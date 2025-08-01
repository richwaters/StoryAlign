//
// TestExtras.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import XCTest

class TestExtras: XCTestCase, FullBookTester {
    let testBookDir = "\(SRCROOT)/Tests/TestBooks/extras"
}


extension TestExtras {
    func testDrive() async throws {
        try await runTest(for: "Drive")
    }
    func testEmbassytown() async throws {
        try await runTest(for: "Embassytown")
    }
    func testLionsOfAlRassan() async throws {
        try await runTest(for: "The_Lions_of_Al-Rassan")
    }
}
