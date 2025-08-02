//
// CliProgressUpdater.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//


import Foundation
import StoryAlignCore


final class CliProgressUpdater : ProgressUpdater, @unchecked Sendable {
    var stageProgress:[ProcessingStage:Double] = [:]
    var stageTotal:[ProcessingStage:Double] = [:]

    let updateQueue = DispatchQueue( label: "com.goodhumans.storyalign.cli.progressupdater" )
    func show(stageProgress: Double, stageTotal: Double, overallCompletionPercent: Double, msgPregix msgPrefix: String, unit:ProgressUpdaterUnit) {
        
        let countOverTot = format(count: stageProgress, overTot: stageTotal, unit: unit)
        let msg = "\(msgPrefix) \(countOverTot)"
        singleLineProgress(message: msg, percent: Int(overallCompletionPercent))
    }
    
    func singleLineProgress( message: String, percent: Int) {
        let msg = message
        let padding = String(repeating: " ", count: max(0, 64 - msg.count))
        print("\r\(msg)\(padding) \(percent)%", terminator: "")
        fflush(stdout)
        if percent == 100 {
            print() ;
            fflush(stdout)
        }
    }
}
