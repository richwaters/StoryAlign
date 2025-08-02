//
// AudioLoader.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation

public enum AudioLoaderType: String, Codable, CaseIterable,Sendable {
    case avfoundation
    case ffmpeg
}

protocol AudioLoader : SessionConfigurable {
    func decode( from fileURL: URL ) async throws -> [Float]
    func getChapters( from url:URL ) async throws -> [ChapterInfo]
    func extractAudio( from url:URL, using audioFileInfo:AudioFile ) async throws
}

struct AudioLoaderFactory {
    static func audioLoader( for sessionConfig:SessionConfig ) -> AudioLoader {
        switch sessionConfig.audioLoaderType {
            case .ffmpeg:
                return FfAudioLoader(sessionConfig:sessionConfig)
            case .avfoundation:
                return AvAudioLoader(sessionConfig: sessionConfig)
        }
    }
}
