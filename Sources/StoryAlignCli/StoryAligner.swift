//
// StoryAligner.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import ZIPFoundation
import StoryAlignCore

struct StoryAligner {
    let sessionConfig:SessionConfig
    var logger:Logger { sessionConfig.logger }

    func alignStory(epubPath: String, audioPath: String, outputURL: URL ) async throws -> AlignmentReport? {
        let epubURL = URL(fileURLWithPath: epubPath)
        let audioURL = URL(fileURLWithPath: audioPath)
        var stageRunTimes:[ProcessingStage:Range<TimeInterval>]
        var stageStartTme:TimeInterval

        let persistedState = try PersistedStoryAlignState(with:sessionConfig)
        stageRunTimes = persistedState?.stageRunTimes ?? [:]
        
        stageStartTme = Date().timeIntervalSinceReferenceDate
        let (eBook,didRunEpub) = try await  loadOrParseEBook(from: epubURL, persistedState: persistedState )
        if didRunEpub {
            stageRunTimes[.epub] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate
            try persistIfApplicable(stageRunTimes: stageRunTimes, eBook: eBook )
        }
        
        if sessionConfig.runStage < .audio {
            return nil
        }
        stageStartTme = Date().timeIntervalSinceReferenceDate
        let (audioBook,didRunAudio) = try await loadOrParseAudioBook(from: audioURL, extractingInto: eBook.opfURL.deletingLastPathComponent(), persistedState: persistedState )
        if didRunAudio {
            stageRunTimes[.audio] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate
            try persistIfApplicable(stageRunTimes: stageRunTimes, eBook: eBook, audioBook: audioBook )
        }

        if sessionConfig.runStage < .transcribe {
            return nil
        }
        stageStartTme = Date().timeIntervalSinceReferenceDate
        let (transcriptions,didRunTranscribe) = try await loadOrTranscribe(audioBook:audioBook, eBook: eBook, persistedState: persistedState )
        if didRunTranscribe {
            stageRunTimes[.transcribe] = stageStartTme ..< Date().timeIntervalSinceReferenceDate
            try persistIfApplicable(stageRunTimes: stageRunTimes, eBook: eBook, audioBook: audioBook , transcriptions: transcriptions)
        }
        
        if sessionConfig.runStage < .align {
            return nil
        }
        stageStartTme = Date().timeIntervalSinceReferenceDate
        let (alignedChapters,didRunAlign) = try await loadOrAlign(ebook: eBook, audioBook: audioBook, transcriptions: transcriptions, persistedState: persistedState )
        if didRunAlign {
            stageRunTimes[.align] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate
            try persistIfApplicable(stageRunTimes: stageRunTimes, eBook: eBook, audioBook: audioBook , transcriptions: transcriptions, alignedChapters: alignedChapters)
        }
        
        if sessionConfig.runStage < .xml {
            return nil
        }
        if sessionConfig.runStage == .xml || !(persistedState?.xmlFileUpdateCompleted ?? false) {
            logger.log(.timestamp, "Updating XML ... ")
            stageStartTme = Date().timeIntervalSinceReferenceDate
            try await XMLUpdater(sessionConfig: sessionConfig).updateXml(forEbook: eBook, audioBook: audioBook, alignedChapters: alignedChapters, )
            stageRunTimes[.xml] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate

            logger.log(.timestamp, "XML update complete.")
            try persistIfApplicable(stageRunTimes: stageRunTimes, eBook: eBook, audioBook: audioBook , transcriptions: transcriptions, alignedChapters: alignedChapters, xmlFileUpdateCompleted: true)
        }
        
        if sessionConfig.runStage < .export {
            return nil
        }
        
        if sessionConfig.runStage == .export || !(persistedState?.exportCompleted ?? false) {
            logger.log(.timestamp, "Exporting epub ... ")
            stageStartTme = Date().timeIntervalSinceReferenceDate
            try EpubExporter(sessionConfig: sessionConfig).export(eBook: eBook, to: outputURL )
            stageRunTimes[.export] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate
            logger.log(.timestamp, "Epub export complete")
            try persistIfApplicable(stageRunTimes: stageRunTimes, eBook: eBook, audioBook: audioBook , transcriptions: transcriptions, alignedChapters: alignedChapters, xmlFileUpdateCompleted: true, exportCompleted:true)
        }
        
        stageStartTme = Date().timeIntervalSinceReferenceDate
        stageRunTimes[.report] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate
        let reportBuilder = AlignmentReportBuilder(sessionConfig: sessionConfig, alignedChapters: alignedChapters, rawTranscriptions: transcriptions, stageRunTimes: stageRunTimes)
        var rpt = reportBuilder.buildReport( epubPath: epubURL, audioPath: audioURL, outPath: outputURL)
        stageRunTimes[.report] =  stageStartTme ..< Date().timeIntervalSinceReferenceDate
        rpt.stageRunTimes = stageRunTimes

        if sessionConfig.reportType == .none {
            //sessionConfig.progressUpdater?.updateProgress(for: .report, msgPrefix: "Completed", increment: 1, total: 1, unit: .none )
            return nil
        }
        
        return rpt
    }
}


private extension StoryAligner {
    
    private func loadOrParseEBook( from url:URL, persistedState: PersistedStoryAlignState?) async throws -> (epub:EpubDocument, didRun:Bool) {
        if sessionConfig.runStage != .epub {
            if let ebook = persistedState?.epubDocument {
                return (ebook,false)
            }
        }
        logger.log(.timestamp, "Parsing ebook ... ")
        let epub = try await EpubParser(sessionConfig: sessionConfig).parse(url:url)
        logger.log(.timestamp, "Epub parsing complete")
        return (epub,true)
    }
    
    private func loadOrParseAudioBook( from url:URL,  extractingInto:URL, persistedState: PersistedStoryAlignState? ) async throws -> (audioBook:AudioBook,didRun:Bool) {
        if sessionConfig.runStage != .audio {
            if let audiobook = persistedState?.audioBook {
                return (audiobook, false)
            }
        }
        logger.log(.timestamp, "Parsing audio ... ")
        let audioBook = try await M4BParser(sessionConfig: sessionConfig).parse(url: url, extractingInto: extractingInto)
        logger.log(.timestamp, "Audio extraction complete")
        return (audioBook, true)
    }
    
    private func loadOrTranscribe( audioBook: AudioBook, eBook: EpubDocument, persistedState: PersistedStoryAlignState? ) async throws -> (rawTranscription:[RawTranscription], didRun:Bool) {
        
        if sessionConfig.runStage != .transcribe {
            if let transcriptions = persistedState?.transcriptions {
                return (transcriptions,false)
            }
        }
        
        logger.log(.timestamp, "Starting transcription")
        let transcriber = TranscriberFactory.transcriber(forSessionConfig: sessionConfig)
        let transcriptions = try await transcriber.transcribe(audioBook: audioBook, for: eBook)
        logger.log(.timestamp, "Completed transcription")
        
        return (transcriptions,true)
    }
    
    private func loadOrAlign( ebook:EpubDocument, audioBook: AudioBook, transcriptions:[RawTranscription], persistedState: PersistedStoryAlignState? )  async throws -> (alignedChapters:[AlignedChapter], didRun:Bool) {
        if sessionConfig.runStage != .align {
            if let alignedChapters = persistedState?.alignedChapters {
                return (alignedChapters,false)
            }
        }
        logger.log(.timestamp, "Starting alignment")
        let alignedChapters = try await Aligner(sessionConfig: sessionConfig).align(ebook: ebook, AudioBook: audioBook, rawTranscriptions: transcriptions)
        logger.log(.timestamp, "Completed alignment")

        return (alignedChapters,true)
    }

}


private extension StoryAligner {
    func persistIfApplicable( stageRunTimes:[ProcessingStage:Range<TimeInterval>], eBook:EpubDocument?, audioBook:AudioBook? = nil , transcriptions:[RawTranscription]? = nil, alignedChapters:[AlignedChapter]? = nil, xmlFileUpdateCompleted:Bool? = nil, exportCompleted:Bool? = nil ) throws {
        if sessionConfig.runStage == .all {
            return
        }
        let persistedState = PersistedStoryAlignState( epubDocument: eBook, audioBook: audioBook, transcriptions: transcriptions, alignedChapters: alignedChapters, xmlFileUpdateCompleted: xmlFileUpdateCompleted, exportCompleted: exportCompleted, stageRunTimes: stageRunTimes)
        try persistedState.save(with: sessionConfig)
    }
}
