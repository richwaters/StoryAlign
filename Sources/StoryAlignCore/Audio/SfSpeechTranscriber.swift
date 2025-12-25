//
// SfSpeechTransxciber.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//


// Don't use this. It doesn't really work as it's soooo slow. Use the new SFSpeechAnalyzer with macOS26 instead
//

import Foundation
import Speech

struct SfSpeechToken  {
    let start:TimeInterval
    let duration:TimeInterval
    let text:String
}


struct SfSpeechTranscriber : Transcriber {
    let sessionConfig: SessionConfig

    func buildTranscription(from rawTranscription: RawTranscription) throws -> Transcription {
        let wordTimeStamps = rawTranscription.segments.enumerated().flatMap { (segIndex, transcriptionSegment) in
            let tokens = transcriptionSegment.tokens.map { sfSpeechToken in
                
                let wordTimeStamp = WordTimeStamp(
                    token: sfSpeechToken.text,
                    start: sfSpeechToken.start,
                    end: sfSpeechToken.end,
                    audioFile: transcriptionSegment.audioFile,
                    transcriptionTokens: [sfSpeechToken],
                    //voiceLen:-1,
                    segmentIndex: segIndex,
                    tokenTypeGuess: .other,
                    //timeConfidence: sfSpeechToken.timeConfidence,
                    //textConfidence: sfSpeechToken.textConfidence
                )
                return wordTimeStamp
            }
            return tokens
        }
        
        let transcriptionTxt = wordTimeStamps.map { $0.token }.joined( separator: " " )
        let transcription = Transcription( transcription: transcriptionTxt, segments: rawTranscription.segments, wordTimeline: wordTimeStamps)
        return transcription
    }
    
    
    func transcribe(audioFile: AudioFile, fullAudioDuration: TimeInterval) async throws -> RawTranscription {
        let sfSpeechSegments = try await recognizeSfSpeech(in: audioFile, fullAudioDuration: fullAudioDuration)
        return RawTranscription(segments: sfSpeechSegments)
    }
}

extension SfSpeechTranscriber {
    func recognizeSfSpeech( in audioFile:AudioFile, fullAudioDuration:TimeInterval  ) async throws -> [TranscriptionSegment]  {
        
        let locale = Locale(identifier: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw StoryAlignError( "Speech recognition not available" )
        }
        recognizer.supportsOnDeviceRecognition = true

        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioFile.filePath)
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.addsPunctuation = true
        recognitionRequest.shouldReportPartialResults = false
        //recognitionRequest.taskHint = .dictation
        
        let progressUpdater = sessionConfig.progressUpdater
        
        //var wordTimeLine:[WordTimeStamp] = []
        var segments:[TranscriptionSegment] = []
        var segIndex = 0
        
        await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: recognitionRequest ) { result, error in
                if let error = error {
                    print("Recognition error: \(error)")
                    continuation.resume()
                    return
                }
                
                guard let result = result else {
                    print("No speech detected")
                    continuation.resume()
                    return
                }
                
                defer {
                    if result.isFinal {
                        continuation.resume()
                    }
                }
                
                let bestTranscription = result.bestTranscription
                let sfSpeechSegments = bestTranscription.segments.filter { seg in
                    if seg.timestamp == 0 {
                        // Partial result -- still parsing -- see: https://stackoverflow.com/questions/58795543/speechkit-function-result-called-multiple-times/62253498#62253498
                        return false
                    }
                    return true
                }
                
                let transcriptionSegments = sfSpeechSegments.enumerated().compactMap { (index, seg) in
                    let segmentTokens:[TranscriptionToken] =  {
                        let segText = seg.substring
                        let words = segText.components(separatedBy: " ")
                        if words.count == 0 {
                            return []
                        }
                        let timeStep:TimeInterval = seg.timestamp/TimeInterval(words.count)
                        let wordDuration = seg.duration/TimeInterval(words.count)
                        let tokens = words.enumerated().map { offset, word in
                            let start = timeStep*Double(offset)
                            let end = start + wordDuration
                            let token = TranscriptionToken(text: word, start: start, end:end, voiceLen:-1, dtw:-1, timeConfidence: Double(seg.confidence), textConfidence: Double(seg.confidence))
                            return token
                        }
                        progressUpdater?.updateProgress(for: .transcribe, msgPrefix: "Transcribing audio", increment: seg.duration, total: fullAudioDuration, unit: .seconds)
                        //print( tokens )
                        return tokens
                    }()
                    segIndex += index
                    let transcriptionSegment = TranscriptionSegment(text: seg.substring, start: seg.timestamp, end: seg.timestamp+seg.duration, audioFile: audioFile, tokens: segmentTokens)
                    return transcriptionSegment
                }
                segments += transcriptionSegments
            }
        }
        return segments
    }
}
