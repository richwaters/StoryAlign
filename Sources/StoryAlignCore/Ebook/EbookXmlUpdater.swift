//
// EbookXmlUpdater.swift
//
// SPDX-License-Identifier: MIT
//
// Copyright (c) 2023 Shane Friedman
// Copyright (c) 2025 Rich Waters
//



import Foundation
import SwiftSoup


public struct XMLUpdater : SessionConfigurable,Sendable {
    public let sessionConfig: SessionConfig
    public init(sessionConfig: SessionConfig) {
        self.sessionConfig = sessionConfig
    }
    
    let cssStyle = """
        .-epub-media-overlay-active {
          background-color: #4FC3F7;
        }
        """

    public func updateXml(forEbook: EpubDocument, audioBook: AudioBook, alignedChapters: [AlignedChapter]) async throws {
        try await tagAndWrite(alignedChapters: alignedChapters, inEbook: forEbook)
        let mediaOverlays = try createMediaOverlays(for: forEbook, alignedChapters: alignedChapters)
        try update(eBook: forEbook, mediaOverlays: mediaOverlays, audioFiles: audioBook.audioFiles)
    }

    func tagAndWrite(alignedChapters: [AlignedChapter], inEbook: EpubDocument) async throws {
        let total = alignedChapters.count
        let totalBytes = alignedChapters.reduce(0) { $0 + $1.manifestItem.xmlText.count }
        
        let nThreads = sessionConfig.throttle ? 1 : 0
        let _ = try await alignedChapters.enumerated().asyncCompactMap(concurrency: nThreads) { (index,chapter) -> (URL, String)? in
            let manifestItem = chapter.manifestItem
            guard let filePath = manifestItem.filePath else {
                return nil
            }
            if chapter.alignedSentences.isEmpty {
                return nil
            }
            logger.log( .info, "Updating \(manifestItem.id)")
            let bytes = manifestItem.xmlText.count
            sessionConfig.progressUpdater?.updateProgress(for: .xml, msgPrefix: "Tagged", increment: bytes, total: totalBytes, unit:.bytes)
            let nuText = try await XHTMLTagger().tag(epub:inEbook, manifestItem: manifestItem, chapterId: manifestItem.id)
            try nuText.write(to: filePath, atomically: true, encoding: .utf8)
            logger.log( .info, "\(manifestItem.id) update complete. ( \(index)/\(total) )")
            return( filePath, nuText)
        }
    }

    func createMediaOverlays(for epub: EpubDocument, alignedChapters: [AlignedChapter]) throws -> [MediaOverlay] {
        let mediaOverlays:[MediaOverlay] = alignedChapters.compactMap { (alignedChapter) -> MediaOverlay? in
            let manifestItem = alignedChapter.manifestItem
            if manifestItem.filePath == nil {
                return nil
            }
            if alignedChapter.allSentenceRanges.isEmpty {
                return nil
            }
            logger.log(.info, "Creating MediaOverlay for \(manifestItem.id)")
            let mo = MediaOverlay(baseURL: epub.opfURL.deletingLastPathComponent(), manifestItem: manifestItem, sentenceRanges: alignedChapter.allSentenceRanges )
            logger.log(.info, "Completed MediaOverlay for \(manifestItem.id)")
            return mo
        }
        return mediaOverlays
    }

    func update(eBook: EpubDocument, mediaOverlays: [MediaOverlay], audioFiles: [AudioFile]) throws {
        logger.log(.info, "Updating OPF")
        
        let opfData = eBook.opfXmlData
        guard let xmlString = String(data: opfData, encoding: .utf8) else {
            throw StoryAlignError("Invalid OPF data")
        }
        let document = try SwiftSoup.parse(xmlString, "", Parser.xmlParser() )
        
        try updateOpfContribAndModTime( in: document )
        try fixScriptedIssues(in: document, eBook: eBook)
        try add(mediaOverlays: mediaOverlays, to: document, audioFiles: audioFiles)
        try addStyles(to: document, eBook: eBook)

        let updatedXMLStr = try document.xmlFormatted()
        try updatedXMLStr.write(to: eBook.opfURL, atomically: true, encoding: .utf8)

        logger.log(.info, "Completed OPF update")
    }
    
    func updateOpfContribAndModTime( in document:Document ) throws {
        guard let metadata = try document.select("metadata").first() else {
            throw StoryAlignError("Metadata not found.")
        }
        //<meta property="dcterms:modified">2025-04-10T02:38:54Z</meta>
        let isoFormatter = ISO8601DateFormatter()
        let dtModified = isoFormatter.string(from: Date())
        if let modifiedElement = try document.select("meta[property=\"dcterms:modified\"]").first() {
            try modifiedElement.text(dtModified)
        }
        else {
            logger.log(.warn, "Couldn't find dcterms:modified in epub -- adding one" )
            let meta = try buildMeta(attributes: [("property","dcterms:modified")], text: dtModified)
            try metadata.appendChild(meta)
        }
        
        //<dc:contributor id="id-2"></dc:contributor>
        //<meta refines="#id-2" property="role" scheme="marc:relators">bkp</opf:meta>
        let idStr = "storyalign-contributor-id1"
        let versionStr = "\(sessionConfig.toolName ?? "StoryAlign") v\(sessionConfig.version ?? "???")"
        let contributor = try buildElement( withName:"dc:contributor", attributes: [("id",idStr)], text: versionStr)
        try metadata.appendChild(contributor)
        let refinesContributor = try buildMeta(
            attributes: [
                ("refines","#\(idStr)"),
                ("property","role"),
                ("scheme", "marc:relators")
            ],
            text: "bkp"
        )
        try metadata.appendChild(refinesContributor)
    }
    
    
    func fixScriptedIssues( in document:Document , eBook: EpubDocument ) throws {
        guard let manifest = try document.select("manifest").first() else {
            throw StoryAlignError("Missing manifest")
        }

        for item in eBook.manifest {
            let hasScript = {
                if item.hasScript ?? false {
                    return true
                }
                if let nav = eBook.nav {
                    if item.href == nav.href && !item.href.isEmpty {
                        return nav.hasScript
                    }
                }
                return false
            }()
            if hasScript {
                if let xmlItem = try manifest.select("item[id=\(item.id)]").first() {
                    var props = (try? xmlItem.attr("properties").split(separator: " ")) ?? []
                    if !props.contains("scripted") {
                        props.append("scripted")
                        try xmlItem.attr("properties", props.joined(separator: " "))
                    }
                }
            }
        }
    }
    
    func buildElement(withName name:String, attributes: [(String, String)], text: String?) throws -> Element {
        let meta = Element(Tag(name), "")
        for (key, value) in attributes {
            try meta.attr(key, value)
        }
        if let text = text {
            try meta.appendChild(TextNode(text, ""))
        }
        return meta
    }

    
    func buildMeta(attributes: [(String, String)], text: String?) throws -> Element {
        return try buildElement(withName: "meta", attributes: attributes, text: text)
    }

    func add(mediaOverlays: [MediaOverlay], to document: Document, audioFiles: [AudioFile]) throws {
        
        if !mediaOverlays.isEmpty {
            let overlayDir = mediaOverlays[0].filePath.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: overlayDir)
            try FileManager.default.createDirectory(at: overlayDir, withIntermediateDirectories: true)
        }
        
        guard let manifest = try document.select("manifest").first(),
              let metadata = try document.select("metadata").first() else {
            throw StoryAlignError("Missing manifest or metadata")
        }

        for mo in mediaOverlays {
            guard let item = try manifest.select("item[id=\(mo.manifestItem.id)]").first() else {
                throw StoryAlignError("Missing manifest item for \(mo.manifestItem.id)")
            }
            try item.attr("media-overlay", mo.itemId)
            let meta = try buildMeta(
                attributes: [
                    ("property", "media:duration"),
                    ("refines", "#\(mo.itemId)")],
                text: mo.sentenceRanges.duration.HHMMSSs)
            try metadata.appendChild(meta)
            try mo.overlayXml.write(to: mo.filePath, atomically: true, encoding: .utf8)
        }

        let totalDuration = mediaOverlays.reduce(0.0) { $0 + $1.sentenceRanges.duration }
        
        try metadata.appendChild(buildMeta(attributes: [("property","media:duration")], text: totalDuration.HHMMSSs))
        try metadata.appendChild(buildMeta(attributes: [("property","media:active-class")], text: "-epub-media-overlay-active"))
                
        for overlay in mediaOverlays {
            try addItem(to: manifest, id: overlay.itemId, href: overlay.href, mediaType: "application/smil+xml")
        }
        
        let audioFiles = Array( Set( mediaOverlays.flatMap { $0.audioFiles } ) )
        let sortedAudioFiles = audioFiles.sorted { $0.filePath.path() < $1.filePath.path() }
        for audioFile in sortedAudioFiles {
            try addItem(to: manifest, id: audioFile.itemId, href: audioFile.href, mediaType: audioFile.mediaType)
        }
    }

    func addStyles(to document: Document, eBook: EpubDocument) throws {
        guard let manifest = try document.select("manifest").first() else {
            throw StoryAlignError("Manifest not found.")
        }

        try addItem(to: manifest, id: "storyalignstyles", href: "\(AssetPaths.styles)/storyalign.css", mediaType: "text/css")

        let stylesDirPath = eBook.opfURL.deletingLastPathComponent().appendingPathComponent(AssetPaths.styles)
        let stylesPath = stylesDirPath.appendingPathComponent("storyalign.css")
        try FileManager.default.createDirectory(at: stylesDirPath, withIntermediateDirectories: true)
        try cssStyle.write(to: stylesPath, atomically: true, encoding: .utf8)
    }

    func addItem(to manifest: Element, id: String, href: String, mediaType: String) throws {
        let newItem = Element(Tag("item"), "")
        try newItem.attr("id", id)
        try newItem.attr("href", href)
        try newItem.attr("media-type", mediaType)
        try manifest.appendChild(newItem)
    }
}

