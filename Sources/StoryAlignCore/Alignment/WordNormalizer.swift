//
//  WordNormalizer.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation


class WordNormalizer {
    static let emDash = "—"
    let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f
    }()
    
    let punctuationMap:[Character: Character] = [
        "“": "\"",
        "”": "\"",
        "„": "\"",
        "‟": "\"",
        "«": "\"",
        "»": "\"",
        "〝": "\"",
        "〞": "\"",
        "‘": "'",
        "’": "'",
        "‚": "'",
        "‛": "'",
        "‐": "-", // Unicode Hyphen
        "‑": "-", // Non-breaking Hyphen
        "‒": "-", // Figure Dash  -- used for phone numbers
        "–": "-", // En Dash -- used for ranges 10-47

        
        // These break up tokens -- so don't map them to hyphens
        // Em-Dash == —
        // "—": "—", // Em Dash -- used to separate thoughts - almost like a period
        //
        "―": WordNormalizer.emDash.first!, // Horizontal Bar -- map to EM Dash
        
        //"…": "...",
        "‹": "<",
        "›": ">"
    ]

    func normalizePunctuation(_ input: String) -> String {
        let nuChars = input.map {
            if let nuChar = punctuationMap[$0] {
                return nuChar
            }
            return $0
        }
        return String(nuChars).replacingOccurrences(of: "--", with: Self.emDash)
    }

    private var spelledNumberCache = [String:String]()

    func normalizedWord(_ word: String) -> (String, Int) {
        let leading  = word.prefix { $0.isWhitespace }
        let trailingChars = word.reversed().prefix { $0.isPunctuation }
        let trailing = String(trailingChars.reversed())
        let core = String( word.dropFirst(leading.count).dropLast(trailing.count) )
        
        let numberValue:Int? = {
            let allDigits = core.allSatisfy { $0.isNumber }
            if allDigits {
                return Int(core)
            }
            if isRomanNumeral(core) {
                return intFromRomanNumeral(core)
            }
            return nil
        }()
        
        guard let i = numberValue else {
            let wordWithNormalizedPunct = normalizePunctuation(word)
            return(wordWithNormalizedPunct,0)
        }
        //if i > 10000 {
        //return (normalizePunctuation(word),0)
        //}

        let key = String(core)
        let spelled = spelledNumberCache[key]
        ?? {
            let s = numberFormatter.string(from: NSNumber(value: i))!
            spelledNumberCache[key] = s
            return s
        }()
        let newWord = "\(leading)\(spelled)\(trailing)"
        return (newWord, newWord.count - word.count)
    }
    
    
    func normalizeWordsInSentence(_ sentence: String) -> String {
        let re = try! NSRegularExpression(pattern: #"(\S+)|(\s+)"#)
        let ns = sentence as NSString
        var out = ""
        re.enumerateMatches(in: sentence, range: NSRange(location:0, length:ns.length)) { m, _, _ in
            guard let m = m else { return }
            let run = ns.substring(with: m.range)
            if run.first!.isWhitespace {
                out += run
            } else {
                out += normalizedWord(run).0
            }
        }
        return out
    }
    
    func isRomanNumeral(_ core:String ) -> Bool {
        core.range(of: "^[IVXLCDM]{2,}$", options: .regularExpression) != nil
    }
    
    func intFromRomanNumeral(_ s:String ) -> Int? {
        let vals: [Character:Int] = [
            "I":1, "V":5,  "X":10, "L":50,
            "C":100, "D":500, "M":1000
        ]
        var total = 0
        var prev = 0
        for c in s.uppercased().reversed() {
            guard let v = vals[c] else { return nil }
            if v < prev {
                total -= v
            } else {
                total += v
                prev = v
            }
        }
        return total
    }
}
