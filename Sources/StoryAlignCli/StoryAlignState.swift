//
// StoryAlignState.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//
//

import Foundation
import StoryAlignCore

fileprivate let filename = "persistedStoryAlignState.json"

struct PersistedStoryAlignState : Codable {
    let epubDocument:EpubDocument?
    let audioBook:AudioBook?
    let transcriptions:[RawTranscription]?
    let alignedChapters:[AlignedChapter]?
    let xmlFileUpdateCompleted:Bool?
    let exportCompleted:Bool?
    let stageRunTimes:[ProcessingStage:Range<Double>]
    
    init?( with sessionConfig:SessionConfig ) throws {
        if sessionConfig.runStage == .all || sessionConfig.runStage == .epub {
            return nil
        }
        let url = sessionConfig.sessionDir.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: url.path) {
            sessionConfig.logger.log( .warn, "No persisted state file found at '\(url.path)'. Rebuilding unspecified stages" )
            return nil
        }
        
        sessionConfig.logger.log( .info, "Loading persisted state '\(url.path)'" )
        let data = try Data(contentsOf: url)
        self = try JSONDecoder().decode(Self.self, from: data)
        sessionConfig.logger.log( .info, "Completed persisted state restore" )
    }
}


extension PersistedStoryAlignState {
    init( epubDocument:EpubDocument?, audioBook:AudioBook?, transcriptions:[RawTranscription]?, alignedChapters:[AlignedChapter]?, xmlFileUpdateCompleted:Bool? = nil, exportCompleted:Bool? = nil, stageRunTimes:[ProcessingStage:Range<Double>] ) {
        self.epubDocument = epubDocument
        self.audioBook = audioBook
        self.transcriptions = transcriptions
        self.alignedChapters = alignedChapters
        self.xmlFileUpdateCompleted = xmlFileUpdateCompleted
        self.exportCompleted = exportCompleted
        self.stageRunTimes = stageRunTimes
    }
    
    func save( with sessionConfig:SessionConfig ) throws {
        let url = sessionConfig.sessionDir.appendingPathComponent(filename)
        if let _ = try? url.checkResourceIsReachable() {
            try FileManager.default.removeItem(at: url)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

