//
// WhisperTranscriber.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import AVFoundation
import NaturalLanguage
import whisper

typealias WhisperCtx = OpaquePointer

/*
struct WhisperSegment : Hashable,Codable, TranscriptionSegment {
    var tokens: [TranscriptionToken] { whisperTokens }
    
    var audioFile: AudioFile
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    var whisperTokens:[WhisperToken] = []
    var voiceLen = 0
    var needsRepair:Bool = false
    
    var duration:TimeInterval {
        end - start
    }
}
 */


/*
 whisper_token id;  // token id
 whisper_token tid; // forced timestamp token id

 float p;           // probability of the token
 float plog;        // log probability of the token
 float pt;          // probability of the timestamp token
 float ptsum;       // sum of probabilities of all timestamp tokens

 // token-level timestamp data
 // do not use if you haven't computed token-level timestamps
 int64_t t0;        // start time of the token
 int64_t t1;        //   end time of the token

 // [EXPERIMENTAL] Token-level timestamps with DTW
 // do not use if you haven't computed token-level timestamps with dtw
 // Roughly corresponds to the moment in audio in which the token was output
 int64_t t_dtw;

 float vlen;
 */

/*
struct WhisperToken : Hashable, Codable, TranscriptionToken {
    var dtw:TimeInterval
    let tokenData:whisper_token_data
    let tokenStr: String
    
    var text:String { tokenStr }
    var start:TimeInterval { TimeInterval(tokenData.t0) / 100.0 }
    var end:TimeInterval { TimeInterval(tokenData.t1) / 100.0 }


    func hash(into hasher: inout Hasher) {
        hasher.combine(dtw)
        hasher.combine(tokenStr)
        hasher.combine(tokenData.id)
        hasher.combine(tokenData.tid)
        hasher.combine(tokenData.p)
        hasher.combine(tokenData.plog)
        hasher.combine(tokenData.pt)
        hasher.combine(tokenData.ptsum)
        hasher.combine(tokenData.t0)
        hasher.combine(tokenData.t1)
    }

    static func ==(lhs: WhisperToken, rhs: WhisperToken) -> Bool {
        return lhs.dtw       == rhs.dtw
        && lhs.tokenStr  == rhs.tokenStr
        && lhs.tokenData.id  == rhs.tokenData.id
        && lhs.tokenData.tid == rhs.tokenData.tid
        && lhs.tokenData.p   == rhs.tokenData.p
        && lhs.tokenData.plog   == rhs.tokenData.plog
        && lhs.tokenData.pt   == rhs.tokenData.pt
        && lhs.tokenData.ptsum   == rhs.tokenData.ptsum
        && lhs.tokenData.t0   == rhs.tokenData.t0
        && lhs.tokenData.t1   == rhs.tokenData.t1
    }
    
    enum CodingKeys: String, CodingKey {
        case dtw
        case tokenStr
        case id
        case tid
        case p
        case plog
        case pt
        case ptsum
        case t0
        case t1
        case vlen
    }
    
    init( dtw:TimeInterval, tokenData:whisper_token_data, tokenStr:String ) {
        self.dtw = dtw
        self.tokenData = tokenData
        self.tokenStr = tokenStr
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dtw = try container.decode(TimeInterval.self, forKey: .dtw)
        tokenStr = try container.decode(String.self, forKey: .tokenStr)
        let id = try container.decode(Int32.self, forKey: .id)
        let tid = try container.decode(Int32.self, forKey: .tid)
        let p = try container.decode(Float.self, forKey: .p)
        let plog = try container.decode(Float.self, forKey: .plog)
        let pt = try container.decode(Float.self, forKey: .pt)
        let ptsum = try container.decode(Float.self, forKey: .ptsum)
        let t0 = try container.decode(Int64.self, forKey: .t0)
        let t1 = try container.decode(Int64.self, forKey: .t1)
        let vlen = try container.decode(Float.self, forKey: .vlen)
        tokenData = whisper_token_data(id: id, tid: tid, p: p, plog: plog, pt: pt, ptsum: ptsum, t0: t0, t1: t1, t_dtw: Int64(dtw*100), vlen:vlen)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dtw, forKey: .dtw)
        try container.encode(tokenStr, forKey: .tokenStr)
        try container.encode(tokenData.id, forKey: .id)
        try container.encode(tokenData.tid, forKey: .tid)
        try container.encode(tokenData.p, forKey: .p)
        try container.encode(tokenData.plog, forKey: .plog)
        try container.encode(tokenData.pt, forKey: .pt)
        try container.encode(tokenData.ptsum, forKey: .ptsum)
        try container.encode(tokenData.t0, forKey: .t0)
        try container.encode(tokenData.t1, forKey: .t1)
        try container.encode(tokenData.vlen, forKey: .vlen)
    }

}
*/

/*
func tokenizeTranscript(_   ctx: OpaquePointer?, transcript: String,) -> Set<Int32> {
    let maxTokens = transcript.count
    let buffer = UnsafeMutablePointer<whisper_token>.allocate(capacity: Int(maxTokens) )
    defer {
        buffer.deallocate()
    }
    
    let nTokens = whisper_tokenize(ctx, transcript, buffer, Int32(maxTokens))
    var ids = Set<Int32>()
    for i in 0..<Int(nTokens) {
        ids.insert(buffer[i])
    }
    return ids
}*/


/*
private let whisperLogitsFilterCallBack:whisper_logits_filter_callback = { (_ ctx: OpaquePointer?,_ state: OpaquePointer?, _ tokens: UnsafePointer<whisper_token_data>?,_ n_tokens: Int32, _ logits:UnsafeMutablePointer<Float>?,  _ userData: UnsafeMutableRawPointer?) in
    
    let BIAS: Float    = 5.0
    let NEG_INF: Float = -1e20
    
    let ids = tokenizeTranscript(ctx, transcript:"Proem - The Immerser" )
    let nVocab = whisper_n_vocab(ctx)
    for id in ids {
        logits![Int(id)] += BIAS
    }
}
*/

private let logCallback:ggml_log_callback = { (log_level:ggml_log_level, text:UnsafePointer<Int8>?, userData:UnsafeMutableRawPointer?) in
    guard let userData else {
        return
    }
    guard let text else {
        return
    }
    
    let sessionConfig = Unmanaged<SessionConfig>
        .fromOpaque(userData).takeUnretainedValue()
    
    let str = String(cString:text)

    let logLevel:LogLevel =  {
        switch log_level {
            case GGML_LOG_LEVEL_NONE:
                return .error
            case  GGML_LOG_LEVEL_DEBUG:
                return .debug
            case GGML_LOG_LEVEL_INFO:
                return .info
            case GGML_LOG_LEVEL_WARN:
                return .warn
            case GGML_LOG_LEVEL_ERROR:
                return .error
            case GGML_LOG_LEVEL_CONT:
                return .error
            default:
                return .warn
        }
    }()
    
    sessionConfig.logger.log( logLevel, str )
}

private func whisperCppProgressCallBack(_ ctx: OpaquePointer?,_ state: OpaquePointer?, _ progress: Int32, _ userData: UnsafeMutableRawPointer?) {
    guard let userData else {
        return
    }
    let whisperProgressUpdater = Unmanaged<WhisperProgressUpdater>
        .fromOpaque(userData).takeUnretainedValue()
    whisperProgressUpdater.updateProgress(percent: Int(progress))
}

class WhisperProgressUpdater : SessionConfigurable {
    let sessionConfig:SessionConfig
    let fullAudioDuration:TimeInterval
    let audioFile:AudioFile
    var lastReportedProgress:TimeInterval = 0
    
    init(sessionConfig: SessionConfig, audioFile: AudioFile, fullAudioDuration: TimeInterval,) {
        self.sessionConfig = sessionConfig
        self.fullAudioDuration = fullAudioDuration
        self.audioFile = audioFile
    }
    
    func updateProgress(percent:Int) {
        let progress = (audioFile.duration * Double(percent) / 100) ///60.0
        let incr = progress - lastReportedProgress
        if incr <= 0 {
            return
        }
        sessionConfig.progressUpdater?.updateProgress(for: .transcribe, msgPrefix: "Transcribing audio", increment: incr, total: fullAudioDuration, unit: .seconds)
        lastReportedProgress = progress
    }
}



func setupWhisperLogging( sessionConfig:SessionConfig ) {
    let ptr = Unmanaged.passUnretained(sessionConfig).toOpaque()
    whisper_log_set(logCallback, ptr ) ;
}

struct WhisperTranscriber : Transcriber, SessionConfigurable {
    func buildTranscription(from rawTranscription: RawTranscription) throws -> Transcription {
        //let audioFile = transcription.audioFile
        let hydratedSegments = rawTranscription.segments
        let segments = mergeZeroDurationSegments(hydratedSegments)
        
        var rebuiltSegmentsCount = 0

        let wordTimeStamps = segments.enumerated().flatMap { (segIndex,seg) in
            let timeStamps = wordTimeStampsFrom(segment:seg, segmentIndex:segIndex, audioFile: seg.audioFile)
            let wordTimeStamps = tokenTimelineToWordTimeline(timeStamps)
            let adjustedTimeStamps = spreadCollapsedRuns(wordTimeStamps: wordTimeStamps, segmentStart: seg.start, segmentEnd: seg.end)
            let (repairedTimeStamps,didRebuild) = fixOutOfWhackDurations(adjustedTimeStamps, segmentStart: seg.start, segmentEnd: seg.end, force: seg.needsRepair)
            rebuiltSegmentsCount += didRebuild ? 1 : 0
            
            if repairedTimeStamps.hasDuplicateConsecutiveSpans()  {
                logger.log( .debug, "Transcription has duplicate consecutive spans in word timestamps" )
            }
            if repairedTimeStamps.hasOverlaps  {
                logger.log( .debug, "Transcription has overlaps word timestamps" )
            }
            return repairedTimeStamps
        }
            
        if wordTimeStamps.hasOverlaps {
            logger.log( .warn, "Transcription has overlaps in word timestamps" )
        }
        
        if wordTimeStamps.hasDuplicateConsecutiveSpans()  {
            logger.log( .warn, "Transcription has duplicate consecutive spans in word timestamps" )
        }
            
        let normalizedResults = normalizeToSpelledWords(wordTimeLine:wordTimeStamps)
        let transcriptionTxt = normalizedResults.map { $0.token }.joined()
        
        let indexedTimeStamps = normalizedResults.enumerated().map { ( index, timeStamp ) in
            var nuTimeStamp = timeStamp
            nuTimeStamp.index = index
            return nuTimeStamp
        }
        
        logger.log( .info, "Rebuilt \(rebuiltSegmentsCount) of \(segments.count) segments")
        
        let transcription = Transcription(transcription: transcriptionTxt, segments: hydratedSegments, wordTimeline: indexedTimeStamps)
        return transcription
    }
    
    let sessionConfig:SessionConfig

    func transcribe(audioFile: AudioFile , fullAudioDuration: TimeInterval) async throws -> RawTranscription {
        let audioLoader = AudioLoaderFactory.audioLoader(for: sessionConfig )

        logger.log(.debug, "\nBeginning decode of \(audioFile.filePath.lastPathComponent)" )
        let pcmSamples = try await audioLoader.decode(from: audioFile.filePath)
        logger.log( .debug, "Decode completed -- \(pcmSamples.count) samples")

                   
        setupWhisperLogging( sessionConfig: sessionConfig )


        let context = try WhisperContextPool.acquire( sessionConfig: sessionConfig )

        let progressUpdater = WhisperProgressUpdater(sessionConfig: sessionConfig, audioFile: audioFile, fullAudioDuration: fullAudioDuration)
        let initialPrompt = ""
        let fullParams = WhisperFullParams( withInitialPrompt:initialPrompt, whisperProgressUpdater: progressUpdater, sessionConfig:sessionConfig)

        let transcription = try doTranscription(context: context, params: fullParams, pcmSamples: pcmSamples, audioFile:audioFile )

        // In case whisper didn't call for 100%
        progressUpdater.updateProgress(percent: 100)
        WhisperContextPool.release(whisperContext: context)

        return transcription
    }
}


extension WhisperTranscriber {
    func doTranscription(context:WhisperContext, params:WhisperFullParams, pcmSamples:[Float], audioFile:AudioFile/*, ebook:EpubDocument?*/ ) throws -> RawTranscription {
        let nSamples = Int32(pcmSamples.count)
        let ctx = context.ctx
        
        let ret = whisper_full(ctx, params.params, pcmSamples, nSamples)
        
        guard ret == 0 else {
            throw StoryAlignError( "Whisper transcription failed with error code \(ret)" )
        }
        
        let bareSegments = segments(from: context, audioFile:audioFile)
        
        
        let segStr = bareSegments.map { "\($0.start) to \($0.end): \($0.text)" }.joined(separator: "\n")
        logger.log(.debug, "Segments: \(segStr)" )
        
        
        let hydratedSegments = bareSegments.enumerated().map { (segIndex, seg) in
            let whisperTokens = tokens(from:context, seg: seg, segIndex:  segIndex)
            let nuSeg = seg.with( tokens:whisperTokens )
            return nuSeg
        }
        
        return RawTranscription( segments: hydratedSegments )
    }

    func mergeZeroDurationSegments(_ segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        var result: [TranscriptionSegment] = []
        
        var i = 0
        while i < segments.count {
            let seg = segments[i]
            
            if !seg.isFastPaced && seg.start != seg.end {
                result.append(seg)
                i += 1
                continue
            }
            
            
            let next = (i < segments.count-1) ? segments[i+1] : nil

            
            if !result.isEmpty {
                let prev = result.removeLast()
                
                let nuText = prev.text + seg.text + (next?.text ?? "")
                let nuTokens = prev.tokens + seg.tokens + (next?.tokens ?? [])
                let nuEnd = (next?.end ?? seg.end)
                let nuSeg = TranscriptionSegment(text: nuText, start: prev.start, end: nuEnd, audioFile: seg.audioFile, tokens: nuTokens, needsRepair: true)
                result.append(nuSeg)
                i += next != nil ? 2 : 1
                continue
            }
            guard let next else {
                result.append(seg)
                i+=1
                continue
            }
            let nuText = seg.text + next.text
            let nuTokens = seg.tokens + next.tokens
            let nuEnd = next.end
            let nuSeg = TranscriptionSegment(text: nuText, start: seg.start, end: nuEnd, audioFile: seg.audioFile,tokens: nuTokens, needsRepair: true)
            result.append(nuSeg)
            i += 2
            continue
        }
        return result
    }
    
    func wordTimeStampsFrom( segment:TranscriptionSegment, segmentIndex:Int, audioFile:AudioFile ) -> [WordTimeStamp] {
        
        let whisperTokens = segment.tokens
        let timeStamps:[WordTimeStamp]  = whisperTokens.enumerated().map { (i,whisperToken:TranscriptionToken) -> WordTimeStamp in
            let tokenStr = whisperToken.text
            let dtw = whisperToken.dtw
            let a = whisperToken.start
            let b = whisperToken.end
            let rawStart = min(a, b)
            let rawEnd   = max(a, b)

            let (start,end ) = {
                if !sessionConfig.whisperDtw || dtw < 0 {
                    return (rawStart, rawEnd)
                }

                let prevInfo = i > 0 ? whisperTokens[i - 1] : nil
                let nextInfo = i < whisperTokens.count - 1 ? whisperTokens[i + 1] : nil
                
                let prevAnchor = prevInfo?.dtw ?? rawStart
                let nextAnchor = nextInfo?.dtw ?? dtw
                
                if rawEnd == rawStart && dtw != prevAnchor && dtw != nextAnchor {
                    let start = (prevAnchor + dtw) / 2
                    let end   = (dtw + nextAnchor) / 2
                    return( start, end )
                }
                
                let start = max(rawStart, min((prevAnchor + dtw)/2, rawEnd))
                let end   = min(rawEnd,   max((dtw + nextAnchor)/2, rawStart))
                return (start,end)
            }()

            let timeStamp = WordTimeStamp( token: tokenStr, start: start, end: end,  audioFile: audioFile, voiceLen: whisperToken.voiceLen, segmentIndex: segmentIndex, tokenTypeGuess: .other , index:-1 )
            
            return timeStamp
        }
        return timeStamps
    }
    
    func segments( from whisperCtx:WhisperContext, audioFile:AudioFile ) -> [TranscriptionSegment] {
        let ctx = whisperCtx.ctx
        let nSegments = whisper_full_n_segments(ctx)
        let segments:[TranscriptionSegment] = (0 ..< nSegments).compactMap  { (i)->TranscriptionSegment? in
            guard let segTextC = whisper_full_get_segment_text(ctx, i) else {
                return nil
            }
            let segText = String(cString: segTextC)
            let segStart = whisper_full_get_segment_t0(ctx, i)
            let segEnd = whisper_full_get_segment_t1(ctx, i)
            
            let segStartTmeInterval = TimeInterval(segStart)/100.0
            let segEndTmeInterval = TimeInterval(segEnd)/100.0
            
            let segment = TranscriptionSegment( text: segText, start: segStartTmeInterval, end: segEndTmeInterval,audioFile:audioFile, tokens:[] )
            return segment
        }
        return segments
    }
    
    func tokens( from whisperCtx:WhisperContext, seg:TranscriptionSegment, segIndex:Int ) -> [TranscriptionToken] {
        let ctx = whisperCtx.ctx
        let segIndex = Int32( segIndex )
        let nTokens = whisper_full_n_tokens(ctx, segIndex)
    
        let whisperTokens = (0 ..< nTokens ).compactMap { (tokenIndex)->TranscriptionToken? in
            guard let tokenC = whisper_full_get_token_text(ctx, segIndex, tokenIndex) else {
                return nil
            }
            let tokenData = whisper_full_get_token_data(ctx, segIndex, tokenIndex)
            let tokenStr = String(cString: tokenC)
            
            if tokenStr == "[_BEG_]" {
                if seg.start != Double(tokenData.t0)/100.0 {
                    logger.log( .debug, "[_BEG_] mismatch")
                }
                if tokenIndex == 0 {
                    if tokenData.t0 == 0 {
                        // I don't this this ever does anything,as seg.start is always gonna be 0 here, but we'll see
                        //correctionTimeOffset = seg.start
                        if seg.start != 0 {
                            logger.log( .debug, "seg.start != 0")
                        }
                    }
                }
                return nil
            }
            
            if tokenStr == "[BLANK_AUDIO]" {
                logger.log( .debug, "[BLANK_AUDIO]")
            }
            
            if ignoreSpecialToken(tokenStr) {
                return nil
            }
            
            let dtw = TimeInterval( tokenData.t_dtw)/100.0
            if dtw < 0 {
                if sessionConfig.whisperDtw {
                    logger.log(.debug, "Shouldn't happen: dtw < 0")
                    return nil
                }
            }
            
            return TranscriptionToken(text:tokenStr, start:Double(tokenData.t0)/100.0, end:Double(tokenData.t1)/100.0, voiceLen: Double(tokenData.vlen), dtw:dtw)
        }
        
        return whisperTokens
    }
    
    func fixOutOfWhackDurations(
        _ stamps: [WordTimeStamp],
        segmentStart: Double,
        segmentEnd: Double,
        force:Bool ,
        tolerance: Double = 0.1
    ) -> ( [WordTimeStamp], Bool ) {
        
        let segmentDuration = segmentEnd - segmentStart
        let totalVlens = stamps.reduce(0) { $0 + $1.voiceLen }
        
        if segmentDuration <= 0 {
            return (stamps, false)
        }
        if totalVlens <= 0 {
            return (stamps, false)
        }

        let expectedDurations = stamps.map { Double($0.voiceLen) / Double(totalVlens) * segmentDuration }
        let actualDurations   = stamps.map { $0.end - $0.start }

        let badCount = zip(expectedDurations, actualDurations)
            .filter { abs($0 - $1) > tolerance }
            .count

        let badLimit = Int(Double(stamps.count) * 0.8)
        if force || badCount >= badLimit {
            var out = [WordTimeStamp]()
            var cum = 0.0
            for ts in stamps {
                let dur   = Double(ts.voiceLen) / Double(totalVlens) * segmentDuration
                let start = segmentStart + cum
                cum += dur
                let end   = segmentStart + cum
                
                let roundedStart = start.roundToMs()
                let roundedEnd = end.roundToMs()

                out.append(WordTimeStamp(
                    token:            ts.token,
                    start:            roundedStart,
                    end:              roundedEnd,
                    audioFile:        ts.audioFile,
                    voiceLen:       ts.voiceLen,
                    segmentIndex: ts.segmentIndex,
                    tokenTypeGuess: ts.tokenTypeGuess
                ))
            }
            return ( out, true )
        }

        return (stamps, false)
    }
    
    func spreadCollapsedRuns(
        wordTimeStamps: [WordTimeStamp],
        segmentStart:   Double,
        segmentEnd:     Double
    ) -> [WordTimeStamp] {
        var out = [WordTimeStamp]()
        let count = wordTimeStamps.count
        let segmentFrames = wordTimeStamps.reduce(0) { $0 + $1.voiceLen }
 
        let frameDuration = segmentFrames > 0
            ? (segmentEnd - segmentStart) / Double(segmentFrames)
            : 0

        var i = 0
        while i < count {
            let s0 = wordTimeStamps[i].start
            let e0 = wordTimeStamps[i].end

            var j = i + 1
            while j < count
               && wordTimeStamps[j].start == s0
               && wordTimeStamps[j].end   == e0 {
                j += 1
            }

            let prevEnd = out.last?.end ?? segmentStart

            if j - i > 1 {
                let rawNextStart: Double = j < count ? wordTimeStamps[j].start : segmentEnd
                let bound = rawNextStart > prevEnd ? rawNextStart : segmentEnd
                let gap = max(0, bound - prevEnd)
                let run = wordTimeStamps[i..<j]
                let totalF = run.reduce(0) { $0 + $1.voiceLen }

                if totalF > 0 && gap > 0 {
                    var cum = 0.0
                    for ts in run {
                        let w     = ts.voiceLen / totalF
                        let start = prevEnd + cum * gap
                        cum += Double(w)
                        let end   = prevEnd + cum * gap
                        let clampedEnd = min( segmentEnd, end )
                        let roundedStart = start.roundToMs()
                        let roundedEnd = clampedEnd.roundToMs()
                        
                        out.append(WordTimeStamp(
                            token:            ts.token,
                            start:            roundedStart,
                            end:              roundedEnd,
                            audioFile:        ts.audioFile,
                            voiceLen:       ts.voiceLen,
                            segmentIndex: ts.segmentIndex,
                            tokenTypeGuess: ts.tokenTypeGuess
                        ))
                    }
                }
                else if totalF > 0 && gap == 0 && j == count {
                    var cumDur = 0.0
                    for ts in run {
                        let dur   = Double( ts.voiceLen ) * frameDuration
                        let start = prevEnd + cumDur
                        cumDur   += dur
                        let end   = prevEnd + cumDur
                        let clampedEnd = min( segmentEnd, end )
                        let roundedStart = start.roundToMs()
                        let roundedEnd = clampedEnd.roundToMs()
                        
                        out.append(WordTimeStamp(
                            token:            ts.token,
                            start:            roundedStart,
                            end:              roundedEnd,
                            audioFile:        ts.audioFile,
                            voiceLen:       ts.voiceLen,
                            segmentIndex:  ts.segmentIndex,
                            tokenTypeGuess: ts.tokenTypeGuess
                        ))
                    }
                }
                else {
                    out.append(contentsOf: run)
                }
            }
            else {
                let ts = wordTimeStamps[i]
                let s = max(ts.start, prevEnd).roundToMs()
                let e = min(ts.end, segmentEnd).roundToMs()
                
                out.append(WordTimeStamp(
                    token:            ts.token,
                    start:            s,
                    end:              e,
                    audioFile:        ts.audioFile,
                    voiceLen:       ts.voiceLen,
                    segmentIndex:  ts.segmentIndex,
                    tokenTypeGuess: ts.tokenTypeGuess
                ))
            }

            i = j
        }

        return out
    }

    func tokenTimelineToWordTimeline(_ tokenTimelineInput: [WordTimeStamp] ) -> [WordTimeStamp] {
        let tokens = tokenTimelineInput
        var groups: [[WordTimeStamp]] = []
        for (idx, entry) in tokens.enumerated() {
            let text = entry.token
            let prevText = idx > 0 ? tokens[idx - 1].token : nil
            if groups.isEmpty || text.isEmpty || startsWithSeparatorCharacter(text) || (prevText.map(endsWithSeparatorCharacter) ?? false) {
                let concatSeparatedNumber:Bool = {
                    let numberSeparator = ","
                    guard let prevText else {
                        return false
                    }
                    if !prevText.hasSuffix(numberSeparator) && !text.hasPrefix(numberSeparator) {
                        return false
                    }
                    if prevText.hasSuffix(numberSeparator) && text.hasPrefix(numberSeparator) {
                        return false
                    }
                    if prevText.endsWithWhiteSpace {
                        return false
                    }
                    if text.startsWithWhiteSpace {
                        return false
                    }
                    if text.hasPrefix(numberSeparator) {
                        if prevText.trimmed().allSatisfy( { String($0) == numberSeparator || $0.isDigit } ) {
                            return true
                        }
                        return false
                    }

                    if prevText.hasSuffix(numberSeparator) {
                        if text.trimmed().allSatisfy( { String($0) == numberSeparator || $0.isDigit } ) {
                            return true
                        }
                        return false
                    }
                    
                    return false
                }()
                
                if !concatSeparatedNumber {
                    groups.append([entry])
                    continue
                }
            }
            groups[groups.count - 1].append(entry)
        }
        
        /*
        var splitGroups: [[WordTimeStamp]] = []
        for (i, group) in groups.enumerated() {
            // This splits off periods at the end of sentences. I'm not sure why. It's not a good idea for out purposes because it can cause alignment to shorten and skip the period
            //let nextGroup = (i + 1 < groups.count) ? groups[i + 1] : nil
            //if group.count > 1 && group.last?.token == "." && (nextGroup == nil || [" ", "["].contains(nextGroup!.first!.token.first!)) {
            //splitGroups.append(Array(group.dropLast()))
            //splitGroups.append([group.last!])
            //} else {
                splitGroups.append(group)
            //}
        }
        groups = splitGroups
        */
        
        var result: [WordTimeStamp] = []
        for group in groups {
            let groupText = group.map { $0.token }.joined()
            if groupText.isEmpty { continue }
            let startTime = group.first!.start
            let endTime   = group.last!.end
            let voiceLen = group.reduce(0) { $0 + $1.voiceLen }
            
            let tokenTypeGuess:TokenTypeGuess = {
                if groupText.isAllWhiteSpaceOrPunct {
                    return .whiteSpaceAndPunct
                }
                let trimmedGrp = groupText.trimmed()
                if !trimmedGrp.isEmpty {
                    if trimmedGrp.last! == "." {
                        return .sentenceEnd
                    }
                    if trimmedGrp.first!.isUppercase {
                        return .sentenceBegin
                    }
                }
                
                return .other
            }()

            //let confidence: Double? = {
            //  guard group.first?.confidence != nil else { return nil }
            // return meanOfVector(group.compactMap { $0.confidence })
            //}()

            let entry = WordTimeStamp(
                //type: "word",
                //token: groupText.trim(),
                token: groupText,
                start: startTime,
                end: endTime,
                audioFile: group.first!.audioFile,
                voiceLen: voiceLen,
                segmentIndex: group.first!.segmentIndex,
                tokenTypeGuess: tokenTypeGuess
                //confidence: confidence,
                //timeline: group
            )
            result.append(entry)
        }
        return result
    }

    func isSeparatorCharacter(_ char: Character) -> Bool {
        let nonSeparatingPunctuation: Set<Character> = ["'", "-", ".", "·", "•"]
        //let nonSeparatingPunctuation: Set<Character> = ["'", "-", ".", "·", "•","\""]
        if nonSeparatingPunctuation.contains(char) { return false }
        return char.isWhitespace || char.isPunctuation
    }
    func startsWithSeparatorCharacter(_ text: String) -> Bool {
        if text.prefix(2) == "--" {
            return true
        }
        guard let first = text.first else { return false }
        return isSeparatorCharacter(first)
    }
    func endsWithSeparatorCharacter(_ text: String) -> Bool {
        if text.suffix(2) == "--" {
            return true
        }
        guard let last = text.last else { return false }
        return isSeparatorCharacter(last)
    }
    
    func ignoreSpecialToken(_ token:String ) -> Bool {
        let fullTokensToIgnore = ["<unk>", "[_EOS_]", "[_SOS_]", "[_EOT_]", "[_SOT_]", "[_TRANSLATE_]", "[_TRANSCRIBE_]",  "[_SOLM_]", "[_PREV_]" , "[_NOSP_]", "[_NOT_]" ]
        
        if fullTokensToIgnore.contains(token) {
            return true
        }
        
        let tokenPrefixesToIgnore: [String] = [ "[_TT_", "[_LANG_", "[_extra_token_" ]
        for pfx in tokenPrefixesToIgnore {
            if token.starts(with: pfx) {
                return true
            }
        }
        
        if token.starts(with: "[_") {
            logger.log(.debug, "Unkown special token \(token)" )
            return true
        }
        
        return false
    }
}

extension WhisperTranscriber {
    
    func normalizeToSpelledWords( wordTimeLine: [WordTimeStamp]) -> [WordTimeStamp] {
        let normalizer = WordNormalizer()
        var offsetDelta = 0
        return wordTimeLine.map { wordTimeStamp in
            let startOffset = wordTimeStamp.startOffset >= 0 ? wordTimeStamp.startOffset + offsetDelta : -1
            let endOffset = wordTimeStamp.endOffset >= 0 ? wordTimeStamp.endOffset + offsetDelta : -1
            let (normalizedWord, delta) = normalizer.normalizedWord(wordTimeStamp.token)
            offsetDelta += delta
            
            return wordTimeStamp.with(token: normalizedWord, startOffset: startOffset, endOffset: endOffset, )
        }
    }
}


class WhisperContext : SessionConfigurable {
    let sessionConfig: SessionConfig
    var ctx:OpaquePointer
    
    init( withModelFile:String, params:WhisperContextParams, sessionConfig: SessionConfig ) throws {
        self.sessionConfig = sessionConfig
        guard let ctx = whisper_init_from_file_with_params(withModelFile, params.params ) else {
            throw StoryAlignError("Unable to load whisper model")
        }
        self.ctx = ctx
    }
    
    deinit {
        whisper_free(ctx)
    }
}


class WhisperFullParams {
    var paramsPtr:UnsafeMutablePointer<whisper_full_params>
    var params:whisper_full_params {
        paramsPtr.pointee
    }
    
    /*
    var language:String {
        didSet {
            if languageCStr != nil {
                free( languageCStr )
            }
            languageCStr = strdup(self.language)!
            self.paramsPtr.pointee.language = UnsafePointer(languageCStr)
        }
    }
    var languageCStr :UnsafeMutablePointer<CChar>?
     */
    let initialPrompt:String
    let initialPromptCstr :UnsafeMutablePointer<CChar>?
    
    init( withInitialPrompt:String, whisperProgressUpdater progressUpdater:WhisperProgressUpdater, sessionConfig:SessionConfig ) {
        let maxThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        
        //paramsPtr = whisper_full_default_params_by_ref(WHISPER_SAMPLING_GREEDY)!
        paramsPtr = whisper_full_default_params_by_ref(WHISPER_SAMPLING_BEAM_SEARCH)!

        paramsPtr.pointee.print_realtime   = false
        paramsPtr.pointee.print_progress   = false
        paramsPtr.pointee.print_timestamps = false
        paramsPtr.pointee.no_timestamps     = false
        paramsPtr.pointee.print_special    = false
        paramsPtr.pointee.translate        = false
        paramsPtr.pointee.n_threads        = Int32(maxThreads)

        paramsPtr.pointee.offset_ms        = 0
        paramsPtr.pointee.no_context       = true
        paramsPtr.pointee.n_max_text_ctx  = 0
        paramsPtr.pointee.single_segment   = false
        paramsPtr.pointee.token_timestamps = true
        
        paramsPtr.pointee.suppress_nst = false
        paramsPtr.pointee.suppress_blank   = false

        //paramsPtr.pointee.no_speech_thold  = 0.3
        //paramsPtr.pointee.logprob_thold   = -0.5
        //paramsPtr.pointee.entropy_thold = 2.0
        //paramsPtr.pointee.max_initial_ts   = 5.0
        
        // 9 crashes, 8 makes things worse, it it seems, 5 is the default, 6 works significantly better than 5, and 7 works a little better than 6, at least on one book I tested.
        // 8 makes things better with larger models or when dtw is enabled
        // Actually lower beam sizes work better with the larger models it seems. need 7 or 8 for tiny and maybe base
        //paramsPtr.pointee.beam_search.beam_size = 7
        paramsPtr.pointee.beam_search.beam_size = Int32(sessionConfig.whisperBeamSize)
        //paramsPtr.pointee.beam_search.beam_size = 5

        //paramsPtr.pointee.beam_search.patience = 1.0
        //paramsPtr.pointee.temperature = 0.0
        
        paramsPtr.pointee.progress_callback = whisperCppProgressCallBack
        let ptr = Unmanaged.passUnretained(progressUpdater).toOpaque()
        paramsPtr.pointee.progress_callback_user_data = ptr
        
        //paramsPtr.pointee.logits_filter_callback = whisperLogitsFilterCallBack
        
        
        /*
         export const defaultWhisperOptions: WhisperOptions = {
             model: undefined,
             temperature: 0.1,
             prompt: undefined,
             topCandidateCount: 5,
             punctuationThreshold: 0.2,
             autoPromptParts: true,
             maxTokensPerPart: 250,
             suppressRepetition: true,
             repetitionThreshold: 2.4,
             decodeTimestampTokens: true,
             endTokenThreshold: 0.9,
             includeEndTokenInCandidates: true,
             timestampAccuracy: undefined,
             encoderProvider: undefined,
             decoderProvider: undefined,
             seed: undefined,
         }
         model: undefined,
         endTokenThreshold: 0.9,
         maxTokensPerPart: 250,
         timestampAccuracy: undefined,

         encoderProvider: undefined,

         */
        
        /*
        paramsPtr.pointee.strategy = WHISPER_SAMPLING_BEAM_SEARCH
        paramsPtr.pointee.beam_search.beam_size = 6
        paramsPtr.pointee.temperature = 0.0
         */
        
        // Auto-detect
        paramsPtr.pointee.language = nil
        /*
        self.language = "en"
        self.languageCStr = strdup(self.language)!
        params.language = UnsafePointer(languageCStr)
         */
        
        
        self.initialPrompt = withInitialPrompt
        self.initialPromptCstr = strdup(withInitialPrompt)!
        paramsPtr.pointee.initial_prompt = UnsafePointer(initialPromptCstr)
        
    }
    
    deinit {
        /*
        if languageCStr != nil {
            free( languageCStr )
        }
         */
        if initialPromptCstr != nil {
            free( initialPromptCstr )
        }
        whisper_free_params(paramsPtr)
    }
}



final class WhisperContextParams : @unchecked Sendable {
    var paramsPtr:UnsafeMutablePointer<whisper_context_params>
    var params:whisper_context_params {
        paramsPtr.pointee
    }
    
    init( sessionConfig:SessionConfig) {
        paramsPtr = whisper_context_default_params_by_ref()!
        //var params = paramsPtr.pointee
        
#if targetEnvironment(simulator)
        paparamsPtr.pointee.use_gpu = false
        print("Running on the simulator, using CPU")
#else
        paramsPtr.pointee.flash_attn = true
#endif

        paramsPtr.pointee.use_gpu    = true;
        paramsPtr.pointee.flash_attn = true;

        if sessionConfig.whisperDtw {
            paramsPtr.pointee.flash_attn = false;
            paramsPtr.pointee.dtw_token_timestamps = true;
            paramsPtr.pointee.dtw_aheads_preset = WHISPER_AHEADS_TINY ;
        }
    }
    
    deinit {
        whisper_free_context_params(paramsPtr)
    }
}


class WhisperContextPool {
    static let serialQueue = DispatchQueue(label: "io.storyalign.WhisperContextPool")
    
    // Best not to cache these things as they act differently on subsequent uses on other threads. Still might be able to preload a pool for one-time use
    //nonisolated(unsafe) static var pool:[WhisperContext] = []
   
    static func acquire( sessionConfig:SessionConfig ) throws -> WhisperContext {
        let whisperContext = try Self.serialQueue.sync { () -> WhisperContext in
            //if !Self.pool.isEmpty {
            //return Self.pool.removeFirst()
            //}
            let modelPath = sessionConfig.modelFile
            let contextParams = WhisperContextParams( sessionConfig: sessionConfig)
            sessionConfig.logger.log( .debug, "Loading whisper model from \(modelPath)")
            let whisperContext = try  WhisperContext(withModelFile: modelPath, params: contextParams, sessionConfig: sessionConfig)
            sessionConfig.logger.log( .debug, "Completed load from \(modelPath)\n\n")
            
            return whisperContext
        }
        return whisperContext
    }
     
    static func release( whisperContext:WhisperContext ) {
        //Self.serialQueue.sync { () in
        //Self.pool.append(whisperContext)
        //}
     }
    
}
