//
// AudioBook.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation

public struct AudioBook : Codable {
    public let audioFiles:[AudioFile]
}

public struct AudioFile : Codable, Hashable, Sendable {
    let startTmeInterval:TimeInterval
    let endTmeInterval:TimeInterval
    let filePath:URL
    let index:Int
    
    func with(
        startTmeInterval: TimeInterval? = nil,
        endTmeInterval: TimeInterval? = nil,
        filePath: URL? = nil,
        index: Int? = nil
    ) -> Self {
        .init(
            startTmeInterval: startTmeInterval ?? self.startTmeInterval,
            endTmeInterval: endTmeInterval ?? self.endTmeInterval,
            filePath: filePath ?? self.filePath,
            index: index ?? self.index
        )
    }

    var duration:TimeInterval { endTmeInterval - startTmeInterval }
    
    var href:String {
        "Audio/\(filePath.lastPathComponent)"
    }
    
    var itemId:String {
        "audio_\(filePath.deletingPathExtension().lastPathComponent)"
    }
    var mediaType:String {
        "audio/mp4"
    }
}


struct ChapterInfo: Codable {
    let start:TimeInterval
    let end: TimeInterval
    let title:String?
}
