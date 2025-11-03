//
// M4BParser.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation


public struct M4BParser : SessionConfigurable {
    public let sessionConfig: SessionConfig
    public init(sessionConfig: SessionConfig) {
        self.sessionConfig = sessionConfig
    }

    public func parse( url:URL, extractingInto rootPath:URL ) async throws -> AudioBook {
        
        let audioLoader = AudioLoaderFactory.audioLoader(for:sessionConfig)
        //let trackInfo = try await audioLoader.getTrackInfo(from: url)
        let chapters = try await audioLoader.getChapters(from: url)
        
        ///////
        let dstDirName = "\(AssetPaths.audio)"
        let dstDirPath = rootPath.appending(component: dstDirName)
        
        try? FileManager.default.removeItem(at: dstDirPath)
        try FileManager.default.createDirectory(at: dstDirPath, withIntermediateDirectories: true )
        
        let audioFiles = chapters.enumerated().map { (index,chapter) in
            let fileName = String(format: "%05d-%05d.mp4", 0, index+1)
            let filePath = dstDirPath.appending(component: fileName)
            let audioFile = AudioFile( startTmeInterval: chapter.start, endTmeInterval: chapter.end, filePath: filePath, index:index)
            return audioFile
        }
        
        for audioFile in audioFiles {
            logger.log(.info, "Extracting \(audioFile.filePath)")
            try await audioLoader.extractAudio(from: url, using: audioFile )
            sessionConfig.progressUpdater?.updateProgress(for: .audio, msgPrefix: "Extracting Audio:", increment: 1, total: audioFiles.count, unit:.none)

        }
        
        //let audioBook = AudioBook(bookInfo: trackInfo, audioFiles: audioFiles)
        let audioBook = AudioBook( audioFiles: audioFiles )
        return audioBook
    }
}



