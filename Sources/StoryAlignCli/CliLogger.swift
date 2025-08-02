//
// CliLogger.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import StoryAlignCore

struct CliLogger : Logger  {
    let minimumLevel: LogLevel
    let isEnabled: Bool = true
    let includeTimestamp: Bool = true

    func log(_ level: LogLevel = .info, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line, indentLevel: Int = 0) {
        guard isEnabled, shouldLog(level: level) else { return }

        let timestamp = includeTimestamp ? "[\(formattedTimestamp())] " : ""
        let location = "\(fileName(from: file)):\(line)"
        let prefix = "[\(level.rawValue.uppercased())] \(timestamp)"
        let s = String(repeating: " ", count: indentLevel * 8 )
        let newLine=(level == .timestamp) ? "\n" : ""
        

        let msg = "\(newLine)\(s)\(prefix)\(message())  (\(location))\n"
        FileHandle.standardError.write(msg.data(using: .utf8) ?? Data())
    }

    private func shouldLog(level: LogLevel) -> Bool {
        return level >= minimumLevel
    }

}
