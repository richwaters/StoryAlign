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

public struct TranscriptionToken : Codable,Sendable {
    let text:String
    let start:TimeInterval
    let end:TimeInterval
    let voiceLen:Double
    let dtw:TimeInterval
    
    func with(
           text: String? = nil,
           start: TimeInterval? = nil,
           end: TimeInterval? = nil,
           voiceLen: Double? = nil,
           dtw: TimeInterval? = nil
       ) -> TranscriptionToken {
           TranscriptionToken(
               text:    text    ?? self.text,
               start:   start   ?? self.start,
               end:     end     ?? self.end,
               voiceLen: voiceLen ?? self.voiceLen,
               dtw:     dtw     ?? self.dtw
           )
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
    var voiceLen:Double { tokens.reduce(0) { $0 + $1.voiceLen } }
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
    let voiceLen:Double
    let segmentIndex:Int
    let tokenTypeGuess:TokenTypeGuess
    var index:Int = -1
    var startOffset: Int = -1
    var endOffset: Int = -1
    
    func with(
        token: String? = nil,
        start: TimeInterval? = nil,
        end: TimeInterval? = nil,
        startOffset: Int? = nil,
        endOffset: Int? = nil,
        audioFile: AudioFile? = nil,
        voiceLen: Double? = nil,
        index: Int? = nil,
        segmentIndex: Int? = nil,
        tokenTypeGuess:TokenTypeGuess? = nil
    ) -> WordTimeStamp {
        WordTimeStamp(
            token: token ?? self.token,
            start: start ?? self.start,
            end: end ?? self.end,
            audioFile: audioFile ?? self.audioFile,
            voiceLen: voiceLen ?? self.voiceLen,
            segmentIndex: segmentIndex ?? self.segmentIndex,
            tokenTypeGuess: tokenTypeGuess ?? self.tokenTypeGuess,
            index: index ?? self.index,
            startOffset: startOffset ?? self.startOffset,
            endOffset: endOffset ?? self.endOffset,
        )
    }
    
    var absoluteStart:TimeInterval {
        return audioFile.startTmeInterval + start
    }
    var absoulteEnd:TimeInterval {
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
        for i in 0..<self.count - 1 {
            if self[i].audioFile.filePath != self[i+1].audioFile.filePath {
                continue
            }
            //let roundedEnd = (self[i].end * 100).rounded() / 100
            //let roundedNextStart = (self[i+1].start * 100).rounded() / 100
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



public struct Transcription:/*Codable,*/ Sendable {
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
                let timestamp = WordTimeStamp(
                    token: entry.token,
                    start: entry.start,
                    end: entry.end,
                    audioFile: entry.audioFile,
                    voiceLen: entry.voiceLen,
                    segmentIndex: entry.segmentIndex + segIndex,
                    tokenTypeGuess: entry.tokenTypeGuess,
                    index:index,
                    startOffset: offset,
                    endOffset: max( offset, offset + entry.token.count - 1),
                )
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

        fullTranscription.sentences = NLTokenizer.tokenizeSentences(text: fullTranscription.transcription)
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

