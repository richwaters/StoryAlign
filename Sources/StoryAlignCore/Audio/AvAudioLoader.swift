//
// AvAudioLoader.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters


import Foundation
import AVFoundation


struct AvAudioLoader : AudioLoader {
    let sessionConfig: SessionConfig

    func getChapters(from url: URL) async throws -> [ChapterInfo] {
        let asset = AVURLAsset(url: url)
        let locales = try await asset.load(.availableChapterLocales)
        guard let locale = locales.first else {
            return []
        }
        let groups = try await asset.loadChapterMetadataGroups(
            withTitleLocale: locale,
            containingItemsWithCommonKeys: []
        )
        
        var chapters:[ChapterInfo] = []
        for group in groups {
            let start = group.timeRange.start.seconds
            let duration = group.timeRange.duration.seconds
            let end = start + duration
            
            let title:String? = try await {
                guard let item = group.items.first(where: { $0.commonKey == .commonKeyTitle }) else {
                    return nil
                }
                let retTitle = try await item.load(.stringValue)
                return retTitle
            }()

            chapters.append( ChapterInfo( start: start, end: end, title:title ) )
        }
        return chapters
    }
    
    func extractAudio(from url: URL, using audioFileInfo: AudioFile) async throws {
        let asset = AVURLAsset(url: url)
            
        let start = CMTime(seconds: audioFileInfo.startTmeInterval, preferredTimescale: 600)
        let end = CMTime(seconds: audioFileInfo.endTmeInterval, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "ExportError", code: -1)
        }
        exportSession.timeRange = timeRange
        try await exportSession.export( to: audioFileInfo.filePath,  as: .m4a )
    }
    
    
    func decode( from fileURL: URL ) async throws -> [Float] {
        return try load16kMonoPCM_viaAVAudioFile(fileURL)
    }
}

extension AvAudioLoader {
    func load16kMonoPCM_viaAVAudioFile(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let inFmt  = file.processingFormat
        let outFmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            //channels: inFmt.channelCount,
            channels: 1,
            interleaved: false
        )!
        let converter = AVAudioConverter(from: inFmt, to: outFmt)!
        converter.sampleRateConverterQuality = .max

        let inBuf = AVAudioPCMBuffer(
            pcmFormat: inFmt,
            frameCapacity: AVAudioFrameCount(file.length)
        )!
        try file.read(into: inBuf)
        
        let ratio     = outFmt.sampleRate / inFmt.sampleRate
        let outFrames = max( inBuf.frameCapacity, AVAudioFrameCount(Double(inBuf.frameLength) * ratio))
        let outBuf    = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: outFrames)!
        
        final class InputState: @unchecked Sendable {
            let fmt: AVAudioFormat
            let channels: [UnsafePointer<Float>]
            var pos: AVAudioFramePosition = 0
            init(fmt: AVAudioFormat, buf: AVAudioPCMBuffer) {
                self.fmt = fmt
                let fcd = buf.floatChannelData!
                let n = Int(fmt.channelCount)
                self.channels = (0..<n).map { UnsafePointer(fcd[$0]) }
            }
        }

        let state = InputState(fmt: inFmt, buf: inBuf)
        let totalInputFrames = AVAudioFramePosition(inBuf.frameLength)

        let inputBlock:AVAudioConverterInputBlock = { inNumPackets, outStatus in
            let framesLeft = totalInputFrames - state.pos
            guard framesLeft > 0 else { outStatus.pointee = .endOfStream; return nil }
            let n = min(AVAudioFrameCount(framesLeft), inNumPackets)
            let chunk = AVAudioPCMBuffer(pcmFormat: state.fmt, frameCapacity: n)!
            chunk.frameLength = n
            for ch in 0..<state.channels.count {
                let src = state.channels[ch].advanced(by: Int(state.pos))
                let dst = chunk.floatChannelData![ch]
                dst.update(from: src, count: Int(n))
            }
            state.pos &+= AVAudioFramePosition(n)
            outStatus.pointee = .haveData
            return chunk
        }

        var error: NSError?
        let status = converter.convert(to: outBuf, error: &error, withInputFrom: inputBlock)
        guard status == .haveData || status == .endOfStream else {
            throw error ?? NSError(domain: "AudioConversion", code: -1, userInfo: nil)
        }

        let ptr = outBuf.floatChannelData![0]
        let count = Int(outBuf.frameLength)
        return Array(UnsafeBufferPointer(start: ptr, count: count))
    }
}
