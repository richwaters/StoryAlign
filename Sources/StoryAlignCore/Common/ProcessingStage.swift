
//
// ProcessingStage.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation


public protocol OrderedCaseIterable: CaseIterable, Comparable, Sendable {
    static var orderedCases: [Self] { get }
    var ordinalValue: Int { get }
}

public extension OrderedCaseIterable {
    var ordinalValue: Int { Self.orderedCases.firstIndex(of: self)! }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.ordinalValue < rhs.ordinalValue
    }
    static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.ordinalValue > rhs.ordinalValue
    }
    static func >= (lhs: Self, rhs: Self) -> Bool {
        lhs.ordinalValue >= rhs.ordinalValue
    }
}


public enum ProcessingStage: String, Codable, OrderedCaseIterable {
    case epub
    case audio
    case transcribe
    case align
    case xml
    case export
    case report
    case all

    public static let orderedCases: [ProcessingStage] = [
        .epub,
        .audio,
        .transcribe,
        .align,
        .xml,
        .export,
        .report,
        .all
    ]

    public var percentOfTotal: Double {
        switch self {
            case .epub:
                return 1.0
            case .audio:
                return 1.0
            case .transcribe:
                return 70.0
            case .align:
                return 22.0
            case .xml:
                return 2.0
            case .export:
                return 4.0
            case .report:
                return 0.0
            case .all:
                return 100.0
        }
    }
}

