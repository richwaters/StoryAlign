//
//  TestGetXhtmlSentences.swift
//  StoryAlign
//
//  Created by Rich Waters on 5/6/25.
//



import XCTest
@testable import StoryAlignCore
import Foundation


fileprivate let sessionConfig = try! SessionConfig(sessionDir: nil, modelFile: "",  runStage: .transcribe, logger: TestsLogger(), audioLoaderType:.avfoundation,  reportType: .full)
fileprivate let xmlTagger = XHTMLTagger(sessionConfig: sessionConfig)


class TestGetXhtmlSentences: XCTestCase {
    func testGetSentencesFromTextNode() throws {
        let htmlString = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
            <head>
            </head>
                <body>
                   <p>
                    This is a text node. It has multiple sentences. Well, three, at least.
                    </p>
                </body>
            </html>
            """
        
        let expected = [
            " This is a text node. ",
            "It has multiple sentences. ",
            "Well, three, at least. ",
        ]
        
        let sentences = try xmlTagger.getXHtmlSentences(from: htmlString)
        
        XCTAssertEqual(sentences, expected)
    }
    
    func testGetSentencesFromSingleElement() throws {
        let htmlString = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
            <head>
            </head>
                <body>
                    <p xmlns="http://www.w3.org/1999/xhtml">
                        This is a text node. It has multiple sentences. Well, three, at least.
                        <span>Maybe, even, four?</span>
                        In fact, five!
                   </p>
                </body>
            </html>
            """
        
        let expected = [
            " This is a text node. ",
            "It has multiple sentences. ",
            "Well, three, at least. ",
            "Maybe, even, four? ",
            "In fact, five! ",
        ]
        
        let sentences = try xmlTagger.getXHtmlSentences(from: htmlString)
        
        XCTAssertEqual(sentences, expected)
    }
    
    
    func testGetSentencesFromNestedElement() throws {
        let htmlString = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
            <head>
            </head>
                <body>
                    <p xmlns="http://www.w3.org/1999/xhtml">
                      This is a text node. It has multiple sentences. Well, three, at least.
                      <span>Maybe, even, four?</span>
                      This sentence... 
                    </p>
                    <p xmlns="http://www.w3.org/1999/xhtml">
                      will be broken up, since it crosses multiple blocks.
                    </p>
                </body>
            </html>
            """
        
        let expected = [
            " This is a text node. ",
            "It has multiple sentences. ",
            "Well, three, at least. ",
            "Maybe, even, four? ",
            "This sentence... ",
            " will be broken up, since it crosses multiple blocks. "
        ]
        
        let sentences = try xmlTagger.getXHtmlSentences(from: htmlString)
        
        XCTAssertEqual(sentences, expected)
    }
    
    
}

