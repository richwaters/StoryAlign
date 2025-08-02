//
// ProgressUpdater.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters


import Foundation

fileprivate let GH_BYTES_PER_KiB: Double = 1024
fileprivate let GH_BYTES_PER_MiB: Double = GH_BYTES_PER_KiB * GH_BYTES_PER_KiB
fileprivate let GH_BYTES_PER_GiB: Double = GH_BYTES_PER_KiB * GH_BYTES_PER_MiB

fileprivate let secondsPerMinute = 60.0
fileprivate let secondsPerHour = 60.0*secondsPerMinute

public enum ProgressUpdaterUnit : Int, Sendable {
    case none = 0
    case bytes
    case seconds
    case sentences
}

public protocol ProgressUpdater : AnyObject, Sendable {
    var updateQueue:DispatchQueue { get }
    var stageProgress:[ProcessingStage:Double] { get set }
    var stageTotal:[ProcessingStage:Double] { get set }
    func updateProgress(for stage: ProcessingStage, msgPrefix: String, increment: Double, total: Double?, unit: ProgressUpdaterUnit)
    func show( stageProgress: Double, stageTotal:Double, overallCompletionPercent: Double, msgPregix:String, unit:ProgressUpdaterUnit )
}

public extension ProgressUpdater {
    func updateProgress(for stage: ProcessingStage, msgPrefix: String, increment: Double, total: Double? = nil, unit: ProgressUpdaterUnit) {
        updateQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            let stageProgress = (self.stageProgress[stage] ?? 0.0) + increment
            self.stageProgress[stage] = stageProgress
            var overallProgressPercent = 0.0
            for completedStage in ProcessingStage.orderedCases {
                if completedStage.ordinalValue >= stage.ordinalValue {
                    break
                }
                overallProgressPercent += completedStage.percentOfTotal
            }
            let stageTotal = self.stageTotal[stage] ?? 0.0
            let nuTotal = total ?? stageTotal
            if nuTotal != stageTotal {
                self.stageTotal[stage] = nuTotal
            }
            let stageProgressRatio = nuTotal == 0 ? 0.0 : Double(stageProgress)/Double(nuTotal)
            overallProgressPercent +=  stageProgressRatio * Double(stage.percentOfTotal)
            self.show( stageProgress: stageProgress, stageTotal: nuTotal, overallCompletionPercent: overallProgressPercent, msgPregix: msgPrefix, unit:unit)
        }
    }
    
    func updateProgress(for stage: ProcessingStage, msgPrefix: String, increment: Int, total: Int?, unit: ProgressUpdaterUnit) {
        guard let total = total else {
            updateProgress(for: stage, msgPrefix: msgPrefix, increment: Double(increment), unit:unit)
            return
        }
        updateProgress(for: stage, msgPrefix: msgPrefix, increment: Double(increment), total: Double(total), unit:unit)
    }
}

public extension ProgressUpdater {
    func format( count: Double, overTot: Double, unit:ProgressUpdaterUnit) -> String {
        if overTot == 0 {
            return ""
        }
        if unit == .bytes {
            let (divisor,sfx,decimals) = {
                if count > GH_BYTES_PER_GiB {
                    return (GH_BYTES_PER_GiB, "GB",2)
                }
                if count > GH_BYTES_PER_MiB {
                    return (GH_BYTES_PER_MiB, "MB",1)
                }
                if count > GH_BYTES_PER_KiB {
                    return (GH_BYTES_PER_KiB, "KB",1)
                }
                return (1.0, "bytes",0)
            }()
            let fmt = "%.\(decimals)f"
            let countStr = String(format:fmt, count/divisor)
            let totStr = String( format: fmt, overTot/divisor)
            return "\(countStr)/\(totStr) \(sfx)"
        }
        
        if unit == .sentences {
            let (divisor,sfx,decimals) = {
                if count > GH_BYTES_PER_MiB {
                    return (GH_BYTES_PER_MiB, "M sentences",1)
                }
                return (1.0, " sentences",0)
            }()
            let fmt = "%.\(decimals)f"
            let countStr = String(format:fmt, count/divisor)
            let totStr = String( format: fmt, overTot/divisor)
            return "\(countStr)/\(totStr) \(sfx)"
        }
        
        if unit == .seconds {
            let (divisor,sfx,decimals) = {
                if count > secondsPerHour {
                    return (secondsPerHour, "hours", 2)
                }
                if count > secondsPerMinute  {
                    return (secondsPerMinute, "minutes",1)
                }
                return (1.0, "seconds",0)
            }()
            let fmt = "%.\(decimals)f"
            let countStr = String(format:fmt, count/divisor)
            let totStr = String( format: fmt, overTot/divisor)
            return "\(countStr)/\(totStr) \(sfx)"
        }
        
        let retStr = "\(Int(count))/\(Int(overTot))"
        return retStr
    }
}
