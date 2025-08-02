//
// TestCliArgs.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//




import XCTest
import Foundation

final class TestCliArgs: XCTestCase {
    let toolName = "storyalign"
    func testLastArgFlag() throws {
        let args: [String] = [toolName, "--throttle", "test.epub", "test.m4b"]
        let storyAlignArgs:StoryAlignArgs = try CliArgsParser().parse(from:args)
        XCTAssertEqual(storyAlignArgs.throttle, true)
        XCTAssertEqual(storyAlignArgs.positionals?.count , 2)
    }
    
    func testBadType() throws {
        let args: [String] = [toolName, "--session-dir=3", "--throttle", "test.epub", "test.m4b"]
        do {
            let _:StoryAlignArgs = try CliArgsParser().parse(from:args)
        }
        catch let err as CliError {
            XCTAssert(err.description.contains("session-dir") )
            XCTAssert(err.description.contains("expected String") )

        }
    }
    
    func testNumAsString() throws {
        let args: [String] = [toolName, "--session-dir=\"3\"", "--throttle", "test.epub", "test.m4b"]
        let storyAlignArgs:StoryAlignArgs = try CliArgsParser().parse(from:args)
        XCTAssert(storyAlignArgs.sessionDir == "3")
        
        let args2: [String] = [toolName, "--session-dir='3'", "test.epub", "test.m4b"]
        let storyAlignArgs2:StoryAlignArgs = try CliArgsParser().parse(from:args2)
        XCTAssert(storyAlignArgs2.sessionDir == "3" )
        
        let args3: [String] = [toolName, "--session-dir='\"3\"'", "--throttle", "test.epub", "test.m4b"]
        let storyAlignArgs3:StoryAlignArgs = try CliArgsParser().parse(from:args3)
        XCTAssert(storyAlignArgs3.sessionDir == "\"3\"")
    }
    
    func testKeySpaceVal() throws {
        let args: [String] = [toolName, "--log-level", "debug", "test.epub", "test.m4b"]
        let storyAlignArgs:StoryAlignArgs = try CliArgsParser().parse(from:args)
        XCTAssert(storyAlignArgs.logLevel == .debug)

    }

}
