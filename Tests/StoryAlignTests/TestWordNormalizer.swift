//
//  TestWordNormalizer.swift
//  StoryAlign
//
//  Created by Rich Waters on 11/5/25.
//




import XCTest
@testable import StoryAlignCore
import Foundation

class TestWordNormalizer: XCTestCase {
    
    func testSpelledNumbers() throws {
        try doTestNormalizerWord(string: "42", expected: "forty-two")
        try doTestNormalizerWord(string: "  42", expected: "  forty-two")
        try doTestNormalizerWord(string: "42!", expected: "forty-two!")
        try doTestNormalizerWord(string: "007,", expected: "seven,")
        try doTestNormalizerWord(string: "0", expected: "zero")
        try doTestNormalizerWord(string: "10", expected: "ten")
        try doTestNormalizerWord(string: "20", expected: "twenty")
        try doTestNormalizerWord(string: "21", expected: "twenty-one")
        try doTestNormalizerWord(string: "99?!", expected: "ninety-nine?!")
        try doTestNormalizerWord(string: "105", expected: "one hundred five")
        try doTestNormalizerWord(string: "1000", expected: "one thousand")
        try doTestNormalizerWord(string: "1984", expected: "one thousand nine hundred eighty-four")
        try doTestNormalizerWord(string: "  \t12...", expected: "  \ttwelve...")
        try doTestNormalizerWord(string: "XIV", expected: "fourteen")
        try doTestNormalizerWord(string: "XLII!", expected: "forty-two!")
        try doTestNormalizerWord(string: "MCMLXXXIV", expected: "one thousand nine hundred eighty-four")
        try doTestNormalizerWord(string: "MMXXV.", expected: "two thousand twenty-five.")
        try doTestNormalizerWord(string: "IX)", expected: "nine)")
        try doTestNormalizerWord(string: "VI,", expected: "six,")
        try doTestNormalizerWord(string: "7—", expected: "seven—")
        try doTestNormalizerWord(string: "12…", expected: "twelve…")
    }
    
    func testDecimalPoints() throws {
        try doTestNormalizerWord(string: ".5.", expected: "point five." )
        try doTestNormalizerWord(string: "0.5.", expected: "zero point five." )
        try doTestNormalizerWord(string: "0.5", expected: "zero point five" )
        try doTestNormalizerWord(string: "0.5.1", expected: "zero point five point one" )
        try doTestNormalizerWord(string: "0.5.1.", expected: "zero point five point one." )


    }

    
    func testPercents() throws {
        let cases: [(String, String)] = [
            ("%", "percent"),
            ("%,", "percent,"),
            ("%;", "percent;"),
            ("0%", "zero percent"),
            ("1%", "one percent"),
            ("7%", "seven percent"),
            ("10%", "ten percent"),
            ("21%", "twenty-one percent"),
            ("42%", "forty-two percent"),
            ("90%", "ninety percent"),
            ("99%?!", "ninety-nine percent?!"),
            ("100%—", "one hundred percent—"),
            ("1984%.", "one thousand nine hundred eighty-four percent."),
            ("007%", "seven percent"),
            ("  12%", "  twelve percent"),
            ("12%,", "twelve percent,"),
            ("12%...", "twelve percent..."),
            ("6%…", "six percent…")
        ]
        for (str,expected) in cases {
            try doTestNormalizerWord(string: str, expected: expected)
        }
    }

}


extension TestWordNormalizer {
    func doTestNormalizerWord(string: String, expected:String) throws {
        let wordNormalizer = WordNormalizer()
        let expectedDeltaLen = expected.count - string.count
        let (resultStr, resultDeltaLen) = wordNormalizer.normalizedWord(string)
        XCTAssertEqual(resultStr, expected )
        XCTAssertEqual(resultDeltaLen, expectedDeltaLen)
    }
}
