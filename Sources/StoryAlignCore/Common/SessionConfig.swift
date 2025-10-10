//
// SessionConfig.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation

public extension ProcessInfo {
    static var isXcodeEnv:Bool {ProcessInfo.processInfo.environment.keys.contains { $0.contains("XCODE") } }
}

public protocol SessionConfigurable  {
    var sessionConfig:SessionConfig { get }
}
public extension SessionConfigurable {
    var logger:Logger { sessionConfig.logger }
}

public final class SessionConfig : Sendable {
    public let sessionDir:URL
    public let modelFile:String
    public let runStage: ProcessingStage
    public let logger:Logger
    public let audioLoaderType:AudioLoaderType
    public let throttle:Bool
    public let progressUpdater:ProgressUpdater?
    //public let version:String?
    private let shouldRemoveSessionDir: Bool
    public let toolName:String?
    public let version:String?
    public let whisperBeamSize:Int
    public let whisperDtw:Bool
    public let reportType:ReportType
    public let startChapter:String?
    public let endChapter:String?

    var modelName:String {
        URL(fileURLWithPath: modelFile).deletingPathExtension().lastPathComponent
    }
    
    
    public init(sessionDir: String?,
                modelFile:String,
                runStage:ProcessingStage?,
                logger:Logger,
                audioLoaderType:AudioLoaderType = .avfoundation,
                throttle:Bool=false,
                progressUpdater:ProgressUpdater? = nil,
                toolName:String? = nil,
                version:String? = nil,
                whisperBeamSize:Int? = nil,
                whisperDtw:Bool? = false,
                reportType:ReportType = .none,
                startChapter:String? = nil,
                endChapter:String? = nil,
    ) throws {
        self.runStage = runStage ?? .all
        self.modelFile = modelFile
        self.logger = logger
        self.audioLoaderType = audioLoaderType
        self.throttle = throttle
        self.progressUpdater = progressUpdater
        self.toolName = toolName
        self.version = version
        self.whisperDtw = whisperDtw ?? false
        self.reportType = reportType
        self.startChapter = startChapter
        self.endChapter = endChapter
        
        self.whisperBeamSize = {
            if let beamSize = whisperBeamSize {
                return beamSize
            }
            if modelFile.contains("tiny") {
                return 7
            }
            if modelFile.contains("large") || modelFile.contains("medium") {
                return 2
            }
            return 5  // whisper.cpp default
        }()
        

        self.sessionDir = try {
            if let sessionDir {
                return URL(fileURLWithPath: sessionDir)
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let sessionDir = tempDir.appendingPathComponent("story_align_\(UUID().uuidString.prefix(12))", isDirectory: true)
            try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            return sessionDir
        }()
        self.shouldRemoveSessionDir = (sessionDir == nil)
    }
    
    public func cleanup() {
        if !shouldRemoveSessionDir {
            return
        }
        try? FileManager.default.removeItem(at: sessionDir)
    }
}
