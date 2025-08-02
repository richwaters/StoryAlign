//
// TestFullBooks.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//



import XCTest
@testable import StoryAlignCore


struct TestConfig : Codable {
    let modelName:String
    let beamSize:Int?
    let expectedSha256:String
}

struct TestBookInfo : Codable {
    let audioBookURL:URL?
    let audioBookSource:String?
    let epubURL:URL?
    let epubSource:String?
    
    let testConfigs:[TestConfig]
}

protocol FullBookTester {
    var testBookDir:String { get }
}

extension FullBookTester {
    static var SRCROOT:String { ProcessInfo.processInfo.environment["SRCROOT"] ?? "." }
}



extension FullBookTester {
    
    func buildSessionConfig( with testConfig:TestConfig ) throws -> SessionConfig {
        let model =  {
            let modelName = testConfig.modelName
            if modelName.first == "/" {
                return modelName
            }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let dir = home.appendingPathComponent(".storyalign")
            return dir.appendingPathComponent(modelName).path()
        }()
        let logger =  CliLogger(minimumLevel: .warn)
        let progressUpdater = CliProgressUpdater()
        
        let sessionDir:String? = nil
        let sessionConfig = try SessionConfig(sessionDir: sessionDir, modelFile: model, runStage: nil, logger:logger, progressUpdater: progressUpdater, reportType: .full)
        return sessionConfig
    }
    
    func runTest( for bookName:String) async throws {
        let testInfoPath = URL(fileURLWithPath: "\(testBookDir)/\(bookName)/testInfo.json")
        let data = try Data(contentsOf: testInfoPath)
        let testInfo = try JSONDecoder().decode(TestBookInfo.self, from: data)
        
        for testConfig in testInfo.testConfigs {
            try await runTest(for: bookName, testInfo:testInfo, testConfig:testConfig)
        }
    }

    
    func runTest( for bookName:String, testInfo:TestBookInfo, testConfig:TestConfig) async throws {
        
        let sessionConfig = try buildSessionConfig( with: testConfig)
        
        let shortModelName = testConfig.modelName.replacingOccurrences(of: ".bin", with: "").replacingOccurrences(of: "ggml-", with: "")
        let sfx = "_narrated_\(shortModelName)"

        let fm = FileManager.default
        let epubPath = URL(fileURLWithPath: "\(testBookDir)/\(bookName)/\(bookName).epub")
        if !fm.fileExists(atPath: epubPath.path()) {
            if let epubURL = testInfo.epubURL {
                print( "Downloading test epub from: \(epubURL)" )
                let data = try Data( contentsOf: epubURL)
                try data.write(to: epubPath)
            }
        }
        if !fm.fileExists(atPath: epubPath.path()) {
            print( "No epub for \(bookName): skipping test" , separator: "")
            if let epubSource = testInfo.epubSource {
                print( " -- Download from \(epubSource)")
            }
            else {
                print("")
            }
            return
        }
        
        let audioPath = URL(fileURLWithPath: "\(testBookDir)/\(bookName)/\(bookName).m4b")
        if !fm.fileExists(atPath: audioPath.path()) {
            if let audioBookURL = testInfo.audioBookURL {
                print( "Downloading test audiobook from: \(audioBookURL)" )
                let data = try Data( contentsOf: audioBookURL)
                try data.write(to: audioPath)
            }
        }
        if !fm.fileExists(atPath: audioPath.path()) {
            print( "No audiobook for \(bookName): skipping test" , separator: "")
            if let audioSource = testInfo.audioBookSource {
                print( " -- Download from \(audioSource)")
            }
            else {
                print("")
            }
            return
        }
        
        let outPath:URL = sessionConfig.sessionDir.appendingPathComponent("\(bookName)\(sfx).epub")
        let expectedPath:URL = URL(fileURLWithPath: "\(testBookDir)/\(bookName)/expected")
        
        let expectedRptFile = expectedPath.appendingPathComponent("\(bookName)\(sfx).json")
        let expectedRpt = try JSONDecoder().decode(AlignmentReport.self, from: Data(contentsOf: expectedRptFile))
        let storyAligner = StoryAligner(sessionConfig: sessionConfig)
        let rpt = try await storyAligner.alignStory(epubPath: epubPath.path(), audioPath: audioPath.path(), outputURL: outPath)!
        
        try runEpubCheck(outPath)
        
        let ckSum = try runEpubStrip(outPath)
        XCTAssert(ckSum.trimmed() == testConfig.expectedSha256.trimmed())

        let score = rpt.score
        let expectedScore = expectedRpt.score
        XCTAssert(score == expectedScore )
        
        let runtime = rpt.runtime
        let expectedRunTime = expectedRpt.runtime
        XCTAssert( runtime < (expectedRunTime * 2) )
    }
    
    func runEpubStrip(_ file:URL) throws -> String  {
        let stripScriptPath = "\(Self.SRCROOT)/scripts/epubstrip.sh"
        let sum = try runScript(stripScriptPath, args: [file.path()])
        return sum
    }
    
    func runEpubCheck(_ file:URL) throws  {
        let scriptPath = "/usr/bin/env"
        let output = try runScript(scriptPath, args: [ "bash", "epubcheck", "--quiet", file.path() ] )
        if output.isEmpty {
            return
        }

        // Ignore .ncx errors. These are epub2 components that are in original epub and not used in epub3
        if output.uppercased().starts(with: "ERROR(NCX-001)") {
            return
        }

        throw( StoryAlignError(output))
    }

    func runScript(_ cmd:String, args:[String]=[]) throws -> String {
        let scriptURL = URL(fileURLWithPath: cmd)
        
        //let process = Process()
        let process = Process()
        process.executableURL = scriptURL
        //process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        //process.arguments = ["bash"] + [scriptURL.path()] + args
        process.arguments = args
        var env = process.environment ?? [:]
        env["PATH"] = ProcessInfo.processInfo.environment["PATH"]!
        process.environment = env
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError  = outputPipe
        let handle = outputPipe.fileHandleForReading
        
        var fullData = Data()
        let bufferSize = 16*1024
        try process.run()
        while process.isRunning {
            let chunk = handle.readData(ofLength: bufferSize)
            if chunk.isEmpty { break }
            fullData.append(chunk)
        }
        process.waitUntilExit()
        let output = String( data: fullData, encoding: .utf8)!
        return output
    }
}


class TestFullBooks: XCTestCase, FullBookTester {
    let testBookDir = "\(SRCROOT)/Tests/TestBooks"

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60 * 60 * 2
     }
}

extension TestFullBooks {
    func testFlatland2() async throws {
        try await runTest(for: "Flatland2" )
    }
    func testDragonsteelPrime() async throws {
        try await runTest(for: "DragonsteelPrime")
    }
}
