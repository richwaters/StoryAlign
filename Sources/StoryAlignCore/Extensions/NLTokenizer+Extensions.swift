//
// NLTokenizer+Extensions.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import NaturalLanguage
extension NLTokenizer {
    static func tokenizeSentences(text: String) -> [String] {
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
    
    static func tokenizeWords(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var words = [String]()
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = text[tokenRange]
            if !word.trim().isEmpty {
                words.append(String(word))
            }
            return true
        }
        
        return words
    }
    
    /*
    static func tokenizePhrases(text: String) -> [String] {
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
    }*/
}
