//
// Transcriber.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import NaturalLanguage
import whisper

fileprivate let fastPaceThreshold = 0.15

public enum TranscriberType:Int, Codable {
    case whisper
    case sfspeech
}

public struct TranscriptionToken : Codable,Sendable, Equatable,Hashable {
    let text:String
    let start:TimeInterval
    let end:TimeInterval
    let voiceLen:Double
    let dtw:TimeInterval
    let timeConfidence:Double
    let textConfidence:Double
    
    func with(
           text: String? = nil,
           start: TimeInterval? = nil,
           end: TimeInterval? = nil,
           voiceLen: Double? = nil,
           dtw: TimeInterval? = nil,
           timeStampConfidence:Double? = nil,
           textConfidence:Double? = nil
       ) -> TranscriptionToken {
           let tt = TranscriptionToken(
               text:    text    ?? self.text,
               start:   start   ?? self.start,
               end:     end     ?? self.end,
               voiceLen: voiceLen ?? self.voiceLen,
               dtw:     dtw     ?? self.dtw,
               timeConfidence: timeStampConfidence ?? self.timeConfidence,
               textConfidence: textConfidence ?? self.textConfidence
           )
           return tt
       }
}
extension TranscriptionToken : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "\(text) Start: \(start) End: \(end) voiceLen:\(voiceLen) dtw:\(dtw)"
    }
    public var debugDescription: String {
        description
    }
}


public struct TranscriptionSegment:Codable,Sendable {
    var text:String
    var start:TimeInterval
    var end:TimeInterval
    let audioFile:AudioFile
    var tokens:[TranscriptionToken]
    var needsRepair:Bool=false
    
    func with(
           text: String? = nil,
           start: TimeInterval? = nil,
           end: TimeInterval? = nil,
           audioFile: AudioFile? = nil,
           tokens: [TranscriptionToken]? = nil
       ) -> TranscriptionSegment {
           TranscriptionSegment(
               text: text ?? self.text,
               start: start ?? self.start,
               end: end ?? self.end,
               audioFile: audioFile ?? self.audioFile,
               tokens: tokens ?? self.tokens
           )
       }
    
    var duration:Double { end - start }
    var tokenDuration : Double { (tokens.last?.end ?? end) - (tokens.first?.start ?? start)}
    var words:[String] { text.components(separatedBy: " ") }
    public var secondsPerWord:Double { duration / Double(words.count) }
    var isFastPaced:Bool { secondsPerWord < fastPaceThreshold }
    var endGap:Double { end - (tokens.last?.end ?? 0) }
    var startGap:Double { (tokens.first?.start ?? 0) - start}
    var voiceLen:Double {
        guard !tokens.isEmpty else { return text.voiceLength }
        return tokens.reduce(0) { $0 + $1.voiceLen }
    }
    var secondsPerVoiceLen:Double { duration/voiceLen }
}

extension TranscriptionSegment : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "\(text) Start: \(start) End: \(end) Duration: (\(duration)  secondsPerWord:\(secondsPerWord) startGap:\(startGap) endGap:\(endGap)  ) "
    }
    public var debugDescription: String {
        description
    }
}

public enum TokenTypeGuess:Int,Codable,Sendable {
    case whiteSpaceAndPunct
    case sentenceEnd
    case sentenceBegin
    case other
    case missing
    
}

public struct WordTimeStamp:Codable, Hashable,Sendable {
    let token: String
    let start: TimeInterval
    let end: TimeInterval
    let audioFile:AudioFile
    let transcriptionTokens:[TranscriptionToken]
    let segmentIndex:Int
    let tokenTypeGuess:TokenTypeGuess
    var index:Int = -1
    var startOffset: Int = -1
    var endOffset: Int = -1
    var isInterpolated:Bool = false
    var isRebuilt:Bool = false
    
    var origStart:TimeInterval {
        transcriptionTokens.first?.start ?? start
    }
    var origEnd:TimeInterval {
        transcriptionTokens.last?.end ?? end
    }
    var origDuration:TimeInterval {
        self.origEnd-self.origStart
    }
    
    var timeConfidence:Double {
        var weighted = 0.0
        var total = 0.0
        for transcriptionToken in transcriptionTokens {
            let c = transcriptionToken.timeConfidence
            let d = max(0, transcriptionToken.end - transcriptionToken.start)
            if d <= 0 { continue }
            weighted += c * d
            total += d
        }
        if total <= 0 { return  0.0 }
        return weighted / total
    }
    var textConfidence:Double {
        var weighted = 0.0
        var total = 0.0
        for transcriptionToken in transcriptionTokens {
            let c = transcriptionToken.textConfidence
            let d = max(0, transcriptionToken.end - transcriptionToken.start)
            if d <= 0 { continue }
            weighted += c * d
            total += d
        }
        if total <= 0 { return  0.0 }
        return weighted / total
    }
    
    var voiceLen:Double {
        guard !transcriptionTokens.isEmpty else { return token.voiceLength }
        return transcriptionTokens.reduce(0.0) { $0 + $1.voiceLen }
    }

    func with(
        token: String? = nil,
        start: TimeInterval? = nil,
        end: TimeInterval? = nil,
        startOffset: Int? = nil,
        endOffset: Int? = nil,
        audioFile: AudioFile? = nil,
        transcriptionTokens:[TranscriptionToken]? = nil,
        index: Int? = nil,
        segmentIndex: Int? = nil,
        tokenTypeGuess:TokenTypeGuess? = nil,
        isInterpolated:Bool? = nil,
        isRebuilt:Bool? = nil,

    ) -> WordTimeStamp {
        let ts = WordTimeStamp(            
            token: token ?? self.token,
            start: start ?? self.start,
            end: end ?? self.end,
            audioFile: audioFile ?? self.audioFile,
            transcriptionTokens: transcriptionTokens ?? self.transcriptionTokens,
            segmentIndex: segmentIndex ?? self.segmentIndex,
            tokenTypeGuess: tokenTypeGuess ?? self.tokenTypeGuess,
            index: index ?? self.index,
            startOffset: startOffset ?? self.startOffset,
            endOffset: endOffset ?? self.endOffset,
            isInterpolated: isInterpolated ?? self.isInterpolated,
            isRebuilt: isRebuilt ?? self.isRebuilt,
        )

        return ts
    }
    

    func merged(with other: WordTimeStamp) -> WordTimeStamp {
        let mergedStartOffset: Int
        if startOffset >= 0 && other.startOffset >= 0 {
            mergedStartOffset = min(startOffset, other.startOffset)
        } else if startOffset >= 0 {
            mergedStartOffset = startOffset
        } else if other.startOffset >= 0 {
            mergedStartOffset = other.startOffset
        } else {
            mergedStartOffset = -1
        }
        
        let mergedEndOffset: Int
        if endOffset >= 0 && other.endOffset >= 0 {
            mergedEndOffset = max(endOffset, other.endOffset)
        } else if endOffset >= 0 {
            mergedEndOffset = endOffset
        } else if other.endOffset >= 0 {
            mergedEndOffset = other.endOffset
        } else {
            mergedEndOffset = -1
        }
        
        let nuStamp = self.with(
            token: token + other.token,
            start: min(start, other.start),
            end: max(end, other.end),
            startOffset: mergedStartOffset,
            endOffset: mergedEndOffset,
            transcriptionTokens: self.transcriptionTokens + other.transcriptionTokens,
            isInterpolated: isInterpolated || other.isInterpolated,
            isRebuilt: isRebuilt || other.isRebuilt,
        )
        return nuStamp
    }
    
    var absoluteStart:TimeInterval {
        return audioFile.startTmeInterval + start
    }
    var absoluteEnd:TimeInterval {
        return audioFile.startTmeInterval + end
    }
    
    var duration:TimeInterval {
        (end - start).roundToMs()
    }
}

extension WordTimeStamp : CustomStringConvertible, CustomDebugStringConvertible {
    public var description : String {
        return "\(token): offsets:\(startOffset) -> \(endOffset), startTime:\(start), endTime:\(end)"
    }
    public var debugDescription: String {
        description
    }
}

extension [WordTimeStamp] {
    var debugDescription : String {
        return self.map { $0.debugDescription}.joined(separator: "\n")
    }
    
    var hasOverlaps : Bool {
        if self.isEmpty {
            return false
        }
        for i in 0..<self.count - 1 {
            if self[i].audioFile.filePath != self[i+1].audioFile.filePath {
                continue
            }
            if  self[i].end > self[i+1].start {
                return true
            }
        }
        return false
    }
    
    var hasEndBeforeStart:Bool {
        for i in 0..<self.count - 1 {
            if self[i].end < self[i].start {
                return true
            }
        }
        return false
    }
    
    func hasDuplicateConsecutiveSpans() -> Bool {
        guard count > 1 else { return false }
        let n = Swift.min(count,3)
        var hasDups = false
        for i in 0..<(count - n){
            let start = self[i].start
            let end = self[i].end
            let audioFile = self[i].audioFile
            for j in 1 ..< n  {
                if self[i+j].start != start || self[i+j].end != end  || self[i+j].audioFile.filePath != audioFile.filePath {
                    hasDups = false
                    break
                }
                hasDups = true
            }
            if hasDups {
                return true
            }
        }
        return hasDups
    }
}



public struct Transcription: Sendable {
    let transcription:String
    public let segments:[TranscriptionSegment]
    let wordTimeline: [WordTimeStamp]
    var sentences:[String] = []
    var sentencesOffsets:[Range<Int>] = []
    var offsetToIndexMap:[Int:String.Index] = [:]
    
    func indexOfSentence(containingOffset offset:Int) -> Int? {
        var low = 0
        var high = sentencesOffsets.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let range = sentencesOffsets[mid]
            if range.contains(offset) {
                return mid
            }
            if range.lowerBound < offset {
                low = mid + 1
                continue
            }
            
            high = mid - 1
        }
        return nil
    }
    
    func indexOfChar( atOffset:Int ) -> String.Index? {
        return offsetToIndexMap[atOffset]
    }
}

public struct RawTranscription:Codable, Sendable {
    public let segments:[TranscriptionSegment]
    
    var fastPacedSegments:[TranscriptionSegment] {
        segments.filter { $0.isFastPaced }
    }
}

public protocol Transcriber : Sendable, SessionConfigurable {
    func transcribe( audioFile:AudioFile, fullAudioDuration:TimeInterval  ) async throws -> RawTranscription
    func buildTranscription( from rawTranscription:RawTranscription ) throws -> Transcription
}

public struct TranscriberFactory {
    static public func transcriber( forSessionConfig:SessionConfig ) -> Transcriber {
        //return SfSpeechTranscriber(sessionConfig: forSessionConfig )
        
        return WhisperTranscriber( sessionConfig: forSessionConfig )
    }
}

public extension Transcriber {
    func transcribe(  audioBook:AudioBook, for epub:EpubDocument ) async throws -> [RawTranscription] {
        sessionConfig.progressUpdater?.updateProgress(for: .transcribe, msgPrefix: "Transcribing audio ...", increment: 0, total: 0, unit:.none)
        
        let totalDuration = (audioBook.audioFiles.reduce(0) { $0 + $1.duration })  // /60.0
        
        let nThreads = sessionConfig.throttle ? 1 : 0
        return try await audioBook.audioFiles.enumerated().asyncMap(concurrency: nThreads) { (index,audioFile) in
            //logger.log(.timestamp, "Transcribing \(index+1)/\(total)" )
            let rawTranscription = try await transcribe(audioFile: audioFile, fullAudioDuration: totalDuration) //   , context:ctx )
            //logger.log( .timestamp, "Complete transcription \(index+1)/\(total)" )
            return rawTranscription
        }
    }
}

public extension Transcription {
    static func concatTranscriptions(_ transcriptions: [Transcription], maxSentenceLen:Int? = nil, meanSentenceLen:Int? = nil  ) -> Transcription {
        var index = 0
        var offset = 0
        var fullTranscription = transcriptions.reduce( Transcription(transcription: "", segments: [], wordTimeline: []) ) { acc, current in
            let mergedTranscript = acc.transcription + current.transcription
            let segIndex = acc.segments.count
                        
            let adjustedTimeline = current.wordTimeline.map { entry in
                let timestamp = entry.with(startOffset:offset, endOffset:max( offset, offset + entry.token.count - 1), index:index, segmentIndex: entry.segmentIndex + segIndex)
                index += 1
                offset += entry.token.count
                return timestamp
            }
            let mergedSegments = acc.segments + current.segments
            
            let mergedTimeline = acc.wordTimeline + adjustedTimeline
            
            
            return Transcription(
                transcription: mergedTranscript,
                segments: mergedSegments,
                wordTimeline: mergedTimeline
            )
        }
        
        let longestSentenceLen = maxSentenceLen ?? NSInteger.max
        let avgSentenceLen = meanSentenceLen ?? 128
        
        let tokenizer = Tokenizer()

        fullTranscription.sentences = tokenizer.tokenizeSentences(text: fullTranscription.transcription)
            .flatMap { (sentence) -> [String] in
                if sentence.count < (longestSentenceLen) {
                    return [sentence]
                }
                let chunkedSentence = sentence.chunked(minLength: avgSentenceLen)
                return chunkedSentence
            }
        
        var offset2 = 0
        fullTranscription.sentencesOffsets = fullTranscription.sentences.map { (sentence) -> Range<Int> in
            let endOffset = offset2 + sentence.count
            let range = offset2..<endOffset
            offset2 = endOffset
            return range
        }

        fullTranscription.offsetToIndexMap = fullTranscription.transcription.buildOffsetsToIndices()
        
        return fullTranscription
    }
}

