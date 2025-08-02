//
//  SentenceRange.swift
//
// SPDX-License-Identifier: MIT
//
// Original source Copyright (c) 2023 Shane Friedman
// Translated and modified Copyright (c) 2025 Rich Waters
//

import Foundation

enum SentenceMatchType : Int, Codable {
    case exact
    case trimmedLeading
    case ignoringEndsPunctuation
    case ignoringAllPunctuation
    case nearest
    case interpolated
    case recoverable
    
}

public struct AlignedSentence : Codable,Sendable {
    let chapterSentence:String
    let chapterSentenceId:Int
    let sentenceRange:SentenceRange
    let matchText:String?
    let matchOffset:Int?
    let matchType:SentenceMatchType?
    var sharedTimeStamp = false

    func with(
        chapterSentence: String? = nil,
        chapterSentenceId: Int? = nil,
        sentenceRange: SentenceRange? = nil,
        matchText: String? = nil,
        matchOffset: Int? = nil,
        matchType: SentenceMatchType? = nil,
        sharedTimeStamp: Bool? = nil
    ) -> Self {
        .init(
            chapterSentence: chapterSentence ?? self.chapterSentence,
            chapterSentenceId: chapterSentenceId ?? self.chapterSentenceId,
            sentenceRange: sentenceRange ?? self.sentenceRange,
            matchText: matchText ?? self.matchText,
            matchOffset: matchOffset ?? self.matchOffset,
            matchType: matchType ?? self.matchType,
            sharedTimeStamp: sharedTimeStamp ?? self.sharedTimeStamp
        )
    }
    
    var chapterSentenceWords:[String] {
        chapterSentence.components(separatedBy: " ")
    }
    
    var secondsPerWord:Double {
        if chapterSentenceWords.isEmpty {
            return 0.0
        }
        let secondsPerWord = sentenceRange.duration / Double(chapterSentenceWords.count)
        return secondsPerWord
    }
    var secondsPerChar:Double {
        if chapterSentence.isEmpty {
            return 0.0
        }
        let secondsPerChar = sentenceRange.duration / Double(chapterSentence.count)
        return secondsPerChar
    }
    
    var secondsPerVlen:Double {
        if chapterSentence.isEmpty {
            return 0.0
        }
        let secondsPerChar = sentenceRange.duration / chapterSentence.voiceLength
        return secondsPerChar
    }
}

extension AlignedSentence : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "\(chapterSentenceId): \(chapterSentence) -- Transcription sentenceRange \(sentenceRange)"
    }
    
    public var debugDescription: String {
        description
    }
}


struct SkippedSentence : Codable, Sendable {
    let chapterSentence:String
    let chapterSentenceId:Int
}




class SentenceRange: Codable, @unchecked Sendable {
    let id: Int
    var start: TimeInterval
    var end: TimeInterval
    var audioFile: AudioFile
    var timeStamps:[WordTimeStamp]
    
    func with(
        id: Int? = nil,
        start: TimeInterval? = nil,
        end: TimeInterval? = nil,
        audioFile: AudioFile? = nil,
        timeStamps: [WordTimeStamp]? = nil
    ) -> SentenceRange {
        .init(
            id: id ?? self.id,
            start: start ?? self.start,
            end: end ?? self.end,
            audioFile: audioFile ?? self.audioFile,
            timeStamps: timeStamps ?? self.timeStamps
        )
    }
    
    var duration:TimeInterval {
        end - start
    }
    
    var timeStampDuration:TimeInterval {
        (timeStamps.last?.end ?? end) - (timeStamps.first?.start ?? start)
    }
    
    var absoluteStart:TimeInterval {
        return audioFile.startTmeInterval + start
    }
    var absoulteEnd:TimeInterval {
        return audioFile.startTmeInterval + end
    }
    
    var sentenceText:String {
        timeStamps.map { $0.token }.joined(separator: " ").collapseWhiteSpace()
    }
    
    var segmentIndexes: [Int] {
        Array( Set( self.timeStamps.compactMap { $0.segmentIndex >= 0 ? $0.segmentIndex : nil } ) ).sorted()
    }
    
    init(id: Int, start: TimeInterval, end: TimeInterval, audioFile: AudioFile, timeStamps:[WordTimeStamp]) {
        self.id = id
        self.start = start
        self.end = end
        self.audioFile = audioFile
        self.timeStamps = timeStamps
    }
}


extension SentenceRange : CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        "SentenceRange(id: \(id), start: \(start), end: \(end), audioFile: \"\(audioFile.filePath.lastPathComponent)\") timeStampSentence: \(sentenceText)"
    }
    
    var debugDescription:String {
        description
    }
}


extension [SentenceRange] {
    var duration:TimeInterval {
        var duration:TimeInterval = 0
        var audioFile: AudioFile? = nil
        var start:TimeInterval = 0
        var end:TimeInterval = 0
        
         for sentenceRange in self {
            if sentenceRange.audioFile.filePath != audioFile?.filePath {
                duration += end - start
                start = sentenceRange.start
                audioFile = sentenceRange.audioFile
            }
            end = sentenceRange.end
        }
        duration += end - start
        return duration
    }
}
