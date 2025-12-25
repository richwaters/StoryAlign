//
// StoryAlignMain.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters


import Foundation
import StoryAlignCore
import ZIPFoundation



@main
struct StoryAlignMain {
    static let toolName = StoryAlignVersion.toolName
    
    static func main() async throws {
        if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
            print(StoryAlignHelp.helpText)
            exit(0)
        }
        if CommandLine.arguments.contains("--version") {
            print("\(toolName) - version \(StoryAlignVersion().fullVersionStr)")
            exit(0)
        }
        
        if CommandLine.arguments.contains("--help-md") {
            //print(StoryAlignHelp.helpText)
            print( CliUsageFormatter.makeMarkdown(from: StoryAlignHelp.helpText) )
            exit(0)
        }
        
        if CommandLine.arguments.contains("__TEMPLATE_ARGS__") {
            print( "It looks like you launched the Template scheme directly. Please run generate_schemes.sh first so your schemes point at real paths.\n" )
            exit(0)
        }
        
        
        do {
            try await runCli()
        }
        catch let err as CliError {
            print()
            print("Error: \(err)")
            print("====")
            print(StoryAlignHelp.usage)
            print()
            exit(1)
        }
        catch let err {
            print("Error: \(err)")
            exit(1)
        }
    }
    
    static func runCli() async throws {
        let storyAlignArgs:StoryAlignArgs = try CliArgsParser().parse()
        try self.validate( storyAlignArgs )
        
        let whisperModel = try resolveWhisperModel(storyAlignArgs: storyAlignArgs)
        let logger = CliLogger(minimumLevel: storyAlignArgs.logLevel ?? .warn )
        let progressUpdater = (storyAlignArgs.noProgress ?? false) ? nil : CliProgressUpdater()
        
        let sessionConfig = try SessionConfig(
            sessionDir: storyAlignArgs.sessionDir,
            modelFile: whisperModel,
            runStage: storyAlignArgs.runStage,
            logger:logger,
            audioLoaderType: storyAlignArgs.audioLoader ?? .avfoundation,
            throttle: storyAlignArgs.throttle ?? false,
            progressUpdater: progressUpdater,
            toolName: toolName,
            version: StoryAlignVersion().shortVersionStr,
            whisperBeamSize: storyAlignArgs.whisperBeamSize,
            whisperDtw: storyAlignArgs.whisperDtw,
            reportType: storyAlignArgs.reportType ?? .none,
            startChapter: storyAlignArgs.startChapter,
            endChapter: storyAlignArgs.endChapter,
            granularity: storyAlignArgs.granularity ?? .sentence
        )
        defer {
            sessionConfig.cleanup()
        }
        
        let storyAligner = StoryAligner(sessionConfig: sessionConfig)
        guard let rpt = try await storyAligner.alignStory(epubPath: storyAlignArgs.ebook, audioPath: storyAlignArgs.audioBook, outputURL: storyAlignArgs.outputURL) else {
            return
        }
        guard sessionConfig.reportType != .none && (sessionConfig.runStage == .all || sessionConfig.runStage == .report) else {
            return
        }
        try writeReport(rpt, outputURL: storyAlignArgs.outputURL, sessionConfig: sessionConfig)
    }

    static func writeReport( _ rpt:AlignmentReport, outputURL:URL, sessionConfig:SessionConfig ) throws {
        let baseName = outputURL.deletingPathExtension().lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let yyyymmddhhmm = formatter.string(from: Date())
        let rptExt = sessionConfig.reportType == .json ? "json" : "txt"
        let rptFileName = outputURL.deletingLastPathComponent().appendingPathComponent("\(baseName)-\(yyyymmddhhmm).\(rptExt)")
        
        if sessionConfig.reportType == .json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try! encoder.encode(rpt)
            try! json.write(to:rptFileName)
            print( "\nReport written to: \(rptFileName.lastPathComponent)")
            return
        }
        
        let formattedRpt = AlignmentReportFormatter(sessionConfig: sessionConfig).format( rpt )
        if ProcessInfo.isXcodeEnv {
            print( formattedRpt )
            return
        }
        try formattedRpt.write(to: rptFileName, atomically: true, encoding: .utf8)
        print( "\nReport written to: \(rptFileName.lastPathComponent)")
    }
}

extension StoryAlignMain {
    static func validate(_ cli:StoryAlignArgs ) throws {
        let audioExtensions = ["m4b", "mp4" ]

        if (cli.positionals ?? []).count != 2 {
            if let firstArg = cli.positionals?.first {
                if firstArg.pathExtension == "epub" {
                    throw CliError( "Missing audiobook argument" )
                }
                else if audioExtensions.contains(firstArg.pathExtension) {
                    throw CliError( "Missing ebook argument" )
                }
            }
            throw CliError( "Both ebook and audiobook must be specified on command line" )
        }
        if cli.ebook.pathExtension != "epub" {
            throw CliError( "Both ebooks in epub format with .epub extension allowed" )
        }
        if !audioExtensions.contains(cli.audioBook.pathExtension ) {
            throw CliError( "Only audiobooks with the following extensions are allowed: \(audioExtensions.joined(separator: ", "))")
        }
        
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: cli.ebook ) {
            throw CliError("Ebook not found at: \(cli.ebook)")
        }
        if !fileMgr.fileExists(atPath: cli.audioBook) {
            throw CliError("Audiobook not found at: \(cli.audioBook)" )
        }
        
        let fm = FileManager.default
        if fm.fileExists(atPath: cli.outputURL.path) {
            if !getYesNoResponse(prompt: "Output file exists: \(cli.outputURL.path)\n\nOverwrite? (Y/N)") {
                throw CliError( "Refusing to overwrite existing output file \(cli.outputURL.path())." )
            }
            try? fm.removeItem(at: cli.outputURL)
        }
        
        try "test".write(to: cli.outputURL, atomically: true, encoding: .utf8)
        try fm.removeItem(at: cli.outputURL)
        
        if cli.runStage != nil {
            if cli.sessionDir == nil {
                throw CliError("--stages was set, but --session-dir was not provided. A --session-dir is required to persist intermediate data between runs of specific stages.")
            }
        }
        if let workingDir = cli.sessionDir {
            if !fileMgr.fileExists(atPath: workingDir) {
                if !getYesNoResponse(prompt: "Working directory '\(workingDir)' doesn't exist. Create it (Y/N)?") {
                    throw CliError("Working directory '\(workingDir)' doesn't exist and creation was not confirmed.")
                }
                let dirUrl = URL(fileURLWithPath: workingDir)
                try fileMgr.createDirectory(at: dirUrl, withIntermediateDirectories: true)
            }
        }
    }
    
    //https://huggingface.co/ggerganov/whisper.cpp/tree/main
    
    static func resolveWhisperModel( storyAlignArgs:StoryAlignArgs ) throws -> String  {
        let whisperModel = try resolveOrDownload(
            providedPath: storyAlignArgs.whisperModel,
            remoteURLs: [
                 URL(string:"https://github.com/richwaters/whisper.cpp/releases/download/v1.7.5-static-xcframework/ggml-tiny.en.bin")!,
                 URL(string:"https://github.com/richwaters/whisper.cpp/releases/download/v1.7.5-static-xcframework/ggml-tiny.en-encoder.mlmodelc.zip")!
            ],
    //                                                              //  column mark
            downloadPrompt:
    """
    
    whisper.cpp model not specified. 
    
    \(toolName) can download the tiny.en model files and install them
    into a '.\(toolName)' hidden folder under your home directory. This 
    will use about 80MB or so. If you use whisper.cpp model files for
    other apps and prefer to manage them yourself, please use the 
    --whisper-model option to tell \(toolName) the model's location.
    
    Would you like to continue with the download (Y/N)?
    """
        )
        guard let whisperModel else {
            throw CliError( "whisper-model not specified" )
        }
        return whisperModel
    }
}

extension StoryAlignMain {
    static func resolveOrDownload(
        providedPath: String?,
        remoteURLs: [URL],
        downloadPrompt: String
    ) throws -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".storyalign")
        
        if let path = providedPath {
            return path
        }
        let targets = remoteURLs.map {
            let targetName = $0.lastPathComponent
            let target = dir.appendingPathComponent(targetName)
            return target
        }
        let allTargetsExist = targets.allSatisfy {
            if fm.fileExists(atPath: $0.path) {
                return true
            }
            if $0.path.pathExtension == "zip" {
                if fm.fileExists(atPath: $0.deletingPathExtension().path ) {
                    return true
                }
            }
            return false
        }
        if allTargetsExist {
            return targets.first!.path
        }
        //print( "\(downloadPrompt): ", terminator: " ")
        if !getYesNoResponse(prompt: downloadPrompt) {
            return nil
        }

        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for (remoteURL, target) in zip(remoteURLs, targets) {
            print( "Downloading \(remoteURL) ...", terminator: "")
            let data = try Data(contentsOf: remoteURL)
            try data.write(to: target)
            
            if target.pathExtension == "zip" {
                try fm.unzipItem(at: target, to: dir, overwrite: true)
                try fm.removeItem(at: target)
            }
            
            print ( "complete")
        }
        return targets.first!.path
    }
    
    static func getYesNoResponse( prompt:String ) -> Bool {
        if ProcessInfo.isXcodeEnv {
            let xcodePrompt = "In normal operation, the prompt below would be displayed in the terminal. Unfortunately, a few years ago Apple disabled the ability to obtain input from the command line in Xcode. This popup dialog fills in for that inadequacy\n\n----\n\(prompt)"
            
            let script = """
               display dialog "\(xcodePrompt)" with title "Xcode prompt" buttons {"No", "Yes"} default button "Yes"
               """
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return output.contains("button returned:Yes")
                }
            } catch {
                return false
            }
            
            return false
        }
        
        var resp = ""
        while resp.lowercased() != "y" && resp.lowercased() != "n" {
            print( "\(prompt): ", terminator: "")
            resp = readLine() ?? ""
        }
        return resp.lowercased() == "y"
    }
}
