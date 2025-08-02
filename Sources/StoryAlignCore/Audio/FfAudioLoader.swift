//
//  FFAudioLoader.swift
//  StoryAlign
//
//  Created by Rich Waters on 4/26/25.
//


import Foundation


struct FfAudioLoader : AudioLoader {
    let sessionConfig: SessionConfig

    func decode(from fileURL: URL) async throws -> [Float] {
        let audioData = try await FfMpegger().run(withArguments: [
            "-i", fileURL.path,
            "-f", "f32le",
            "-acodec", "pcm_f32le",
            "-ac", "1",
            "-ar", "16000",
            "-"  
        ])

        let sampleCount = audioData.count / MemoryLayout<Float>.size
        let floats: [Float] = audioData.withUnsafeBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            return Array(floatBuffer.prefix(sampleCount))
        }
        
        return floats
    }
    
    
    
    func extractAudio( from url:URL, using audioFileInfo:AudioFile ) async throws {
        let args = [
          "-vn",
          "-ss",
          "\(audioFileInfo.startTmeInterval)",
          "-to",
          "\(audioFileInfo.endTmeInterval)",
          "-i",
          url.absoluteString,
          "-c:a",
          "copy",
          audioFileInfo.filePath.absoluteString
        ]
        
        try await FfMpegger().run(withArguments: args)
    }
    
    /*
    func getTrackInfo( from url:URL ) async throws -> AudioBookInfo {
        let ffTrackInfo:FfmpegTrackInfo = try await FFProber().run(withArguments: [
            "-i",
            url.absoluteString,
            "-show_format",
            "-of",
            "json"
        ])
        return ffTrackInfo.format
    }
     */
    
    func getChapters( from url:URL ) async throws -> [ChapterInfo] {
        let ffChapters:FfmpegChapters = try await FfProber().run(withArguments: [
            "-i",
            url.absoluteString,
            "-show_chapters",
            "-of",
            "json"
        ])
        let chapters = ffChapters.chapters.map {
            return ChapterInfo(start: Double($0.startTime) ?? 0 , end: Double($0.endTime) ?? 0, title:$0.tags?.title  )
        }
        return chapters
    }
    
    func loadAudio(url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
}


struct FfChapterInfo: Codable {
    let id: Int?
    let timeBase: String?
    let start: TimeInterval?
    let startTime: String
    let end: TimeInterval?
    let endTime: String
    let tags: Tags?

    enum CodingKeys: String, CodingKey {
        case id
        case timeBase = "time_base"
        case start
        case startTime = "start_time"
        case end
        case endTime = "end_time"
        case tags
    }

    struct Tags: Codable {
        let title: String?
    }
}

struct FfAudioBookInfo: Codable {
    let filename: String?
    let nbStreams: Int?
    let nbPrograms: Int?
    let formatName: String?
    let formatLongName: String?
    let startTime: String?
    let duration: String?
    let size: String?
    let bitRate: String?
    let probeScore: Int?
    let tags: FfTags?
    
    enum CodingKeys: String, CodingKey {
        case filename
        case nbStreams = "nb_streams"
        case nbPrograms = "nb_programs"
        case formatName = "format_name"
        case formatLongName = "format_long_name"
        case startTime = "start_time"
        case duration
        case size
        case bitRate = "bit_rate"
        case probeScore = "probe_score"
        case tags
    }
}

struct FfTags: Codable {
    let majorBrand: String?
    let minorVersion: String?
    let compatibleBrands: String?
    let title: String?
    let track: String?
    let album: String?
    let genre: String?
    let artist: String?
    let encoder: String?
    let mediaType: String?
    
    enum CodingKeys: String, CodingKey {
        case majorBrand = "major_brand"
        case minorVersion = "minor_version"
        case compatibleBrands = "compatible_brands"
        case title
        case track
        case album
        case genre
        case artist
        case encoder
        case mediaType = "media_type"
    }
}




////////////////////////////////////////
// MARK: FfProber
//

struct FfmpegTrackInfo: Decodable {
    let format: FfAudioBookInfo
}
struct FfmpegChapters: Decodable {
    let chapters: [FfChapterInfo]
}

struct FfProber {
    func run<T:Decodable>( withArguments args:[String] ) async throws -> T {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let logArgs = ["-loglevel", "quiet"]
        process.arguments = ["ffprobe"] + logArgs + args
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        try process.run()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                }
                else {
                    var reason = "ffprobe terminated with a non-zero status"
                    if process.terminationStatus == 127 {
                        reason = "Command ffprob not found"
                    }
                    continuation.resume(throwing: NSError(domain: "runFfProbe",
                                                          code: Int(proc.terminationStatus),
                                                          userInfo: [NSLocalizedDescriptionKey: reason] ) )
                }
            }
        }
        
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let json = try JSONDecoder().decode(T.self, from: data)
        return json as T
    }


}

struct FfMpegger {
    //let sessionConfig:SessionConfig
    //var logger:Logger { sessionConfig.logger }
    @discardableResult func run( withArguments args:[String] ) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ffmpeg"] + args
        
        //logger.log( .debug,  "Running: \(args.joined(se))" )
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        let handle = outputPipe.fileHandleForReading
        try process.run()
        var fullData = Data()
        let bufferSize = 16*1024
        
        while process.isRunning {
            let chunk = handle.readData(ofLength: bufferSize)
            if chunk.isEmpty { break }
            fullData.append(chunk)
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw StoryAlignError( "Error using FFMPEG to decode audio: \(process.terminationStatus)")
        }
        
        
        return fullData
    }

}


