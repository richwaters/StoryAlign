//
// URL+Extensions.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//


import Foundation

extension URL {
    func relative(to base: URL) -> String {
        let a = standardized.resolvingSymlinksInPath().pathComponents
        let b = base.standardized.resolvingSymlinksInPath().pathComponents

        var i = 0
        while i < a.count && i < b.count {
            if a[i] != b[i] {
                break
            }
            i += 1
        }

        var comps = [String]()
        for _ in i..<b.count {
            comps.append("..")
        }
        comps.append(contentsOf: a[i...])
        return comps.joined(separator: "/")
    }
}
