//
// SmilCheckMail.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import ZIPFoundation
import NaturalLanguage

struct SmilClip {
    let smilPath: String
    let audioClip: String
    let clipBegin: TimeInterval
    let clipEnd: TimeInterval
    let textHref: String
    let xmlText:String
    let index:Int
    var duration: TimeInterval { clipEnd - clipBegin }
}

struct SmilCheckerThresholds: Codable {
    var maxClipDuration: TimeInterval = 45.0   // Looking for real outliers where multiple sentences are grouped
    var minClipDuration: TimeInterval = 0.3
    
    // Silence/gap threshold between clips (in seconds)
    var maxGapDuration: TimeInterval = 1.5
    
    // Word‐pace thresholds (seconds per word)
    var maxSecondsPerWord: TimeInterval = 3.5
    var minSecondsPerWord: TimeInterval = 0.14
    
    // Characters‐per‐second threshold
    var minCharsPerSecond: Double = 3.0
    var maxCharsPerSecond: Double = 100.0

    
    // Low-text count special case
    var minWordsForCheck: Int = 2
    var minCharsForCheck: Int = 6
    var maxDurationForLowWordCount: TimeInterval = 3.5
    var minDurationForLowWordCount: TimeInterval = 0.1

    
    // Overlap tolerance (how much two clips can overlap before flagging)
    var overlapTolerance: TimeInterval = 0.0
    
    // Duplicate timing tolerance (how close clipBegin/clipEnd must be to count as “duplicate”)
    var duplicateTimingTolerance: TimeInterval = 0.0
}

struct SmilChecker {
    var parsedDocs: [String: XMLDocument] = [:]
    
    func parseTime(_ value: String) -> TimeInterval? {
        let clean = value.replacingOccurrences(of: "s", with: "")
        let parts = clean.split(separator: ":").compactMap(Double.init)
        switch parts.count {
            case 1: return parts[0]
            case 2: return parts[0] * 60 + parts[1]
            case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
            default: return nil
        }
    }
    
    
    func splitFragment(href: String) -> (file: String, fragment: String)? {
        guard let idx = href.firstIndex(of: "#") else { return nil }
        let file = String(href[..<idx])
        let fragment = String(href[href.index(after: idx)...])
        return (file, fragment)
    }
    
    func extractClips(from smilURL: URL) -> [SmilClip] {
        guard let xml = try? XMLDocument(contentsOf: smilURL, options: []) else { return [] }
        guard let pars = try? xml.nodes(forXPath: "//par") as? [XMLElement] else { return [] }
        return pars.enumerated().compactMap { (index,par) -> SmilClip? in
            guard
                let audio = par.elements(forName: "audio").first,
                let text  = par.elements(forName: "text").first,
                let bStr  = audio.attribute(forName: "clipBegin")?.stringValue,
                let eStr  = audio.attribute(forName: "clipEnd")?.stringValue,
                let src   = audio.attribute(forName: "src")?.stringValue,
                let href  = text.attribute(forName: "src")?.stringValue,
                let b     = parseTime(bStr),
                let e     = parseTime(eStr)
            else { return nil }
            return SmilClip(
                smilPath: smilURL.lastPathComponent,
                audioClip: src,
                clipBegin: b,
                clipEnd: e,
                textHref: href,
                xmlText: par.xmlString,
                index: index
            )
        }
    }
    
    mutating func textForFragment(base: URL, href: String) throws -> String {
        guard let (file, frag) = splitFragment(href: href) else { return "" }

        let doc = try  {
            if let doc = parsedDocs[file] {
                return doc
            }
            let url = base.appendingPathComponent(file)
            let data = try Data(contentsOf: url)
            let xmlDoc = try XMLDocument(data: data, options: .documentTidyXML)
            parsedDocs[file] = xmlDoc
            return xmlDoc
        }()
        let xpath = "//*[@id='\(frag)']"
        guard let node = try doc.nodes(forXPath: xpath).first as? XMLElement else {
            return ""
        }
        return node.stringValue ?? ""
    }
    
    func report(_ emsg:String, clip:SmilClip , frag:String ) {
        //let msg = "\(emsg) PAR: \(clip.xmlText),  xhtmlFrag: \(frag) )"
        let msg = "\(emsg) -- href:\(clip.textHref) -- frag: \(frag) -- clip \(clip.clipBegin) to \(clip.clipEnd) -- audioFile:\(clip.audioClip )"
        print("[WARN] \(msg)\n" )
    }
    
    mutating func checkSmil(at smilURL: URL, thresholds:SmilCheckerThresholds, isLastOrFirstSmil:Bool ) async throws {
        let base = smilURL.deletingLastPathComponent()
        let clips = extractClips(from: smilURL)
        
        // Duration and pace checks
        for clip in clips {
            let isVeryFirstOrLastClip = isLastOrFirstSmil && clips.last?.clipEnd == clip.clipEnd
            
            let txt = try textForFragment(base: base, href: clip.textHref)
            if txt.isEmpty {
                report(  "Empty fragment", clip:clip, frag:txt)
                continue
            }
            
            let bareText = txt.trimmingCharacters(in: .punctuationCharacters).trimmed()
            if bareText.isEmpty {
                //report( "Punctionation only -- duration \(clip.duration)", clip:clip, frag: txt)
                continue
            }
            
            let sentences = tokenizeSentences(text: bareText)
            if sentences.count > 3 {
                report( "Too many sentences in frag", clip:clip, frag:txt)
            }

            let words = tokenizeWords(text: bareText)
            let wc = words.count
            
            if wc == 0 {
                report( "No words in frag", clip:clip, frag: txt)
                continue
            }
            
            let allowExtraTime = (wc<3 && (clip.index == 0 || clip.index == clips.count-1))
            let extraTime = allowExtraTime ? 4.0 : 0.0
            
            let maxClipDuration = ((wc < thresholds.minWordsForCheck ) ? thresholds.maxDurationForLowWordCount : thresholds.maxClipDuration) + extraTime
            let minClipDuration = (wc < thresholds.minWordsForCheck || txt.count < thresholds.minCharsForCheck) ? thresholds.minDurationForLowWordCount : thresholds.minClipDuration
            
            
            let charsPerSecond = Double(txt.count)/clip.duration
            let secondsPerWord = clip.duration / Double(wc)
            let maxSecondsPerWord =   thresholds.maxSecondsPerWord + extraTime
            let minSecondsPerWord = (wc <= 3 ) ? 0.05 : thresholds.minSecondsPerWord
            let minCharsPerSecond = allowExtraTime ? 0.3 :  thresholds.minCharsPerSecond
            
            if clip.duration > maxClipDuration && !isVeryFirstOrLastClip {
                report(  "Long duration \(clip.duration)s", clip:clip, frag:txt)
            }
            else if secondsPerWord > maxSecondsPerWord && !isVeryFirstOrLastClip {
                let slowPace = String(format: "%.2f", secondsPerWord)
                report("Slow pace \(slowPace)", clip:clip, frag: txt)
            }
            else if clip.duration < minClipDuration {
                report("Short duration (\(clip.duration)s)", clip:clip, frag:txt)
            }
            else if secondsPerWord < minSecondsPerWord {
                let fastPace = String(format: "%.2f", secondsPerWord)
                report("Fast pace \(fastPace)", clip:clip, frag: txt)
            }
            else if charsPerSecond < minCharsPerSecond {
                //report("Slow chars per second (\(charsPerSecond) cps)", clip:clip, frag:txt)
            }
            else if charsPerSecond > thresholds.maxCharsPerSecond {
                report("Fast chars per second (\(charsPerSecond) cps)", clip:clip, frag:txt)
            }
            
        }
        
        // Overlap checks
        let groupedByAudio = Dictionary(grouping: clips, by: { $0.audioClip })
        for (audioFile, group) in groupedByAudio {
            let sorted = group.sorted { $0.clipBegin < $1.clipBegin }
            for i in 1..<sorted.count {
                let prev = sorted[i - 1]
                let curr = sorted[i]
                if curr.clipBegin < prev.clipEnd {
                    print("[WARN] Overlap in \(audioFile):")
                    print("  → Previous: \(prev.clipBegin)s–\(prev.clipEnd)s (\(prev.textHref))")
                    print("  → Current:  \(curr.clipBegin)s–\(curr.clipEnd)s (\(curr.textHref))")
                }
            }
        }
    }
}

extension SmilChecker {
    func tokenizeSentences(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences = [String]()
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let sentence = text[tokenRange]
            if !sentence.trim().isEmpty {
                sentences.append(String(sentence))
            }
            return true
        }
        
        return sentences
    }
    
    func tokenizeWords(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var words = [String]()
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = text[tokenRange]
            if !word.trim().isEmpty {
                words.append(String(word))
            }
            return true
        }
        
        return words
    }
}

@main
struct SmilCheckerMain {
    static func main() async throws {
        try await runSmilCheck()
    }
    
    static func runSmilCheck() async throws {
        let args = CommandLine.arguments
        guard args.count == 2 else {
            print("Usage: smilchecker (<book.epub>|<book.smil>)")
            exit(1)
        }
        
        let thresholds = SmilCheckerThresholds()
        
        let epubURL = URL(fileURLWithPath: args[1])
        if epubURL.pathExtension == "smil" {
            var smilChecker = SmilChecker()
            try await smilChecker.checkSmil(at: epubURL, thresholds: thresholds, isLastOrFirstSmil: false)
            exit(0)
        }
        let tempDir: URL
        do {
            tempDir = try unzipEPUB(at: epubURL)
        } catch {
            print("Unzip failed: \(error)")
            exit(2)
        }
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        let containerData = try Data(contentsOf: containerPath)
        let containerDoc = try XMLDocument(data: containerData)
        let fullPath = try containerDoc.nodes(forXPath: "/*[local-name()='container']/*[local-name()='rootfiles']/*[local-name()='rootfile']/@full-path").first!.stringValue!
        let manifestPath = tempDir.appendingPathComponent(fullPath)
        let manifestData = try Data(contentsOf: manifestPath)
        let manifestDoc =  try XMLDocument(data: manifestData)
        let spineItemrefs = try manifestDoc.nodes(
            forXPath: "/*[local-name()='package']/*[local-name()='spine']/*[local-name()='itemref']"
        )

        let smilFilesInOrder = spineItemrefs.compactMap { node -> String? in
            let itemref = node as? XMLElement
            guard let idref = itemref?.attribute(forName: "idref")?.stringValue else {
                return nil
            }
            let manifestItems = try? manifestDoc.nodes(
                forXPath: "/*[local-name()='package']/*[local-name()='manifest']/*[local-name()='item'][@id='\(idref)']"
            ) as? [XMLElement]
            let manifestItem = manifestItems?.first
            guard let mediaOverlay = manifestItem?.attribute(forName: "media-overlay") else {
                return nil
            }
            let overlayItems = try? manifestDoc.nodes(
                forXPath: "/*[local-name()='package']/*[local-name()='manifest']/*[local-name()='item'][@id='\(mediaOverlay.stringValue!)']"
            ) as? [XMLElement]
            let overlayItem = overlayItems?.first
            
            let mediaType = overlayItem?.attribute(forName: "media-type")?.stringValue
            if mediaType != "application/smil+xml" {
                return nil
            }
            let smilHref = overlayItem?.attribute(forName: "href")?.stringValue
            return smilHref
        }

        let smilPaths = smilFilesInOrder
        
        let concurrency = 1
        let _ = try await smilPaths.asyncMap(concurrency: concurrency) { rel in
            let url = manifestPath.deletingLastPathComponent().appendingPathComponent(rel)
            var smilChecker = SmilChecker()
            try await smilChecker.checkSmil(at: url, thresholds: thresholds, isLastOrFirstSmil: (rel == smilPaths.last || rel == smilPaths.first))
        }
    }
    
    static func unzipEPUB(at epubURL: URL) throws -> URL {
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent("smilcheck_\(UUID())")
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        let archive = try Archive(url: epubURL, accessMode: .read)
        
        for entry in archive {
            let outURL = dest.appendingPathComponent(entry.path)
            try fm.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: outURL)
        }
        return dest
    }
}
