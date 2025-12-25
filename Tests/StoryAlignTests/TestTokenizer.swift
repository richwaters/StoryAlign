//
//  TestTokenizer.swift
//  StoryAlign
//
//  Created by Rich Waters on 11/3/25.
//



import XCTest
@testable import StoryAlignCore
import Foundation

class TestTokenizer: XCTestCase {
    var tokenizer = Tokenizer()
    
    func testPhraseWithCommas() throws {
        let sentence = "This is a test, with commas."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "This is a test, ",
            "with commas."
        ])
    }
    
    func testPhraseWithEmDash() throws {
        let sentence = "This is a test—with emdash."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "This is a test—",
            "with emdash."
        ])
    }
    func testPhraseWithSemiColon() throws {
        let sentence = "This is a test; with semicolon."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "This is a test; ",
            "with semicolon."
        ])
    }
    func testPhraseWithNeighborSeparators() throws {
        let sentence = "This is a test;,with neighbor separators."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "This is a test;,",
            "with neighbor separators."
        ])
    }
    
    func testMultiSentenceMultiSep1() throws {
        let sentence = "He hesitated, unsure what to say next; the silence felt heavier than words. Then—without warning—she laughed: loud, bright, unrestrained."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "He hesitated, ",
            "unsure what to say next; ",
            "the silence felt heavier than words. ",
            "Then—without warning—",
            "she laughed: ",
            "loud, bright, unrestrained."
        ])
    }
    
    func testMultiSentenceMultiSep2() throws {
        let sentence = "I brought the maps, pens, and coffee. You bring the plan: something bold, maybe impossible. If it fails, we’ll blame the weather—or fate."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "I brought the maps, ",
            "pens, and coffee. ",
            "You bring the plan: ",
            "something bold, ",
            "maybe impossible. ",
            "If it fails, ",
            "we’ll blame the weather—",
            "or fate."
        ])
    }
    
    func testMultiSentenceMultiSep3() throws {
        let sentence = "She paused at the gate—just long enough to remember. The key turned easily, almost too easily. Inside, the house smelled of cedar, dust, and something sweet."
        let phrases = tokenizer.tokenizePhrases(text: sentence)
        XCTAssertEqual(phrases, [
            "She paused at the gate—",
            "just long enough to remember. ",
            "The key turned easily, ",
            "almost too easily. ",
            "Inside, the house smelled of cedar, ",
            "dust, and something sweet."
        ])
    }
    
    func testTokenizeWordsWithMergedPunct() {
        do {
            let sentence = " Meet the author."
            let result = tokenizer.tokenizeWords(text:sentence)
            let expected = [" Meet ", "the ", "author."]
            XCTAssertEqual(result,expected)
        }
        do {
            let sentence = "This is a test. "
            let result = tokenizer.tokenizeWords(text:sentence)
            let expected = ["This ", "is ", "a ", "test. "]
            XCTAssertEqual(result,expected)
        }
        
        do {
            let sentence = "\"Mars is America,\" Tori said, waving his beer expansively."
            let result = tokenizer.tokenizeWords(text:sentence)
            let expected = ["\"Mars ", "is ", "America,\" ", "Tori ", "said, ", "waving ", "his ", "beer ", "expansively."]
            XCTAssertEqual(result,expected)
        }
    }
}
