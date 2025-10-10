//
// Aligner.swift
// SPDX-License-Identifier: MIT
//
// Copyright (c) 2023 Shane Friedman
// Copyright (c) 2025 Rich Waters
//

import Foundation
import NaturalLanguage

typealias FoundMatch =  (index: Int, match: String, matchType:SentenceMatchType)



fileprivate let OFFSET_SEARCH_WINDOW_SIZE = 5000

class UsedOffets : @unchecked Sendable {
    private var mutex = pthread_mutex_t()
    private var offsets:[(start:Int,end:Int)] = []
    
    init(count:Int) {
        self.offsets = Array(0..<count).map { _ in (start:0, end:0) }
        pthread_mutex_init(&mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func markUsed(index:Int, start:Int, end:Int) {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        self.offsets[index] = (start:start, end:end)
    }
    
    func startsAfter( index:Int ) -> Int {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        var i = index - 1
        while( i >= 0 ) {
            let offset = offsets[i]
            if offset.end != 0 {
                return offset.end
            }
            if offset.start != 0 {
                return offset.start
            }
            i -= 1
        }
        return 0
    }
    func endsBefore( index:Int ) -> Int {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        
        var i = index + 1
        while( i < offsets.count ) {
            let offset = offsets[i]
            if offset.start != 0 {
                return offset.start
            }
            i += 1
        }
        return 0
    }
}

public struct Aligner : SessionConfigurable, Sendable {
    public let sessionConfig:SessionConfig
    private let fuzzySearcher = FuzzySearcher()
    

    public init(sessionConfig: SessionConfig) {
        self.sessionConfig = sessionConfig
    }
    
    public func align( ebook:EpubDocument, AudioBook:AudioBook, rawTranscriptions:[RawTranscription] ) async throws -> [AlignedChapter] {
        
        let transcriber = TranscriberFactory.transcriber(forSessionConfig: sessionConfig)
        let transcriptions = try rawTranscriptions.map { try transcriber.buildTranscription(from: $0) }
        
        let allChapterSentences = ebook.manifest.flatMap { $0.xhtmlSentences }
        let longestSentenceLen = allChapterSentences.map { $0.count }.max()!
        let avgSentenceLen = Int( allChapterSentences.map { Double($0.count) }.average() )
        
        let fullTranscription = Transcription.concatTranscriptions(transcriptions, maxSentenceLen: longestSentenceLen*2, meanSentenceLen: avgSentenceLen)
        let transcriptionNgramIndex = NGramIndex(transcript: fullTranscription.transcription, ngramSize: 6)

        
        logger.log(.debug, "Transcription timeline Hasdups \(fullTranscription.wordTimeline.hasDuplicateConsecutiveSpans())" )
        logger.log(.debug, "Transcription timeline hasOverlaps \(fullTranscription.wordTimeline.hasOverlaps)" )
        
        let bodyMatterHrefs = (ebook.nav?.bodymatterHrefs ?? []).map { $0.hrefWithoutFragment }
        let backMatterHrefs = (ebook.nav?.backmatterHrefs ?? []).map { $0.hrefWithoutFragment }
        
        let sortedManifest = ebook.manifest.sorted { $0.spineItemIndex < $1.spineItemIndex }
        let startManifestItem:EpubManifestItem? = {
            guard let startChapter = sessionConfig.startChapter else {
                return nil
            }
            let retItem = sortedManifest.first { $0.nameOrId == startChapter }
            if retItem == nil {
                logger.log( .warn, "Couldn't find start chapter:\(startChapter)" )
            }
            return retItem
        }()
        let endManifestItem:EpubManifestItem? = {
            guard let endChapter = sessionConfig.endChapter else {
                return nil
            }
            let  retItem = sortedManifest.first { $0.nameOrId == endChapter }
            if retItem == nil {
                logger.log( .warn, "Couldn't find end chapter:\(endChapter)" )
            }
            return retItem
        }()
        
        
        var inBodyMatter = bodyMatterHrefs.isEmpty && startManifestItem == nil

        let navDir = URL(filePath: ebook.nav?.href ?? "").deletingLastPathComponent().path()
        var manifestItems = sortedManifest.filter { manifestItem in
            let relPath = {
                let manifestHrefUrl = URL(filePath:manifestItem.href)
                guard manifestHrefUrl.deletingLastPathComponent().path() == navDir else {
                    return ""
                }
                return manifestHrefUrl.lastPathComponent
            }()

            if let endManifestItem {
                if manifestItem.nameOrId == endManifestItem.nameOrId {
                    inBodyMatter = false
                }
            }
            else {
                if backMatterHrefs.contains(manifestItem.href) || backMatterHrefs.contains(relPath) {
                    inBodyMatter = false
                }
            }
            if let startManifestItem {
                if manifestItem.nameOrId == startManifestItem.nameOrId {
                    inBodyMatter = true
                }
            }
            else if bodyMatterHrefs.contains(manifestItem.href) || bodyMatterHrefs.contains(relPath) {
                inBodyMatter = true
            }
            return inBodyMatter
        }
        if manifestItems.isEmpty && !bodyMatterHrefs.isEmpty && !inBodyMatter {
            logger.log(.warn, "Couldn't find bodymatter: \(bodyMatterHrefs.first!)")
            manifestItems = sortedManifest
        }
        
        let ebookSentenceCount = manifestItems.reduce(0) { $0 + ($1.xhtmlSentences.count) }
        progressUpdate(0, epubSentenceCount:ebookSentenceCount)

        
        let usedTranscriptionOffsets = UsedOffets(count: ebook.manifest.count)

        let nThreads = sessionConfig.throttle ? 1 : 0
        let firstPassAlignments:[AlignedChapter] = try await manifestItems.asyncCompactMap(concurrency: nThreads) { (manifestItem) -> AlignedChapter? in
            guard let alignedItem = try align(manifestItem: manifestItem, withTranscription: fullTranscription, usedOffsets: usedTranscriptionOffsets, transcriptionNGramIndex: transcriptionNgramIndex ) else {
                return nil
            }
            
            usedTranscriptionOffsets.markUsed(index: manifestItem.spineItemIndex, start: alignedItem.transcriptionStartOffset ?? 0, end: alignedItem.transcriptionEndOffset ?? 0)
            return alignedItem
        }
            .sorted { $0.manifestItem.spineItemIndex < $1.manifestItem.spineItemIndex }
        
        
        // This gives another try at chapters that were skipped because they couldn't be found with the course ngramIndex. This tries again with the finer search, but it can be faster since the window is much smaller as the usedOffsets is filled in now.
        let secondPassAlignedItems = try firstPassAlignments.map { alignedItem in
            guard alignedItem.isEmpty else { return alignedItem }
           
            let manifestItem = alignedItem.manifestItem
            guard let nuItem = try align(manifestItem: manifestItem, withTranscription: fullTranscription, usedOffsets: usedTranscriptionOffsets, transcriptionNGramIndex: nil ) else {
                progressUpdate(manifestItem.xhtmlSentences.count)
                return alignedItem
            }
            if nuItem.isEmpty {
                progressUpdate(manifestItem.xhtmlSentences.count)
                return alignedItem
            }
            usedTranscriptionOffsets.markUsed(index: manifestItem.spineItemIndex, start: nuItem.transcriptionStartOffset ?? 0, end: nuItem.transcriptionEndOffset ?? 0)
            return nuItem
        }
            .sorted { $0.manifestItem.spineItemIndex < $1.manifestItem.spineItemIndex }

        
        
        // Final pass
        // This looks for cases where chapterStart was too far into the chapter. It then tries to align those sentences starting from the end of the previous chapter. This can correct the missed alignments better than interpolation. Except for the case where there's stuff in the transcription in between chapters.
        var lastAlignedSentence:AlignedSentence? = nil
        let alignedItems = try secondPassAlignedItems.map { alignedItem in
            guard let firstAlignedSentence = alignedItem.alignedSentences.first else {
                return alignedItem
            }
            guard firstAlignedSentence.sentenceRange.timeStamps.count > 0 else {
                logger.log( .warn, "Internal error -- no time stamps for first aligned sentence in \(alignedItem)" )
                return alignedItem
            }
            defer {
                lastAlignedSentence = alignedItem.alignedSentences.last!
            }
            guard firstAlignedSentence.chapterSentenceId != 0 else {
                return alignedItem
            }

            let firstSentenceStartOffset = firstAlignedSentence.sentenceRange.timeStamps.first!.startOffset
            let gap = firstSentenceStartOffset - (lastAlignedSentence?.sentenceRange.timeStamps.last!.endOffset ?? 0)
            guard gap > 0 else {
                return alignedItem
            }
            
            var startTransOffset = firstSentenceStartOffset-gap
            if firstAlignedSentence.sentenceRange.audioFile.filePath != lastAlignedSentence?.sentenceRange.audioFile.filePath {
                let audioFilePath = firstAlignedSentence.sentenceRange.audioFile.filePath
                let startTsIndex = lastAlignedSentence?.sentenceRange.timeStamps.last!.index ?? 0
                if let firstTsForAudioFile = fullTranscription.wordTimeline[startTsIndex...].first(where:{ $0.audioFile.filePath == audioFilePath}) {
                    startTransOffset = firstTsForAudioFile.startOffset
                }
            }

            let chapterSentences = alignedItem.manifestItem.xhtmlSentences.prefix(firstAlignedSentence.chapterSentenceId)
            if chapterSentences.isEmpty {
                return alignedItem
            }
            
            let normalizedChapterSentences = try normalize(sentences: Array(chapterSentences) )
            let (alignedSentences, _, _ ) = alignSentences( manifestItemName:alignedItem.manifestItem.nameOrId, chapterStartSentence: 0, chapterSentences: normalizedChapterSentences, transcription: fullTranscription, startingTransOffset: startTransOffset )
            guard alignedSentences.isEmpty == false else {
                return alignedItem
            }
            let nuSentences = alignedSentences + alignedItem.alignedSentences
            let nuAlignedItem = alignedItem.with(alignedSentences: nuSentences)
            return nuAlignedItem
        }
        
        let refined = try finalize(alignedItems: alignedItems, transcription: fullTranscription)
        return refined
    }

}

extension Aligner {

    //func align( manifestItem:EpubManifestItem, withTranscription transcription:Transcription, startsAfterOffset:Int, endsBeforeOffset:Int, transcriptionNGramIndex:NGramIndex? ) throws -> AlignedChapter? {
    func align( manifestItem:EpubManifestItem, withTranscription transcription:Transcription, usedOffsets:UsedOffets, transcriptionNGramIndex:NGramIndex? ) throws -> AlignedChapter? {

        logger.log(.info, "Aligning \(manifestItem.nameOrId)")

        let transcriptionTxt = transcription.transcription
        let chapterSentences = try normalize(sentences: manifestItem.xhtmlSentences)
        
        if chapterSentences.isEmpty {
            logger.log(.info, "\(manifestItem.id) has no text; skipping")
            return nil
        }
        
        if chapterSentences.count < 2 {
            if (chapterSentences.first ?? "").split(separator: " ").count < 4 {
                logger.log(.info, "\(manifestItem.id) has fewer than four words; skipping")
                return nil
            }
        }

        //let endsBeforeOffset = usedOffsets.endsBefore(index: manifestItem.spineItemIndex)
        //guard let (startSentence, startTranscriptionOffset) = findBestOffset(manifestItemId:manifestItem.id, epubChapterSentences: chapterSentences, transcriptionText: transcriptionTxt, startsAfterOffset: startsAfterOffset, endsBeforeOffset: endsBeforeOffset) else {
        let  offsetInfo = {
            guard let transcriptionNGramIndex else {
                let startsAfterOffset = usedOffsets.startsAfter(index: manifestItem.spineItemIndex)
                let endsBeforeOffset = usedOffsets.endsBefore(index: manifestItem.spineItemIndex)
                return findBestOffset(manifestItemId:manifestItem.id, epubChapterSentences: chapterSentences, transcriptionText: transcriptionTxt, startsAfterOffset: startsAfterOffset, endsBeforeOffset: endsBeforeOffset)
            }
            //return findBestOffset2(manifestItemId:manifestItem.id, epubChapterSentences: chapterSentences, transcription:transcription, startsAfterOffset: startsAfterOffset, endsBeforeOffset: endsBeforeOffset, index: transcriptionNGramIndex)
            return findBestOffset2(manifestItem:manifestItem, epubChapterSentences: chapterSentences, transcription:transcription, usedOffsets:usedOffsets, index: transcriptionNGramIndex)
        }()
        
        
        guard let (startSentence, startTranscriptionOffset) = offsetInfo else {
           logger.log(.info, "Couldn't find matching transcription for \(manifestItem.id)")
           return AlignedChapter(manifestItem:manifestItem)
       }

        usedOffsets.markUsed(index: manifestItem.spineItemIndex, start: startTranscriptionOffset, end: 0)

        
        let (alignedSentences, skippedSentences, endTranscriptionOffset ) = alignSentences( manifestItemName:manifestItem.nameOrId, chapterStartSentence: startSentence, chapterSentences: chapterSentences, transcription: transcription, startingTransOffset: startTranscriptionOffset )

        logger.log(.debug, "Found chapter starrt for \(manifestItem.id) at \(startTranscriptionOffset)")
        logger.log(.debug, "Found end for \(manifestItem.id) at \(endTranscriptionOffset)")
        logger.log( .debug, "Manifest item start text: \(manifestItem.startTxt.collapseWhiteSpace())\n----\n")
        logger.log( .debug, "Transcription start text: \(transcriptionTxt.safeSubstring(from: startTranscriptionOffset , length:128))\n====\n\n" )
        logger.log( .debug, "Manifest item end text: \(manifestItem.endTxt.collapseWhiteSpace())")
        logger.log( .debug, "Transcription end text: \(transcriptionTxt.safeSubstring(to: endTranscriptionOffset , length:128).collapseWhiteSpace())" )

        let alignedChapter = AlignedChapter(manifestItem: manifestItem, transcriptionStartOffset: startTranscriptionOffset, transcriptionEndOffset: endTranscriptionOffset, alignedSentences: alignedSentences, skippedSentences:skippedSentences, rebuiltSentences: [] )

        logger.log(.info, "Completed alignment of \(manifestItem.id)")

        
        return alignedChapter
    }
    
    public func finalize(alignedItems: [AlignedChapter], transcription:Transcription) throws -> [AlignedChapter] {
        var lastSentenceRange:SentenceRange? = nil
        
        let refinedAlignedItems = try alignedItems.map { alignedItem in
            if alignedItem.isEmpty || alignedItem.alignedSentences.isEmpty {
                return alignedItem
            }

            let doRefine = { (alignedItem:AlignedChapter ) -> AlignedChapter in
                let chapterSentences = try normalize(sentences: alignedItem.manifestItem.xhtmlSentences)
                let (refined,rebuilt) = refine(alignSentences: alignedItem.alignedSentences, lastSentenceRange:lastSentenceRange, transcription:transcription, chapterSentences: chapterSentences)
                lastSentenceRange = refined.last?.sentenceRange
                return alignedItem.with(alignedSentences: refined, rebuiltSentences: rebuilt)
            }
            
            
            let firstSentence = alignedItem.alignedSentences.first!
            if firstSentence.chapterSentenceId != 0 {
                return try doRefine(alignedItem)
            }
            
            guard let last = lastSentenceRange else {
                firstSentence.sentenceRange.start = 0
                return try doRefine(alignedItem)
            }
            
            if firstSentence.sentenceRange.audioFile.filePath == last.audioFile.filePath  {
                last.end = firstSentence.sentenceRange.start
                return try doRefine(alignedItem)
            }
            last.end = last.audioFile.duration
            firstSentence.sentenceRange.start = 0
            return try doRefine(alignedItem)
        }
        lastSentenceRange?.end = lastSentenceRange?.audioFile.duration ?? 0
        
        return refinedAlignedItems
    }
    
    func normalize( sentences:[String] ) throws  -> [String] {
        let wordNormalizer = WordNormalizer()
        let chapterSentences = sentences.map { wordNormalizer.normalizeWordsInSentence($0).collapseWhiteSpace().trimmed() }
        return chapterSentences
    }

}


private extension Aligner {
    private func findBestOffset(manifestItemId:String,  epubChapterSentences: [String], transcriptionText: String, startsAfterOffset:Int, endsBeforeOffset:Int ) -> (startSentence: Int, transcriptionOffset: Int)? {
        let lastMatchOffset = startsAfterOffset

        var offset = lastMatchOffset + 1
        let textCount = transcriptionText.count
        while offset < textCount {
            var startSentence = 0
            let endOffset = min( max(offset + OFFSET_SEARCH_WINDOW_SIZE, endsBeforeOffset), textCount )

            if offset > endOffset {
                logger.log(.debug, "Can we still get here?")
                return nil
            }
            let startIndex = transcriptionText.index(transcriptionText.startIndex, offsetBy: offset)
            let endIndex = transcriptionText.index(transcriptionText.startIndex, offsetBy: endOffset)
            let transcriptionTextSlice = String(transcriptionText[startIndex..<endIndex])
            while startSentence < epubChapterSentences.count {
                let sliceEnd = min(startSentence + 6, epubChapterSentences.count)
                let queryString = epubChapterSentences[startSentence..<sliceEnd].joined(separator: " ")
                let loweredQuery = queryString.lowercased()
                let loweredTextSlice = transcriptionTextSlice.lowercased()
                let maxDistance = max(Int(Double(queryString.count) * 0.1), 1)
                if let firstMatch = fuzzySearcher.findNearestMatch(needle: loweredQuery, haystack: loweredTextSlice, maxDist: maxDistance) {
                    let offset = (firstMatch.index + offset) % textCount
                    logger.log(.debug, "\(manifestItemId): Found best offset \(offset) traversed:\(offset - lastMatchOffset)")
                    
                    return (startSentence: startSentence, transcriptionOffset: offset)
                }
                
                startSentence += 3
                //startSentence += 1
            }
            
            offset += min( textCount - offset, OFFSET_SEARCH_WINDOW_SIZE / 2)
        }
        
        logger.log( .debug, "\(manifestItemId):   No chapter offset found. traversed:\(offset - lastMatchOffset)")
        
        return nil
    }
    
    //private func findBestOffset2( manifestItemId: String, epubChapterSentences: [String], transcription: Transcription, startsAfterOffset: Int, endsBeforeOffset: Int, index: NGramIndex ) -> (startSentence: Int, transcriptionOffset: Int)? {
    private func findBestOffset2( manifestItem: EpubManifestItem, epubChapterSentences: [String], transcription: Transcription, usedOffsets:UsedOffets, index: NGramIndex ) -> (startSentence: Int, transcriptionOffset: Int)? {
        let manifestItemId = manifestItem.id
        let transcriptionText = transcription.transcription
        //let last = startsAfterOffset
        let textCount = transcriptionText.count
        //let endOffset = endsBeforeOffset == 0 ? textCount : endsBeforeOffset
        
        for chapterSentenceIndex in stride(from: 0, to: epubChapterSentences.count, by: 3) {
            let sliceEnd = min(chapterSentenceIndex + 6, epubChapterSentences.count)
            let chunk = epubChapterSentences[chapterSentenceIndex..<sliceEnd]
                .joined(separator: " ")

            let loweredNeedle = chunk.lowercased()
            let maxDist = max(Int(Double(loweredNeedle.count) * 0.1), 1)
            let windowSize = min( loweredNeedle.count*3, OFFSET_SEARCH_WINDOW_SIZE)
            
            let endsBeforeOffset = usedOffsets.endsBefore(index: manifestItem.spineItemIndex)
            let endOffset = endsBeforeOffset == 0 ? textCount : endsBeforeOffset
            let startsAfterOffset = usedOffsets.startsAfter(index: manifestItem.spineItemIndex)


            let allCandidates = index.candidates(for: chunk)
            let candidates:[Int] = allCandidates.pairs().compactMap { (prev,candidate) in
                if candidate > endOffset || candidate < startsAfterOffset {
                    return nil
                }
                guard let lastCandidate=prev else {
                    return candidate
                }
                if lastCandidate > 0 && (candidate + loweredNeedle.count + maxDist) < (lastCandidate+windowSize) {
                    return nil
                }
                return candidate
            }
            
            logger.log( .debug,  "manifoldItemId:\(manifestItemId) findChapterOffsetRough: WindowSize \(windowSize)  candidatesCount:\(candidates.count) chunkSize:\(chunk.count) sentenceIndex:\(chapterSentenceIndex)", indentLevel: 1)
            
            var candidateIndex = 0
            for candidate in candidates {
                let windowEnd = min(candidate + windowSize, textCount)
                let start = transcriptionText.index(transcriptionText.startIndex, offsetBy: candidate )
                let end = transcriptionText.index( transcriptionText.startIndex, offsetBy: windowEnd )
                let slice = transcriptionText[start..<end]
                let loweredHay = slice.lowercased()
                
                guard let match = fuzzySearcher.findNearestMatch( needle: loweredNeedle, haystack: loweredHay, maxDist: maxDist ) else {
                    candidateIndex += 1
                    continue
                }
                        
                let found = (candidate + match.index) % textCount
                logger.log( .debug, "manifoldItemId:\(manifestItemId) findChapterOffsetRough: found at candidateIndex:\(candidateIndex), offset:\(found-startsAfterOffset) sentence:\(chapterSentenceIndex)")
                let (fineStart, fineEnd) = {
                    guard let sentenceIndex = transcription.indexOfSentence(containingOffset: found) else {
                        let fineWindowSize = OFFSET_SEARCH_WINDOW_SIZE
                        let fineStart = max(0, found - fineWindowSize / 2)
                        let fineEnd = min(found + fineWindowSize / 2, textCount)
                        return( fineStart, fineEnd )
                    }
                    let fineStartSentence = max(0, sentenceIndex-6)
                    let fineEndSentence = min(sentenceIndex+6, transcription.sentences.count)
                    return (transcription.sentencesOffsets[fineStartSentence].startIndex, transcription.sentencesOffsets[fineEndSentence].endIndex )
                }()
                
                guard let (fineStartSentence, offset) = findBestOffset(manifestItemId: manifestItemId, epubChapterSentences: epubChapterSentences, transcriptionText: transcriptionText, startsAfterOffset: fineStart, endsBeforeOffset: fineEnd) else {
                    logger.log(.info, "Could not find best offset for \(manifestItemId) from index")
                    return( chapterSentenceIndex, found)
                }
                return (fineStartSentence, offset)
            }
        }
        return nil
    }
}

extension Aligner {
    func progressUpdate(_ incr:Int, epubSentenceCount:Int? = nil) {
        sessionConfig.progressUpdater?.updateProgress(for: .align, msgPrefix: "Aligned", increment: incr, total: epubSentenceCount, unit: .sentences)
    }
    
    func alignSentences( manifestItemName:String, chapterStartSentence: Int, chapterSentences: [String], transcription: Transcription, startingTransOffset: Int ) -> (alignedSentences: [AlignedSentence], skippedSentences:[SkippedSentence], transcriptionOffset: Int) {
        var alignedSentences: [AlignedSentence] = []
        var skippedSentences:[SkippedSentence] = []

        let transcriptionStartSentenceIndex = (transcription.indexOfSentence(containingOffset: startingTransOffset) ?? 0)
        let transcriptionSentenceOffsets = transcription.sentencesOffsets[transcriptionStartSentenceIndex]
        let midSentenceOffset = max(0, startingTransOffset - transcriptionSentenceOffsets.lowerBound)
        let firstTransSentence = transcription.sentences[transcriptionStartSentenceIndex].safeSubstring(from: midSentenceOffset)
        let otherTransSentences = transcription.sentences[transcriptionStartSentenceIndex+1 ..< transcription.sentences.count]
        let transcriptionSentences = ([firstTransSentence] + otherTransSentences).map { $0.lowercased() }
        var startSentenceEntry = chapterStartSentence
        
        
        let charactersToRemove: Set<Character> = [".", "-", "_", "(", ")", "[", "]", ",", "/", "?", "!", "@", "#", "$", "%", "^", "&", "*", "`", "~", ";", ":", "=", "'", "\"", "<", ">", "+", "ˌ", "ˈ", "“"]
        
        let isTooShort = { ( sentence: String ) -> Bool  in
            let cleaned = sentence.filter { !charactersToRemove.contains($0) }
            return cleaned.count <= 3
        }
        
        let filteredChapterSentences: [(Int, String)] = chapterSentences.enumerated().filter { (index, sentence) in
            let cleaned = sentence.filter { !charactersToRemove.contains($0) }
            if cleaned.count == 0 {
            //if cleaned.count <= 3 {
            //if cleaned.count < 3 {
                if index < chapterStartSentence {
                    startSentenceEntry -= 1
                }
                let skippedSentence = SkippedSentence(chapterSentence: sentence, chapterSentenceId: index)
                skippedSentences.append(skippedSentence)
                return false
            }
            return true
        }

        let windowSize = 10
        var transcriptionWindowIndex = 0
        var transcriptionWindowOffset = 0
        var lastGoodTranscriptionWindow = 0
        var notFound = 0
        var sentenceIndex = startSentenceEntry
        var lastMatchEnd = startingTransOffset

        while sentenceIndex < filteredChapterSentences.count {
            guard transcriptionWindowIndex < transcriptionSentences.count else {
                break
            }

            let (sentenceId, sentence) = filteredChapterSentences[sentenceIndex]
            let tooShort = isTooShort(sentence )
            let fullWindowList = Array(transcriptionSentences.dropFirst(transcriptionWindowIndex).prefix(windowSize))
            let safeRaw = fullWindowList.joined()
            let safeOffset = min(transcriptionWindowOffset, safeRaw.count)
            let transcriptionWindow = String(safeRaw.dropFirst(safeOffset))
            
            let query = sentence.trimmed().collapseWhiteSpace().lowercased()
            let smallQuerySpecialCase = query.split(separator: " ").count <= 3 && query.count < 20
            let hardMaxWindowSize = smallQuerySpecialCase ? 3 :  windowSize

            let seeds = computeWindowSizes(forQuery: query, transcriptionSentences: transcriptionSentences, fromTransWindowIdx: transcriptionWindowIndex, transWindowOffset:transcriptionWindowOffset, hardMaxWindowSize: hardMaxWindowSize)
            

            var listUsed: [String] = []
            var foundMatch: (index: Int, match: String, matchType:SentenceMatchType)? = nil
            for ws in seeds {
                let candidateList = Array(transcriptionSentences.dropFirst(transcriptionWindowIndex).prefix(ws))
                let startIdx = min(transcriptionWindowIndex, transcriptionSentences.count)
                let rawSentences = Array(transcriptionSentences.dropFirst(startIdx).prefix(ws))
                let raw = rawSentences.joined()
                let safeDrop = min(transcriptionWindowOffset, raw.count)
                let haystack = String(raw.dropFirst(safeDrop))
                
                defer {
                    if let foundMatch {
                        logger.log(.debug, "Found match at index:\(foundMatch.index): type:\(foundMatch.matchType) queryLen:\(query.count) matchLen:\(foundMatch.match.count)" )
                        logger.log(.debug, "query:\(query)", indentLevel: 1 )
                        logger.log( .debug, "haystack:\(haystack)\n", indentLevel: 1)
                        listUsed = candidateList
                    }
                }
                
                // dynamic threshold
                let baseDist = max(Int(floor(0.25 * Double(query.count))), 1)
                let drift = transcriptionWindowIndex - lastGoodTranscriptionWindow
                let threshold = max(1, Int(Double(baseDist) / Double(drift + 1)))
                
                logger.log(.debug, "Seed:\(ws) Haystack size: \(haystack.count)")

                if haystack.starts(with: query) {
                    foundMatch = (0, query, .exact)
                    break
                }
                if haystack.starts(with: " \(query)") {
                    foundMatch = (1, query, .trimmedLeading)
                    break
                }

                if let range = rangeExactMatchIgnoringSurroundingPunctuation(in: haystack, query: query) {
                    let matched = String(haystack[range])
                    let offset  = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
                    foundMatch = (offset, matched, .ignoringEndsPunctuation)
                    break
                }
                
                if let range = rangeExactMatchIgnoringAllPunctuation(in: haystack, query: query) {
                    let matched = String(haystack[range])
                    let offset  = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
                    foundMatch = (offset, matched, .ignoringAllPunctuation)
                    break
                }
                if tooShort {
                    break;
                }
                
                if let m = fuzzySearcher.findNearestMatch(needle: query, haystack: haystack, maxDist: threshold) {
                    if m.index > 200 {
                        logger.log(.debug, "Far away match at index:\(m.index): type:\(m.match): query:\(query) haystack:\(haystack)" )
                    }
                    foundMatch = (m.index, m.match, .nearest)
                    break
                }
            }
            
            guard let firstMatch = foundMatch else {
                sentenceIndex += 1
                notFound += 1
                
                logger.log(.debug, "No match on try \(notFound) for chapterQuery \(query) transcriptionWindow: \(transcriptionWindow)")

                if tooShort || notFound == 3 || sentenceIndex == filteredChapterSentences.count {
                    let maxTransWindowTries = tooShort ? 2 : 30
                    
                    transcriptionWindowIndex += 1
                    if transcriptionWindowIndex == lastGoodTranscriptionWindow + maxTransWindowTries {
                        let skippedRange = filteredChapterSentences[(sentenceIndex - notFound)..<sentenceIndex]
                        logger.log(.debug, "TranscriptionWindoIndex hit limit:")
                        skippedSentences += skippedRange.map { (sentenceId,sentence) in
                            logger.log(.debug, "Skipped sentence -- hit transcriptionWindoIndex Limit: \(sentence)", indentLevel: 1)
                            return SkippedSentence( chapterSentence: sentence, chapterSentenceId: sentenceId /*, lastEndFoundOffset16: lastMatchEnd*/)
                        }
                        transcriptionWindowIndex = lastGoodTranscriptionWindow
                        notFound = 0
                        continue
                    }
                    sentenceIndex -= notFound
                    notFound = 0
                }
                continue
            }
            

            
            if notFound > 0 {
                let skipped = filteredChapterSentences[(sentenceIndex - notFound)..<sentenceIndex]
                skippedSentences += skipped.map { (sentenceId,sentence) in
                    logger.log(.debug, "Skipped sentence -- \(sentence)", indentLevel: 1)
                    return SkippedSentence( chapterSentence: sentence, chapterSentenceId: sentenceId /*, lastEndFoundOffset16: lastMatchEnd*/)
                }
            }
            notFound = 0


            let transcriptionOffset = transcriptionSentences[0..<transcriptionWindowIndex].joined().count
            let matchStartIndex =  firstMatch.index + transcriptionOffset + transcriptionWindowOffset + startingTransOffset
            guard let startResult = findStartTimestamp(matchStartIndex: matchStartIndex, transcription: transcription) else {
                sentenceIndex += 1
                continue
            }

            var matchEndOffset = firstMatch.index + firstMatch.match.count + transcriptionOffset + transcriptionWindowOffset + startingTransOffset
            if firstMatch.match.last == " " && firstMatch.match.count > 1 {
                matchEndOffset -= 1
            }
            var start = startResult.start
            let audiofile = startResult.audioFile
            let endTimeStamp = findEndTimestamp(  fromStartTimeStamp:startResult, forMatch:firstMatch, transcription: transcription)
            let endValue = endTimeStamp.end

            var sharedTimeStamp = false
            // adjust previous ranges
            if !alignedSentences.isEmpty {
                var previousSentence = alignedSentences[alignedSentences.count - 1]
                let previous = previousSentence.sentenceRange
                if audiofile.filePath == previous.audioFile.filePath && previous.id == sentenceId - 1 {
                    if previous.timeStamps.first?.index == startResult.index && previous.timeStamps.last?.index == endTimeStamp.index {
                        logger.log( .debug, "Single timestap for multiple sentences: \(startResult.token)" )
                        previousSentence.sharedTimeStamp = true
                        alignedSentences[alignedSentences.count - 1] = previousSentence
                        sharedTimeStamp = true
                    }

                    let gap = start - previous.end
                    if gap > 0 {
                        
                        // Default to splitting the time between the 2 sentences equally.
                        start -= gap/2
                        let prevTimeStamp = previous.timeStamps.last!
                        
                        // If the sentences are in 2 different segments, use the segment information to split the gap
                        if prevTimeStamp.segmentIndex != startResult.segmentIndex {
                            let seg = transcription.segments[startResult.segmentIndex]
                            if seg.start < startResult.start && seg.start >= previous.end {
                                // set the start of this sentence to the start of the segment
                                start = seg.start
                            }
                            let prevEndSeg = transcription.segments[prevTimeStamp.segmentIndex]
                            if prevEndSeg.end < start  {
                                // If the previous segment ends before this one starts, backup the start to the end of the
                                // previous segment. This might not always be smart but I think in most cases it's better
                                // to move on asap.
                                start = prevEndSeg.end
                            }
                        }
                    }
                    previous.end = start
                }
                else if previous.id == sentenceId - 1 {
                    previous.end = previous.audioFile.duration
                    start = 0
                }
            }
            
            let timeStamps = Array(transcription.wordTimeline[startResult.index ... endTimeStamp.index])

            let sentenceRange = SentenceRange(id: sentenceId, start: start, end: endValue, audioFile: audiofile, timeStamps: timeStamps)
            let alignedSentence = AlignedSentence(chapterSentence: sentence, chapterSentenceId: sentenceId, sentenceRange: sentenceRange, matchText: foundMatch?.match, matchOffset: foundMatch?.index, matchType: foundMatch?.matchType, sharedTimeStamp: sharedTimeStamp)
            alignedSentences.append(alignedSentence)
            progressUpdate(1)

            notFound = 0
            //lastMatchEnd = matchEndOffset
            lastMatchEnd = endTimeStamp.endOffset
            let windowIndexResult = getWindowIndexFromOffset(window: listUsed, offset: firstMatch.index + firstMatch.match.count + transcriptionWindowOffset)
            transcriptionWindowIndex += windowIndexResult.index
            transcriptionWindowOffset = windowIndexResult.offset
            lastGoodTranscriptionWindow = transcriptionWindowIndex
            sentenceIndex += 1
        }
        
        if notFound > 0 {
            logger.log(.debug, "End of alignment loop: \(notFound) sentences not found")
            let skipped = filteredChapterSentences[(sentenceIndex - notFound)..<filteredChapterSentences.count]
            skippedSentences += skipped.map { (sentenceId,sentence) in
                logger.log(.debug, "Skipped sentence -- End of loop: \(sentence)", indentLevel: 1)
                return SkippedSentence( chapterSentence: sentence, chapterSentenceId: sentenceId /*, lastEndFoundOffset16: lastMatchEnd*/)
            }
        }
        
        //exportTestJson(withAlignedSentences: alignedSentences, chapterSentences: sentences, skippedSentences: skippedSentences, transcription: transcription)

        return (alignedSentences, skippedSentences, lastMatchEnd)
    }
    
    func computeWindowSizes( forQuery query:String, transcriptionSentences:[String], fromTransWindowIdx:Int, transWindowOffset offs:Int, hardMaxWindowSize:Int) -> [Int] {
        
        let desiredSmallChars = Int( Double(query.count) * 1.5)
        let desiredMidChars = query.count * 3
        let desiredMaxChars = query.count * 7
                        
        let base = fromTransWindowIdx
        let computeOne = { (targetChars:Int, startIndex:Int) -> (windowCount: Int, charCount: Int)  in
            let overshootBias = 1.2
            
            var curLen = transcriptionSentences[base..<min(base + startIndex, transcriptionSentences.count)].reduce(0) { $0 + $1.count } - offs
            let endIndex = min(transcriptionSentences.count - base, hardMaxWindowSize)

            //var curLen = (remainingTransSentences.prefix(startIndex).reduce(0) { $0 + $1.count} ) - offs
            //let endIndex = min(remainingTransSentences.count, hardMaxWindowSize)
            
            for ws in (startIndex ..< endIndex) {
                //let s = remainingTransSentences[ws]
                //let sCount = s.count
                let sCount = transcriptionSentences[base + ws].count

                let newLen = curLen + sCount
                let newWs  = ws + 1
                
                let overshoot  = (newLen - targetChars)
                let undershoot = (targetChars - curLen)

                if newLen > targetChars {
                    if curLen <= query.count || Double(overshoot) <= Double(undershoot) * overshootBias {
                        curLen = newLen
                        return (windowCount:newWs, charCount: newLen)
                    }
                    return (windowCount: ws, charCount: curLen)
                }
                curLen = newLen
            }
            return (windowCount:endIndex, charCount: curLen)
        }

        let (minWS, minChars) = computeOne(desiredSmallChars, 0)
        var (midWS, midChars) = computeOne(desiredMidChars, minWS)
        var (maxWindowSize, maxChars) = computeOne(desiredMaxChars, midWS)

        if midWS <= minWS {
            midWS = (minWS + maxWindowSize) / 2
            if midWS <= minWS || midChars <= minChars {
                midWS = -1
            }
        }
        if  midWS >= maxWindowSize {
            midWS = -1
        }
        if maxWindowSize <= midWS || maxWindowSize <= minWS {
            maxWindowSize = -1
        }
        let seeds = [minWS, midWS, maxWindowSize].filter { $0 > 0 }
        
        logger.log(.debug, "computeWindowSizes: queryLen:\(query.count) --- desiredSmallChars \(desiredSmallChars) desiredMidChars \(desiredMidChars) desiredMaxChars \(desiredMaxChars) --  seeds: \(seeds) minChars \(minChars) midChars \(midChars) maxChars \(maxChars) ")
        
        return seeds
    }
    
    func rangeExactMatchIgnoringSurroundingPunctuation(in haystack: String, query: String) -> Range<String.Index>? {
        let endPunctCount = query.reversed().prefix { $0.isPunctuation }.count
        let leadPunctCount = query.prefix { $0.isPunctuation }.count
        let core = String(query.dropFirst(leadPunctCount).dropLast(endPunctCount))

        var h = haystack.startIndex
        while h < haystack.endIndex && (haystack[h].isPunctuation || haystack[h].isWhitespace) {
            h = haystack.index(after: h)
        }
        
        //let pattern = "^\\s*[[:punct:]]{0,\(leadPunctCount)}\(escapedCore)[[:punct:]]{0,\(endPunctCount)}"
        if !haystack[h...].hasPrefix(core) {
            return nil
        }
        let startHAfterPunct = h
        h = haystack.index(h, offsetBy: core.count)
        if h == haystack.endIndex {
            return startHAfterPunct..<h
        }
        
        //let maxH = haystack.index(h, offsetBy: endPunctCount)
        let maxH = haystack.index(h, offsetBy: endPunctCount, limitedBy: haystack.endIndex) ?? haystack.endIndex
        while h < haystack.endIndex && (haystack[h].isPunctuation && h < maxH ) {
            h = haystack.index(after: h)
        }
        
        return startHAfterPunct..<h
    }
    
    func rangeExactMatchIgnoringAllPunctuation(in haystack: String, query: String) -> Range<String.Index>? {
        let endPunctCount = query.reversed().prefix { $0.isPunctuation }.count
        let leadPunctCount = query.prefix { $0.isPunctuation }.count
        let core = String(query.dropFirst(leadPunctCount).dropLast(endPunctCount))

        var h = haystack.startIndex
        while h < haystack.endIndex && (haystack[h].isPunctuation || haystack[h].isWhitespace) {
            h = haystack.index(after: h)
        }
        
        //let pattern = "^\\s*[[:punct:]]{0,\(leadPunctCount)}\(escapedCore)[[:punct:]]{0,\(endPunctCount)}"
        let hayStackChars = Array(haystack[h...])
        var hayStackOffset = 0
        
        let coreChars = Array(core)
        for (coreCharIndex, coreChar) in coreChars.enumerated() {
            if hayStackOffset >= hayStackChars.count {
                if coreChar.isPunctuation {
                    continue
                }
                return nil
            }
            
            let haystackChar = hayStackChars[hayStackOffset]
            if haystackChar == coreChar {
                hayStackOffset += 1
                continue
            }
            if coreChar.isPunctuation && haystackChar.isPunctuation {
                hayStackOffset += 1
                continue
            }
            if coreChar.isWhitespace && haystackChar.isWhitespace {
                hayStackOffset += 1
                continue
            }
            if haystackChar.isPunctuation {
                hayStackOffset += 1
                continue
            }
            if coreChar.isPunctuation {
                continue
            }
            
            if coreChar.isWhitespace && coreCharIndex > 0 && coreChars[coreCharIndex-1].isPunctuation  {
                continue
            }

            if hayStackOffset > 0 && hayStackChars[hayStackOffset-1].isPunctuation {
                while hayStackOffset < hayStackChars.count && hayStackChars[hayStackOffset].isWhitespace {
                    hayStackOffset += 1
                }
                if hayStackOffset < hayStackChars.count && hayStackChars[hayStackOffset] == coreChar {
                    hayStackOffset += 1
                }
                continue
            }

            return nil
        }

        let startHAfterPunct = h
        h = haystack.index(h, offsetBy: hayStackOffset)
        if h == haystack.endIndex {
            return startHAfterPunct..<h
        }
        
        let maxH = haystack.index(h, offsetBy: endPunctCount, limitedBy: haystack.endIndex) ?? haystack.endIndex
        while h < haystack.endIndex && (haystack[h].isPunctuation && h < maxH ) {
            h = haystack.index(after: h)
        }
        
        return startHAfterPunct..<h
    }

    // Binary search helper: finds the first index in `timeline` where predicate is true.
    private func lowerBound(in timeline: [WordTimeStamp], where predicate: (WordTimeStamp) -> Bool) -> Int {
        var iters = 0
        var low = 0
        var high = timeline.count
        while low < high {
            iters += 1
            let mid = (low + high) / 2
            if predicate(timeline[mid]) {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low
    }
    
    
    /*
    func findEndTimestamp(matchEndOffset: Int, transcription: Transcription) -> WordTimeStamp? {
        let timeline = transcription.wordTimeline
        let index = lowerBound(in: timeline) { $0.startOffset >= matchEndOffset }
        guard index > 0 else { return nil }
        return timeline[index - 1]
    }
    */
    
    func findEndTimestamp(  fromStartTimeStamp:WordTimeStamp, forMatch:FoundMatch, transcription: Transcription) -> WordTimeStamp {
        if forMatch.match.isEmpty {
            return fromStartTimeStamp
        }
        let matchEndOffset = fromStartTimeStamp.startOffset + forMatch.match.count - 1

        guard let endIndex = transcription.wordTimeline[fromStartTimeStamp.index... ].firstIndex(where: { $0.startOffset >= matchEndOffset }) else {
            return fromStartTimeStamp
        }
        let ts = (endIndex > 0 && endIndex > fromStartTimeStamp.index) ? transcription.wordTimeline[endIndex - 1] : fromStartTimeStamp

        if ts.index >= (transcription.wordTimeline.count - 1)  {
            return ts
        }
        
        let nextTx = transcription.wordTimeline[ts.index + 1]
        if nextTx.token.count > 4 || ts.tokenTypeGuess == .sentenceEnd || nextTx.tokenTypeGuess == .sentenceBegin {
            return ts
        }

        let full = transcription.transcription
        //let lo = full.index(full.startIndex, offsetBy: fromStartTimeStamp.startOffset)
        guard let lo = transcription.offsetToIndexMap[fromStartTimeStamp.startOffset] else {
            return ts
        }

        guard let hi = transcription.offsetToIndexMap[ts.endOffset+1] else {
            return ts
        }

        //let hi = full.index(lo, offsetBy: (ts.endOffset + 1 - fromStartTimeStamp.startOffset) )
        let tsSentence = full[lo..<hi].lowercased().trimmed()
        
        if tsSentence != forMatch.match.trimmed() {
            let mergedSentence = tsSentence+nextTx.token.lowercased().trimmed()
            if mergedSentence == forMatch.match.trimmed() {
                return nextTx
            }
        }

        return ts
    }

    

    func findStartTimestamp(matchStartIndex: Int, transcription: Transcription) -> WordTimeStamp? {
        let timeline = transcription.wordTimeline
        // Find the first entry where endOffsetUtf16 exceeds the matchStartIndex.
        
        // fails when token is 1 char ---
        let index = lowerBound(in: timeline) {
            $0.endOffset > matchStartIndex || ($0.token.count == 1 && $0.endOffset == matchStartIndex)
        }
        //let index = lowerBound(in: timeline) { $0.endOffset >= matchStartIndex }

        guard index < timeline.count else { return nil }
        let entry = timeline[index]
        return entry
    }


    func getWindowIndexFromOffset(window: [String], offset: Int) -> (index: Int, offset: Int) {
        var index = 0
        var remainingOffset = offset
        
        while index < window.count - 1 && remainingOffset >= window[index].count {
            remainingOffset -= window[index].count
            index += 1
        }
        
        return (index, remainingOffset)
    }
}


extension Aligner {
    var missingTimeStampToken:String {
        "[_MISSING_TIMESTAMP_IDENTIFIER_]"
    }
    
    func refine( alignSentences:[AlignedSentence], lastSentenceRange:SentenceRange?, transcription:Transcription, chapterSentences:[String] ) -> (all:[AlignedSentence], rebuilt:[AlignedSentence]) {
        let interpolated = interpolateSentenceRanges(alignedSentences: alignSentences, chapterSentences: chapterSentences, lastSentenceRange: lastSentenceRange)
        let withOffsets = fillInOffsets(interpolated, using: transcription.wordTimeline)
        let (expanded, rebuilt) = expandEmptySentenceRanges(alignedSentences: withOffsets, segments: transcription.segments)
        return (expanded, rebuilt)
    }
    

    ///////////////
    ///
    func makeInterpolated( start: Double, duration:TimeInterval, startSentenceIndex:Int, count: Int,  chapterSentences:[String], audioFile: AudioFile) -> [AlignedSentence]  {
        
        let missingSentences = chapterSentences[startSentenceIndex ..< startSentenceIndex + count]
        let totalVlen = missingSentences.reduce(0.0) { $0 + $1.voiceLength }
        let secondsPerVlen = duration / totalVlen

        var lastStart = start
        let endIndex = startSentenceIndex + count
        let interpolatedSentences = (startSentenceIndex ..< endIndex).map {  index in
            let chapterSentence = index < chapterSentences.count ? chapterSentences[index] : ""
            let vlen = chapterSentence.voiceLength
            let interpolatedLength = count == 1 ? duration : vlen*secondsPerVlen
            
            let missingStart =  lastStart
            let missingEnd = missingStart + interpolatedLength
            lastStart = missingEnd
            let wordTimeStamp = WordTimeStamp(token: missingTimeStampToken, start: missingStart, end: missingEnd, audioFile: audioFile, voiceLen: vlen, segmentIndex: -1, tokenTypeGuess: .missing)
            
            let newRange = SentenceRange(
                id: index,
                start: missingStart.roundToMs(),
                end: missingEnd.roundToMs(),
                audioFile: audioFile,
                timeStamps: [wordTimeStamp]
            )
            let nuSentence = AlignedSentence(chapterSentence:chapterSentence, chapterSentenceId: index, sentenceRange: newRange, matchText: nil, matchOffset: nil, matchType: .interpolated)
            return nuSentence
        }

        return interpolatedSentences
    }
    
    func interpolateSentenceRanges(alignedSentences: [AlignedSentence], chapterSentences:[String], lastSentenceRange: SentenceRange?) -> [AlignedSentence] {

        if alignedSentences.isEmpty {
            return []
        }
        var interpolated: [AlignedSentence] = []
        var sentences = alignedSentences
        var firstAlignedSentence = sentences.removeFirst()
        let firstSentenceRange = firstAlignedSentence.sentenceRange
        
        if firstSentenceRange.id != 0 {
            let count = firstSentenceRange.id
            let crossesAudioBoundary = (lastSentenceRange == nil) || (firstSentenceRange.audioFile.filePath != lastSentenceRange?.audioFile.filePath)
            var diff = crossesAudioBoundary ? firstSentenceRange.start : firstSentenceRange.start - lastSentenceRange!.end
            
            if diff <= 0 {
                if crossesAudioBoundary {
                    // The storyTeller platform just ignores these. I'm not sure what the ramifications of trying to interpolate these are, but it seems to improve things a tiny bit in some cases.
                    if firstSentenceRange.start < 0.25 {
                        firstAlignedSentence.sharedTimeStamp = true
                        diff = 0.25
                        firstSentenceRange.start += diff
                    }
                    else {
                        diff = firstSentenceRange.start
                    }
                }
                else {
                    diff = 0.25
                    lastSentenceRange?.end = firstSentenceRange.start - diff
                }
            }
            
            let startPoint = crossesAudioBoundary ? 0.0 : lastSentenceRange!.end
            if diff > 0 {
                let interpolatedSentences = makeInterpolated(start: startPoint, duration: diff, startSentenceIndex: 0, count: count,chapterSentences: chapterSentences, audioFile: firstSentenceRange.audioFile)
                interpolated.append(contentsOf: interpolatedSentences)
                progressUpdate(interpolatedSentences.count)
            }
        }
        interpolated.append(firstAlignedSentence)

        for alignedSentence in sentences {
            let sentenceRange = alignedSentence.sentenceRange
            if interpolated.isEmpty {
                interpolated.append(alignedSentence)
                continue
            }
            
            let lastAlignedSentence = interpolated.last!
            let lastSentenceRange = lastAlignedSentence.sentenceRange
            let missingCount = sentenceRange.id - lastSentenceRange.id - 1
            
            if missingCount == 0 {
                interpolated.append(alignedSentence)
                continue
            }
            
            let crossesAudioBoundary = (sentenceRange.audioFile.filePath != lastSentenceRange.audioFile.filePath)
            var diff: Double = 0.0
            var gapAudioFile = sentenceRange.audioFile
            
            if crossesAudioBoundary {
                let (largestGap, audioFileFromGap) = getLargestGap(trailing: lastSentenceRange, leading: sentenceRange)
                diff = largestGap
                gapAudioFile = audioFileFromGap
            } else {
                diff = sentenceRange.start - lastSentenceRange.end
            }
            
            let currentSentence = alignedSentence
            
            if diff <= 0 {
                if crossesAudioBoundary {
                    let rangeLength = sentenceRange.end - sentenceRange.start
                    diff = (rangeLength < 0.5) ? rangeLength / 2.0 : 0.25
                    currentSentence.sentenceRange.start = diff.roundToMs()
                } else {
                    diff = 0.25
                    lastAlignedSentence.sentenceRange.end = (sentenceRange.start - diff).roundToMs()
                    interpolated[interpolated.count - 1] = lastAlignedSentence
                }
            }
            
            let startPoint = crossesAudioBoundary ? 0.0 : interpolated.last!.sentenceRange.end
            
            let interpolatedSentences = makeInterpolated(start: startPoint, duration:diff, startSentenceIndex:lastAlignedSentence.chapterSentenceId + 1 , count: missingCount, chapterSentences: chapterSentences, audioFile: gapAudioFile)
            interpolated += interpolatedSentences
            progressUpdate(interpolatedSentences.count)
            interpolated.append(currentSentence)
        }
        
        guard let last = interpolated.last else {
            return interpolated
        }
        
        let missingAtEnd = chapterSentences.count - last.chapterSentenceId - 1
        guard missingAtEnd > 0 else {
            return interpolated
        }
        
        let interpolatedSentences = makeInterpolated(start:  last.sentenceRange.end, duration:0.25, startSentenceIndex:last.chapterSentenceId + 1 , count: missingAtEnd, chapterSentences: chapterSentences, audioFile: last.sentenceRange.audioFile)
        interpolated += interpolatedSentences
        progressUpdate(interpolatedSentences.count)
        
        return interpolated
    }
    
    func fillInOffsets(
        _ alignedSentences: [AlignedSentence],
        using timeline: [WordTimeStamp]
    ) -> [AlignedSentence] {
        if alignedSentences.isEmpty {
            return alignedSentences
        }
                
        var out = alignedSentences
        
        let realSentences = alignedSentences.filter {
            guard let timeStamp = $0.sentenceRange.timeStamps.first else {
                return false
            }
            return timeStamp.token != missingTimeStampToken
        }
        

        let assignedTimeStamps =  Set( realSentences.flatMap {
            $0.sentenceRange.timeStamps
        }.map { $0.index })
        
        
        let absoluteStart = max(0,alignedSentences.first!.sentenceRange.absoluteStart - 60)
        let absoluteEnd = alignedSentences.last!.sentenceRange.absoluteStart + 60
        let unassignedTimeStamps = timeline.filter {
            if $0.absoluteStart < absoluteStart  || $0.absoulteEnd > absoluteEnd {
                return false
            }
            return !assignedTimeStamps.contains( $0.index )
        }
        
        for i in 0..<out.count {
            let alignedSentence = out[i]
            let sentenceRange = alignedSentence.sentenceRange
            guard let wt = sentenceRange.timeStamps.first else {
                continue
            }
            if wt.token != missingTimeStampToken {
                continue
            }

            let filePath = sentenceRange.audioFile.filePath
            let windowStart = sentenceRange.start
            let windowEnd   = sentenceRange.end
            
            let realTimeStamps = unassignedTimeStamps.compactMap { (timeStamp) -> WordTimeStamp? in
                if timeStamp.audioFile.filePath != filePath {
                    return nil
                }
                if timeStamp.start < windowStart || timeStamp.end > windowEnd {
                    return nil
                }
                return timeStamp
            }

            if !realTimeStamps.isEmpty {
                sentenceRange.timeStamps = realTimeStamps
                out[i] = alignedSentence.with(sentenceRange: sentenceRange, matchType: .recoverable)
                continue
            }

            let prevEnd = (i > 0 ? out[i-1].sentenceRange.timeStamps.last?.endOffset : nil) ?? -1
            let nextStart = (i + 1 < out.count ? out[i+1].sentenceRange.timeStamps.first?.startOffset : nil) ?? prevEnd
            var fill = WordTimeStamp(
                token: missingTimeStampToken,
                start: wt.start,
                end: wt.end,
                audioFile: sentenceRange.audioFile,
                voiceLen: -1,
                segmentIndex: -1,
                tokenTypeGuess: .missing
            )
            fill.startOffset = prevEnd + 1
            fill.endOffset = nextStart > 0 ? nextStart - 1 : prevEnd + 1
            sentenceRange.timeStamps = [fill]
            out[i] = alignedSentence.with(sentenceRange: sentenceRange, matchType: .interpolated)
        }
        
        return out
    }
    
    
    /**
     * Given two sentence ranges, find the trailing gap of the first
     * and the leading gap of the second, and return the larger gap
     * and corresponding audiofile.
     */
    func getLargestGap(trailing: SentenceRange, leading: SentenceRange) -> (Double, AudioFile) {
        let leadingGap = leading.start
        let duration = trailing.audioFile.duration
        let trailingGap = duration - trailing.end

        if trailingGap > leadingGap {
            return (trailingGap, trailing.audioFile)
        }
        return (leadingGap, leading.audioFile)
    }

    
}

extension Aligner {
    func rebuildIfNeeded( alignedSentence:AlignedSentence, alignedSentences:[AlignedSentence] ) -> [AlignedSentence] {
        
        let sentenceRange = alignedSentence.sentenceRange
        let chapterSentence = alignedSentence.chapterSentence
        let chapterSentenceIdOffset = (alignedSentences.first?.chapterSentenceId ?? 0) - 0

        var rebuiltSentences:[AlignedSentence] = []
        
        if chapterSentence.isEmpty || chapterSentence.isAllWhiteSpaceOrPunct {
            if chapterSentence.count < 3 {
                //these are usually single " or a ". or similar. They should be pushed off the the next sentence or appended to previous one.
                logger.log(.debug, "FIXME \(chapterSentence)" )
            }
        }
        
        let words = chapterSentence.split(separator: " ")
        let duration = sentenceRange.duration
        let secondsPerWord = duration / Double(words.count)
        if !alignedSentence.sharedTimeStamp && secondsPerWord >= 0.1 {
            return []
        }
        
        if !alignedSentence.sharedTimeStamp && alignedSentence.matchType != .interpolated {
            return []
        }
        logger.log(.debug, "Suspicious \(alignedSentence)")

        let audioFile = alignedSentence.sentenceRange.audioFile.filePath
        guard let nextFoundSentence = ( alignedSentences.first { $0.sentenceRange.audioFile.filePath == audioFile && $0.chapterSentenceId > alignedSentence.chapterSentenceId && $0.matchType != .interpolated && !$0.sharedTimeStamp }) else {
            return []
        }
        guard let prevFoundSentence = (alignedSentences.reversed().first { $0.sentenceRange.audioFile.filePath == audioFile && $0.chapterSentenceId < alignedSentence.chapterSentenceId && ( ($0.matchType != .interpolated && !$0.sharedTimeStamp) || $0.chapterSentenceId == 0)  }) else {
            return []
        }
        let durationToAllocate = nextFoundSentence.sentenceRange.end - prevFoundSentence.sentenceRange.start
        var lastEnd:TimeInterval = prevFoundSentence.sentenceRange.start
        
        let sentences = Array(alignedSentences[(prevFoundSentence.chapterSentenceId-chapterSentenceIdOffset) ... (nextFoundSentence.chapterSentenceId-chapterSentenceIdOffset)])
        
        //let segmentIndexes = sentences.flatMap { $0.sentenceRange.segmentIndexes }
        //let segments = segmentIndexes.map { segments[$0] }
        
        let totalVlen = sentences.map { sentence in
            return ( sentence.chapterSentence + " " ).voiceLength
        } .reduce(0, +)
        let secondsPerVlen = durationToAllocate / totalVlen
        
        for sentence in sentences {
            defer {
                rebuiltSentences.append(sentence)
            }
            
            let vlen = (sentence.chapterSentence + " ").voiceLength
            let nuSentenceDuration:TimeInterval = Double(vlen) * secondsPerVlen
            sentence.sentenceRange.start = lastEnd.roundToMs()
            if sentence.chapterSentenceId != nextFoundSentence.chapterSentenceId {
                let newEnd:TimeInterval = lastEnd + nuSentenceDuration
                if newEnd > sentence.sentenceRange.start {
                    sentence.sentenceRange.end = newEnd.roundToMs()
                    lastEnd = newEnd
                }
            }
        }
        
        return rebuiltSentences
    }
    
    
    func expandEmptySentenceRanges(alignedSentences: [AlignedSentence], segments:[TranscriptionSegment]) -> (all:[AlignedSentence], rebuilt:[AlignedSentence]) {
        var expandedSentences = [AlignedSentence]()
        var rebuiltSentences = [AlignedSentence]()
        var rebuiltIds = Set<Int>()
        
        for alignedSentence in alignedSentences {
            let sentenceRange = alignedSentence.sentenceRange
            let chapterSentence = alignedSentence.chapterSentence
            
            if chapterSentence.isEmpty || chapterSentence.isAllWhiteSpaceOrPunct {
                if chapterSentence.count < 3 {
                    //these are usually single " or a ". or similar. They should be pushed off the the next sentence or appended to previous one.
                    logger.log(.debug, "FIXME \(chapterSentence)" )
                }
            }
            
            let rebuilt = rebuildIfNeeded(alignedSentence: alignedSentence, alignedSentences: alignedSentences)
            for r in rebuilt {
                if !rebuiltIds.contains(r.chapterSentenceId) {
                    rebuiltSentences.append(r)
                    rebuiltIds.insert(r.chapterSentenceId)
                }
            }
            
            if let previousSentence = expandedSentences.last {
                // If the previous range's end overlaps this sentence's start
                // and they belong to the same audio file, nudge the start.
                if previousSentence.sentenceRange.end > sentenceRange.start &&
                    previousSentence.sentenceRange.audioFile.filePath == sentenceRange.audioFile.filePath {
                    sentenceRange.start = previousSentence.sentenceRange.end
                }
                
                // If the end time is not greater than the start time, adjust it.
                if sentenceRange.end <= sentenceRange.start {
                    sentenceRange.end = sentenceRange.start + 0.001
                    logger.log(.debug, "Expanded empty sentence range to avoid zero duration.")
                }
            }
            let nuSentence = alignedSentence.with(sentenceRange: sentenceRange, matchType: alignedSentence.matchType)
            expandedSentences.append(nuSentence)
        }
        
        return (expandedSentences,rebuiltSentences)
    }
}

extension Aligner {
    func exportTestJson( withAlignedSentences alignedSentences: [AlignedSentence], chapterSentences:[String], skippedSentences:[SkippedSentence], transcription:Transcription )  {
        let startChapterSentenceId = max( 0 , skippedSentences.first!.chapterSentenceId - 5)
        let endChapterSentenceId = min( skippedSentences.last!.chapterSentenceId + 5 , chapterSentences.count - 1 )
        let chapterText = chapterSentences[startChapterSentenceId...endChapterSentenceId].joined(separator: " ")
        
        let firstAlignedSentence = alignedSentences.first { $0.chapterSentenceId == startChapterSentenceId }
        let lastAlignedSentence = alignedSentences.first { $0.chapterSentenceId == endChapterSentenceId }
        let startTimeStamp = firstAlignedSentence!.sentenceRange.timeStamps.first!
        let endTimeStamp = lastAlignedSentence!.sentenceRange.timeStamps.last!
        
        let wordTimeLine = Array(transcription.wordTimeline[startTimeStamp.index...endTimeStamp.index])
        
        
        let startOffset = startTimeStamp.startOffset
        let endOffset = endTimeStamp.endOffset
        let transcriptionText = transcription.transcription.safeSubstring(from: startOffset, to: endOffset)
        
        print( "Chapter Text: \(chapterText)\n\n")
        print( "Transcription text: \(transcriptionText)\n\n")
        

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let encodedTimeLine = try! encoder.encode(wordTimeLine)
        try! encodedTimeLine.write(to: URL(fileURLWithPath: "/tmp/timeline.json"))
    }
}
