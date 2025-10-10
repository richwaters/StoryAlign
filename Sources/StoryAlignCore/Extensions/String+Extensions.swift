//
//  String+Extensions.swift
//  StoryAlign
//
//  Created by Rich Waters on 4/14/25.
//

import Foundation


public extension String {
    
    // Can't use trim as name becuase it conflicts with SwiftSoup
    func trimmed() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func trimmingTrailingWhitespace() -> String {
        guard let idx = rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards)?.upperBound else { return "" }
        return String(self[..<idx])
    }
    
    func removeWhiteSpace() -> String {
        return replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
    }
    func removeNewlnes() -> String {
        return replacingOccurrences(of: "\n", with: "")
    }
    
    func collapseWhiteSpace() -> String {
        return replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    func safeSubstring(from start: Int, to end: Int) -> String {
        let lower = max(0, min(start, count))
        let upper = max(lower, min(end, count))
        
        let startIndex = index(startIndex, offsetBy: lower)
        let endIndex = index(startIndex, offsetBy: upper - lower)
        
        return String(self[startIndex..<endIndex])
    }
    
    
    func safeSubstring(from start: Int, length:Int? = nil) -> String {
        let len = length ?? self.count - start
        return safeSubstring(from: start, to: start+len)
    }
    func safeSubstring( to end:Int, length:Int) -> String {
        return safeSubstring(from: end-length, to: end)
    }
    
    var pathExtension: String {
        URL(fileURLWithPath: self).pathExtension
    }
    
    var isAllWhiteSpaceOrPunct:Bool {
        self.allSatisfy { $0.isWhitespace || $0.isPunctuation }
    }
    var endsWithWhiteSpace:Bool {
        guard let s = self.last else {
            return false
        }
        return s.isWhitespace
    }
    var startsWithWhiteSpace:Bool {
        let trimmed = drop { $0.isWhitespace }
        return trimmed.count < count
    }

    func escapingXMLEntities() -> String {
        var s = self
        s = s.replacingOccurrences(of: "&", with: "&amp;")
        s = s.replacingOccurrences(of: "<", with: "&lt;")
        s = s.replacingOccurrences(of: ">", with: "&gt;")
        s = s.replacingOccurrences(of: "\"", with: "&quot;")
        s = s.replacingOccurrences(of: "'", with: "&apos;")
        return s
    }

    func chunked(minLength: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        var i = 0
        let n = count
        
        let characters = Array(self)
        while i < n {
            let char = characters[i]
            current.append(char)

            if current.count >= minLength && char.isWhitespace {
                let candidate = current
                current = ""
                if candidate.trimmed().isEmpty {
                    current = candidate
                    i += 1
                    continue
                }
                chunks.append(candidate)
            }

            i += 1
        }

        if !current.isEmpty {
            if current.trimmed().isEmpty {
                if !chunks.isEmpty {
                    chunks[chunks.count - 1] += current
                    return chunks
                }
                chunks.append(current)
                return chunks
            }
            
            chunks.append(current)
            return chunks
        }

        return chunks
    }
    
    var hrefWithoutFragment: String {
          guard let i = firstIndex(of: "#") else { return self }
          return String(self[..<i])
      }
    
    subscript(i: Int) -> Character {
        let idx = self.index(self.startIndex, offsetBy: i)
        return self[idx]
    }
    
    var hasNonWhitespace: Bool {
        !self.trimmed().isEmpty
    }
}

extension String {
    // From whisper.cpp
    var voiceLength:Double {
        var res: Double = 0.0
        for c in self {
            switch c {
                case " ":
                    res += 0.01
                case ",":
                    res += 2.0
                case ".", "!", "?":
                    res += 3.0
                case "0"..."9":
                    res += 3.0
                default:
                    res += 1.0
            }
        }
        return res
    }
}

extension String {
    func buildOffsetsToIndices() -> [Int: String.Index] {
        Dictionary(uniqueKeysWithValues: indices.enumerated().map { (offset, idx) in
            (offset, idx)
        })
    }
}

extension Substring {
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func collapseWhiteSpace() -> String {
        return replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    

    
}


extension Character {
    var isDigit:Bool {
        return ("0"..."9").contains(self)
    }
}
