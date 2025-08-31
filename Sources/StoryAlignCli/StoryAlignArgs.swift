//
// StoryAlignArgs.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import StoryAlignCore

extension CaseIterable where Self: RawRepresentable, RawValue == String {
    static var separatedByPipe:String {
        "(\(Self.allCases.map{ $0.rawValue.lowercased() }.joined(separator: "|")))"
    }
}

struct StoryAlignHelp {
    static let orStages = ProcessingStage.separatedByPipe
    static let orAudioLoader = AudioLoaderType.separatedByPipe
    static let orLogLevel = LogLevel.separatedByPipe
    static let orReportType = ReportType.separatedByPipe
    static let toolName = StoryAlignVersion.toolName
    
    static let synopsis = "Synopsis: A tool that merges an ebook with an audiobook to produce an enriched ebook with narration."
    
    static let usage = """
    Basic Usage:
      \(toolName) <ebook> <audiobook>
    
    Usage:
      \(toolName) [--help] [--version] [--outfile=<file>] [--log-level=\(orLogLevel)] [--no-progress] [--throttle] [--whisper-model=<file>] [--audio-loader=\(orAudioLoader)] [--report=\(orReportType)] [--whiper-beam-size=<number>] [--whisper-dtw] [--session-dir=<directory>] [--stage=\(orStages)] <ebook> <audiobook>
    """
    
    static let argsDescription = """
    Arguments:
      <ebook>         The input ebook file (in .epub format)

      <audiobook>    The input audiobook file (in .m4b format).
    """
    
    // The | at the end here is the ~76th column. Don't go past it         |
    //                                                                     |
    static let optionsDescription = """
    Options:
      --outfile <file>      
          Set the file in which to save the aligned book. Defaults to the 
          name and path of the input  file with '_narrated' appended to the
          basename of that file.

      --log-level=\(orLogLevel)  
          Set the level of logging output. Defaults to 'warn'. Set to 
          'error' to only report errors. If set to anything above 'warn',
          either redirect stderr (where these messages are sent) or user
          the --no-progress flag to prevent conflicts.

      --no-progress                 
          Suppress progress updates. 
    
      --throttle
          By default, \(toolName) will use all of the resources the 
          operating system allows. That can end up working the 
          device pretty hard. Use this option to pare back on that. Aligning
          the book will take longer, but it'll keep the fans off.

      --whisper-model <file>
          The whisper model file. This is a 'ggml' file compatible with 
          the whisper.cpp library. The 'ggml-tiny.en.bin' model is appropriate
          and best for most cases. If this option is not specified, 
          \(toolName) will download and install the model after prompting for 
          confirmation. If you do specify a model file, make sure the companion
          .mlmodelc files are installed in the same location as the specified 
          .bin file.

      --audio-loader=\(orAudioLoader)
          Selects the audio-loading engine. The default is 'avfoundation', 
          which uses Apple's builtin frameworks to load and decode audio. In
          most cases this should work fine. The 'ffmpeg' option uses the 
          FFmpeg command-line utility to load and decode audio. This might be
          helpful if you encounter issues with the default. To make use of 
          it, you must have ffmpeg installed on your system and in your path.
    
      --version 
          Show version information
    
      -h, --help 
          Show this help information.

    =====

    Development Options:
      These options are useful for debugging and testing, but they usually 
      aren't used in normal operation.
    
      --report=\(orReportType)
          Show a report describing the results of the alignment when it 
          has completed. This 'score' choice emits a score that predicts the 
          percentage of sentences that have been aligned correctly. Other
          options show more detailed information about what was aligned. 
          The default is 'none'.
    
      --whisper-beam-size <number (1-8)>
          Set the number of paths explored by whisper.cpp when looking for
          the best transcription. Higher values will consider more options. That
          doesn't necessarily mean more accuracy. In fact, it's a bit 
          arbitrary. (Lookup 'beam search curse' to learn more). \(toolName)
          defaults to 2 for large & medium models, 7 for tiny models and 5 for 
          all other models.  
    
     --whisper-dtw
          Enable the dynamic time warping experimantal feature for whisper.cpp
          and the experimental handling of that information in \(toolName). This
          might improve accuracy of the timing of the transcription. 
          
      --session-dir <directory>
          Set the directory used for session data. It is required when --stage 
          is specified, and it tells \(toolName) where to store both temporary
          and persisted data.

      --stage \(orStages)
          The processing stage to be run. When set, \(toolName) expects to find 
          intermediate files stored in the directory pointed to by the session-dir
          argument. It will re-generate missing information required to run
          the specified stage.
    """
    
    static let helpText = """

\(toolName) (\(StoryAlignVersion().shortVersionStr))

\(synopsis)

\(usage)

\(argsDescription)

\(optionsDescription)

"""
}

struct StoryAlignArgs: CliArgs {
    var outfile: String?
    var logLevel: LogLevel?
    var noProgress: Bool?
    var whisperModel: String?
    var whisperBeamSize: Int?
    var whisperDtw: Bool?
    var audioLoader: AudioLoaderType?
    var sessionDir: String?
    var runStage: ProcessingStage?
    var throttle:Bool?
    var reportType:ReportType?
    var positionals: [String]?
    
    var ebook: String {
        positionals?.first ?? ""
    }
    var audioBook: String {
        positionals?.last ?? ""
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case outfile
        case logLevel = "log-level"
        case noProgress = "no-progress"
        case whisperModel = "whisper-model"
        case whisperBeamSize = "whisper-beam-size"
        case whisperDtw = "whisper-dtw"
        case audioLoader = "audio-loader"
        case sessionDir = "session-dir"
        case runStage = "stage"
        case reportType = "report"
        case throttle
        
        //'positionals' left out of CodingKeys so it will never be filled in by JSON decoder
    }

    var outputURL: URL {
        if let outfile {
            return URL(fileURLWithPath: outfile)
        }
        let inputURL = URL(fileURLWithPath: positionals?.first ?? "" )
        let basefile = inputURL.deletingPathExtension().lastPathComponent
        let nuFile = "\(basefile)_narrated.epub"
        if ProcessInfo.isXcodeEnv {
            return inputURL.deletingLastPathComponent().appendingPathComponent(nuFile)
        }
        let url = URL(filePath:FileManager.default.currentDirectoryPath ).appendingPathComponent(nuFile)
        return url
    }
}

