//
// NLTokenizer+Extensions.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import NaturalLanguage

fileprivate let emDash = "—"



struct Tokenizer { //: SessionConfigurable {
                   //let sessionConfig: SessionConfig

    /*
    func tokenize( text:String ) -> [String] {
        return tokenizeSentences(text: text)
        //return NLTokenizer.tokenizePhrases(text: text)
    }
     */
    func tokenizeSentences(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences = [String]()
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let sentence = text[tokenRange]
            if !sentence.trim().isEmpty {
                sentences.append(String(sentence))
            }
            return true
        }
        
        return sentences
    }
    
    func tokenizeWords(text: String) -> [String] {
        //return tokenizeWords( text, separator: /[\s—,.;:!?|]/ )
        return tokenizeWords( text, separator: /[\s—,;!?|]/ )
        /*
        let s = text
        let tok = NLTokenizer(unit: .word)
        tok.string = s
        let words = tok.tokens(for: s.startIndex..<s.endIndex)
        var out: [String] = []
        var i = s.startIndex
        for (k, r) in words.enumerated() {
            if i < r.lowerBound { out.append(String(s[i..<r.lowerBound])) }
            let nextLo = (k + 1 < words.count) ? words[k + 1].lowerBound : s.endIndex
            out.append(String(s[r.lowerBound..<nextLo]))
            i = nextLo
        }
        if i < s.endIndex { out.append(String(s[i..<s.endIndex])) }
        return out
         */
    }
    
    func tokenizeWords(_ input: String, separator: Regex<Substring>) -> [String] {
        var tokens: [String] = []
        var from = input.startIndex

        for m in input.matches(of: separator) {
            let r = m.range
            let head = input[from..<r.lowerBound]
            let delim = input[r]

            if !head.isEmpty {
                var t = String(head)
                t.append(contentsOf: delim)
                tokens.append(t)
                from = r.upperBound
                continue
            }

            if tokens.isEmpty {
                tokens.append(String(delim))
            } else {
                tokens[tokens.index(before: tokens.endIndex)].append(contentsOf: delim)
            }
            from = r.upperBound
        }

        let tail = input[from...]
        if !tail.isEmpty { tokens.append(String(tail)) }
        
        let merged = coalescePunctOnlyWords(tokens).filter { !$0.trimmed().isEmpty }
        return merged
    }
    
    func tokenizePhrases(text: String) -> [String] {
        let phraseSeparators = [",", ":", ";", emDash]
        let minWordsForPhrase = 2
        
        let sentences = tokenizeSentences(text: text)
        let phrases = sentences.flatMap { (sentence) -> [String] in
            let sentenceWords = tokenizeWords(text: sentence)
            var sentencePhrases:[String] = []
            var phraseWords:[String] = []
            for (index,word) in sentenceWords.enumerated() {
                guard !word.isEmpty else { continue }
                
                phraseWords.append(word)
                
                guard phraseWords.count >= minWordsForPhrase else {
                    continue
                }
                guard index < sentenceWords.count - 2 else {
                    continue
                }

                if phraseSeparators.contains( String(word.trimmed().last!) ) {
                    sentencePhrases.append( phraseWords.joined() )
                    phraseWords = []
                }
            }
            if !phraseWords.isEmpty {
                sentencePhrases.append(phraseWords.joined())
            }
            return sentencePhrases
        }
        return phrases
    }
    
    /*
    func coalescePunctOnlyWords(_ words: [String]) -> [String] {
        var out: [String] = []
        for w in words {
            if w.isAllWhiteSpaceOrPunct {
                if out.isEmpty {
                    out.append(w)
                    continue
                }
                out[out.count - 1] += w
                continue
            }
            out.append(w)
        }
        return out
    }*/
    func coalescePunctOnlyWords(_ words: [String]) -> [String] {
        var out: [String] = []
        var leading = ""

        for w in words {
            if w.isAllWhiteSpaceOrPunct {
                if out.isEmpty {
                    leading += w
                } else {
                    out[out.count - 1] += w
                }
                continue
            }

            if !leading.isEmpty {
                out.append(leading + w)
                leading.removeAll(keepingCapacity: true)
            } else {
                out.append(w)
            }
        }

        if !leading.isEmpty { out.append(leading) }
        return out
    }
    
}
