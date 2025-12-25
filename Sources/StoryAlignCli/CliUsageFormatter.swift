//
//  CliUsageFormatter.swift
//  StoryAlign
//
//  Created by Rich Waters on 12/12/25.
//

extension CaseIterable where Self: RawRepresentable, RawValue == String {
    static var separatedByPipe:String {
        "(\(Self.allCases.map{ $0.rawValue.lowercased() }.joined(separator: "|")))"
    }
}


struct CliUsageFormatter {
    static func wrap(text: String, at preferredColumn:Int = 76, allowedOverflow:Int = 2) -> String {
        let col = max(preferredColumn, 1)
        let overflow = max(allowedOverflow, 0)
        
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
            .flatMap { line -> [String] in
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                let body = line.dropFirst(indent.count)
                if body.isEmpty { return [line] }
                
                let availableSoft = max(col - indent.count, 1)
                let availableHard = availableSoft + overflow
                let words = body.split(separator: " ").map(String.init)
                if words.isEmpty { return [indent] }
                
                var out: [String] = []
                var current = ""
                var curLen = 0
                
                func flush() {
                    out.append(indent + current)
                    current = ""
                    curLen = 0
                }
                
                for w in words {
                    let wLen = w.count
                    
                    if current.isEmpty {
                        current = w
                        curLen = wLen
                        continue
                    }
                    
                    if curLen + 1 + wLen <= availableSoft {
                        current.append(" ")
                        current.append(w)
                        curLen += 1 + wLen
                        continue
                    }
                    if curLen + 1 + wLen <= availableHard {
                        current.append(" ")
                        current.append(w)
                        curLen += 1 + wLen
                        continue
                    }
                    
                    flush()
                    current = w
                    curLen = wLen
                }
                
                if !current.isEmpty { flush() }
                return out
            }
            .joined(separator: "\n")
    }
}

extension CliUsageFormatter {
    
    static func makeMarkdown(from full: String) -> String {
        var out: [String] = []
        let lines = full.split(separator: "\n", omittingEmptySubsequences: false)
        for raw in lines {
            let line = String(raw)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                out.append("")
                continue
            }
            if isHeader(raw) {
                out.append("### " + esc(trimmedLine))
                continue
            }
            if let opt = optionLine(line) {
                out.append(opt)
                continue
            }
            out.append(esc(line))
        }
        return out.joined(separator: "\n")
    }

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "<", with: "\\<")
            .replacingOccurrences(of: ">", with: "\\>")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    static func isHeader(_ line: Substring) -> Bool {
        guard let first = line.first else { return false }
        return !String(first).contains(anyOf: [" ", "\t", "═", "─", "=", "⸺"])
    }

    static func optionLine(_ line: String) -> String? {
        let l = line.trimmingCharacters(in: .whitespaces)
        guard let m = l.wholeMatch(of: /^(?:(-[A-Za-z]),\s*)?(--[A-Za-z0-9\-]+)(?:(=|\s+)(.+))?$/) else {
            return nil
        }

        let alias = m.1.map(String.init)
        let name = String(m.2)
        let sep = m.3.map(String.init)
        let rest = m.4.map(String.init)

        let head = alias.map { "**\($0)**, **\(name)**" } ?? "**\(name)**"
        guard let rest else { return head }
        guard let sep else { return head }

        if sep == "=" {
            return head + "=" + esc(rest)
        }

        return head + sep + esc(rest)
    }
    
    /*
    static func optionLine(_ line: String) -> String? {
        let l = line.trimmingCharacters(in: .whitespaces)
        guard let m = l.wholeMatch(of: /^(?:(-[A-Za-z]),\s*)?(--[A-Za-z0-9\-]+)(?:([ =])(.+))?$/) else {
            return nil
        }
        
        let alias = m.1.map(String.init)
        let name = String(m.2)
        let sep = m.3.map(String.init) ?? ""
        let rest = m.4.map(String.init) ?? ""
        
        if let a = alias {
            if sep == "=" { return "**\(a)**, **\(name)**=\(esc(rest))" }
            if rest.isEmpty { return "**\(a)**, **\(name)**" }
            return "**\(a)**, **\(name)** \(esc(rest))"
        }
        
        if sep == "=" { return "**\(name)**=\(esc(rest))" }
        if rest.isEmpty { return "**\(name)**" }
        return "**\(name)** \(esc(rest))"
    }*/
}
