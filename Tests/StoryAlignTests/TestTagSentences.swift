//
//  TestTagSentences.swift
//  StoryAlign
//
//  Created by Rich Waters on 5/4/25.
//


import XCTest
import SwiftSoup
@testable import StoryAlignCore
import Foundation

func normalize( xml:String ) throws -> String {
    //let doc = try XMLDocument(xmlString: xml, options:.documentTidyXML)
    let doc = try XMLDocument(xmlString: xml, options:.documentTidyXML)
    return doc.xmlString()
    //return doc.rootElement()?.canonicalXMLStringPreservingComments(true) ?? ""
    
    /*
    let doc = try XMLDocument(xmlString: xml, options: [.nodePreserveWhitespace])
    let data = doc.xmlData(options: [.nodeCompactEmptyElement])
    let out  = String(data: data, encoding: .utf8)!
    return out
     */
}

class AppendTextNodeTests: XCTestCase {
    let xmlTagger = XHTMLTagger()

    func testCanAppendTextNodesToEmptyParents() throws {
        let container = Element(Tag(""), "")
        var sentences = Set<Int>()
        try xmlTagger.appendTextNode(chapterId: "chapter_one", xml: container, text: "test", marks: [], taggedSentences: &sentences, sentenceId: nil)
        XCTAssertEqual(container.getChildNodes().count, 1)
        try XCTAssertEqual(container.getChildNodes().first?.outerHtml().trim(), "test")
    }
    func testCanAppendTextNodesWithMarks() throws {
        let container = Element(Tag(""), "")
        var sentences = Set<Int>()
        let attrs = Attributes()
        try attrs.put(attribute: Attribute(key: "href", value: "#"))
        let marks: [Mark] = [
            Mark(elementName: "a", attributes: attrs )
        ]
        try xmlTagger.appendTextNode(
            chapterId: "chapter_one",
            xml: container,
            text: "test",
            marks: marks,
            taggedSentences: &sentences,
            sentenceId: nil
        )
        
        let firstChild = container.getChildNodes().first!
        XCTAssertEqual(container.getChildNodes().count, 1)
        XCTAssertEqual(
            try normalize(xml:firstChild.outerHtml()),
            try normalize( xml:"<a href=\"#\">test</a>")
        )
    }
    
    func testCanWrapTextNodesWithSentenceSpans() throws {
        let container = Element(Tag(""), "")
        var sentences = Set<Int>()
        try xmlTagger.appendTextNode(
            chapterId: "chapter_one",
            xml: container,
            text: "test",
            marks: [],
            taggedSentences: &sentences,
            sentenceId: 0
        )
        XCTAssertEqual(container.getChildNodes().count, 1)
        let firstChild = container.getChildNodes().first!
        
        XCTAssertEqual(
            try normalize(xml:firstChild.outerHtml()),
            try normalize( xml:"<span id=\"chapter_one-sentence0\">test</span>")
        )
    }
    
    func testCanJoinTextNodesWithSameSentenceIds() throws {
        let container = Element(Tag(""), "")
        let span = Element(Tag("span"), "")
        try span.attr("id", "chapter_one-sentence0")
        try span.appendText("test")
        try container.appendChild(span)
        
        var sentences = Set<Int>()
        try xmlTagger.appendTextNode(
            chapterId: "chapter_one",
            xml: container,
            text: "test",
            marks: [],
            taggedSentences: &sentences,
            sentenceId: 0
        )
        
        XCTAssertEqual(container.getChildNodes().count, 1)
        let firstChild = container.getChildNodes().first!
        XCTAssertEqual(
            try normalize(xml:firstChild.outerHtml()),
            try normalize(xml:"<span id=\"chapter_one-sentence0\">testtest</span>")
        )
    }
}

class TagSentencesTests: XCTestCase {
    let xmlTagger = XHTMLTagger()

    func testCanTagSentences() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html>
          <head>
            <meta charset="utf-8" />
            <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
          </head>
          <body>
            <p>
                Call me Ishmael. Some years ago—never mind how long precisely—having
                little or no money in my purse, and nothing particular to interest me on
                shore, I thought I would sail about a little and see the watery part of
                the world.
            </p>
          </body>
        </html>
        """
        
        
        let expected = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html>
          <head>
            <meta charset="utf-8"/>
            <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
          </head>
          <body>
            <p>
                <span id="chapter_one-sentence0">Call me Ishmael.</span> <span id="chapter_one-sentence1">Some years ago—never mind how long precisely—having
                little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of
                the world.</span>
            </p>
          </body>
        </html>
        """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")

        try XCTAssertEqual( normalize(xml: result), normalize(xml:expected) )
    }
    
    func testCanTagSentencesWithFormattingMarks() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html>
          <body>
            <p>Call me <strong>Ishmael</strong>. Some years ago.</p>
          </body>
        </html>
        """

        let expected = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html>
          <head></head>
          <body>
            <p><span id="chapter_one-sentence0">Call me <strong>Ishmael</strong>.</span> <span id="chapter_one-sentence1">Some years ago.</span></p>
          </body>
        </html>
        """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        try XCTAssertEqual( normalize(xml: result), normalize(xml:expected) )
    }
    
    func testCanTagMultipleParagraphs() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
              <head>
                <meta charset="utf-8" />
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    Call me Ishmael. Some years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world. It is a way I have of driving off the spleen and regulating the
                    circulation. Whenever I find myself growing grim about the mouth; whenever
                    it is a damp, drizzly November in my soul; whenever I find myself
                    involuntarily pausing before coffin warehouses, and bringing up the rear
                    of every funeral I meet; and especially whenever my hypos get such an
                    upper hand of me, that it requires a strong moral principle to prevent me
                    from deliberately stepping into the street, and methodically knocking
                    people’s hats off—then, I account it high time to get to sea as soon
                    as I can.
                </p>
                <p>
                    This is my substitute for pistol and ball. With a philosophical
                    flourish Cato throws himself upon his sword; I quietly take to the ship.
                    There is nothing surprising in this. If they but knew it, almost all men
                    in their degree, some time or other, cherish very nearly the same feelings
                    towards the ocean with me.
                </p>
              </body>
            </html>
            """
        
        let expected = """
            <?xml version="1.0" encoding="UTF-8"?><html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <span id="chapter_one-sentence0">Call me Ishmael.</span> <span id="chapter_one-sentence1">Some years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.</span> <span id="chapter_one-sentence2">It is a way I have of driving off the spleen and regulating the
                    circulation.</span> <span id="chapter_one-sentence3">Whenever I find myself growing grim about the mouth; whenever
                    it is a damp, drizzly November in my soul; whenever I find myself
                    involuntarily pausing before coffin warehouses, and bringing up the rear
                    of every funeral I meet; and especially whenever my hypos get such an
                    upper hand of me, that it requires a strong moral principle to prevent me
                    from deliberately stepping into the street, and methodically knocking
                    people’s hats off—then, I account it high time to get to sea as soon
                    as I can.</span>
                </p>
                <p>
                    <span id="chapter_one-sentence4">This is my substitute for pistol and ball.</span> <span id="chapter_one-sentence5">With a philosophical
                    flourish Cato throws himself upon his sword; I quietly take to the ship.</span>
                    <span id="chapter_one-sentence6">There is nothing surprising in this.</span> <span id="chapter_one-sentence7">If they but knew it, almost all men
                    in their degree, some time or other, cherish very nearly the same feelings
                    towards the ocean with me.</span>
                </p>
              </body>
            </html>
            """

        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanTagSentencesWithOverlappingFormattingMarks() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
              <head>
                <meta charset="utf-8" />
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    Call me <strong>Ishmael. Some years ago</strong>—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.
                </p>
              </body>
            </html>
            """

        /*
        let expected = """
            <?xml version="1.0" encoding="UTF-8"?><html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <span id="chapter_one-sentence0">Call me <strong>Ishmael.</strong></span><strong> </strong><span id="chapter_one-sentence1"><strong>Some years ago</strong>—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.</span>
                </p>
              </body>
            </html>
            """
         */
        
        let expected = """
            <?xml version="1.0" encoding="UTF-8"?><html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <span id="chapter_one-sentence0">Call me <strong>Ishmael.</strong></span><span id="chapter_one-sentence1"><strong>Some years ago</strong>—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.</span>
                </p>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanTagSentencesWithNestedFormattingMarks() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
              <head>
                <meta charset="utf-8" />
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <em>Call me <strong>Ishmael</strong>.</em> Some years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.
                </p>
              </body>
            </html>
            """

        let expected = """
            <?xml version="1.0" encoding="UTF-8"?><html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <span id="chapter_one-sentence0"><em>Call me </em><em><strong>Ishmael</strong></em><em>.</em></span> <span id="chapter_one-sentence1">Some years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.</span>
                </p>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanTagSentencesWithAtoms() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
              <head>
                <meta charset="utf-8" />
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    Call me Ishmael. Some<img src="#"/> years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.
                </p>
              </body>
            </html>
            """

        let expected = """
            <?xml version="1.0" encoding="UTF-8"?><html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <span id="chapter_one-sentence0">Call me Ishmael.</span> <span id="chapter_one-sentence1">Some<img src="#"></img> years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore, I thought I would sail about a little and see the watery part of
                    the world.</span>
                </p>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanTagSentencesInNestedTextBlocks() throws {
        let xml = """
            <?xml version='1.0' encoding='utf-8'?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"
                  epub:prefix="z3998: http://www.daisy.org/z3998/2012/vocab/structure/#" lang="en" xml:lang="en">
              <head>
                <link href="../styles/9781534431010.css" rel="stylesheet" type="text/css" />
                <link href="../styles/SS_global.css" rel="stylesheet" type="text/css" />
                <link rel="stylesheet" href="../../Styles/storyalign.css" type="text/css" />
              </head>
              <body>
                <blockquote class="blockquotelet">
                  <p class="blockno"><span aria-label="page 7" id="page_7" role="doc-pagebreak" /></p>
                  <p class="blockno">Look on my works, ye mighty, and despair!</p>
                  <p class="blockno1">A little joke.</p>
                  <p class="blockno1"> </p>
                  <p class="blockno1">Trust that I have accounted for all variables of irony.</p>
                  <p class="blockno1"> </p>
                  <p class="blockno1">Though I suppose if you’re unfamiliar with overanthologized works of the early Strand 6
                    nineteenth century, the joke’s on me.</p>
                  <p class="blockin">I hoped you’d come.</p>
                </blockquote>
              </body>
            </html>
            """
    
        let expected = """
            <?xml version="1.0" encoding="utf-8"?><!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" epub:prefix="z3998: http://www.daisy.org/z3998/2012/vocab/structure/#" lang="en" xml:lang="en">
              <head>
                <link href="../styles/9781534431010.css" rel="stylesheet" type="text/css"/>
                <link href="../styles/SS_global.css" rel="stylesheet" type="text/css"/>
                <link rel="stylesheet" href="../../Styles/storyalign.css" type="text/css"/>
              </head>
              <body>
                <blockquote class="blockquotelet">
                  <p class="blockno"><span aria-label="page 7" id="page_7" role="doc-pagebreak"/></p>
                  <p class="blockno"><span id="chapter_one-sentence0">Look on my works, ye mighty, and despair!</span></p>
                  <p class="blockno1"><span id="chapter_one-sentence1">A little joke.</span></p>
                  <p class="blockno1"> </p>
                  <p class="blockno1"><span id="chapter_one-sentence2">Trust that I have accounted for all variables of irony.</span></p>
                  <p class="blockno1"> </p>
                  <p class="blockno1"><span id="chapter_one-sentence3">Though I suppose if you’re unfamiliar with overanthologized works of the early Strand 6
                    nineteenth century, the joke’s on me.</span></p>
                  <p class="blockin"><span id="chapter_one-sentence4">I hoped you’d come.</span></p>
                </blockquote>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanTagSentencesAcrossTextBlockBoundaries() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    Call me Ishmael. Some years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore,
                </p>
                <p>
                    I thought I would sail about a little and see the watery part of
                    the world.
                </p>
              </body>
            </html>
            """

        let expected = """
            <?xml version="1.0" encoding="UTF-8"?><html>
              <head>
                <meta charset="utf-8"/>
                <title>The Project Gutenberg eBook of Moby Dick; Or the Whale, by Herman Melville</title>
              </head>
              <body>
                <p>
                    <span id="chapter_one-sentence0">Call me Ishmael.</span> <span id="chapter_one-sentence1">Some years ago—never mind how long precisely—having
                    little or no money in my purse, and nothing particular to interest me on
                    shore,</span>
                </p>
                <p>
                    <span id="chapter_one-sentence2">I thought I would sail about a little and see the watery part of
                    the world.</span>
                </p>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanHandleSoftPageBreaks() throws {
        let xml = """
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en-US" xml:lang="en-US">
              <head>
                <title>Chapter 1, Black Powder War</title>
                <meta charset="utf-8"/>
                <link href="../css/prh_resets.css" rel="stylesheet" type="text/css"/>
                <link href="../css/rh_static.css" rel="stylesheet" type="text/css"/>
                <link href="../css/9780345493439_style.css" rel="stylesheet" type="text/css"/>
              <meta content="urn:uuid:52698e83-e600-48be-b763-c64bde1e3e0c" name="Adept.expected.resource"/>
              </head>
              <body>
                <a id="d1-d2s6d3s2"/>
                <div class="page_top_padding">
                  <span epub:type="pagebreak" id="page_9" role="doc-pagebreak" title="9"/>
                  <h1 class="para-cn-chap-pg trajan-pro-3">CHAPTER 1</h1>
                  <div class="para-orn">
                    <span class="figure figure_dingbat">
                    <img alt="" class="height_1em" role="presentation" src="../images/Novi_9780345493439_epub3_001_r1.jpg"/></span></div>
                  <p class="para-pf dropcaps3line char-dropcap-DC trajan-pro-3-dc" style="text-indent:0;">The hot wind blowing into Macao was sluggish and unrefreshing, only stirring up the rotting salt smell of the harbor, the fish-corpses and great knots of black-red seaweed, the effluvia of human and dragon wastes. Even so the sailors were sitting crowded along the rails of the <i class="char-i">Allegiance</i> for a breath of the moving air, leaning against one another to get a little room. A little scuffling broke out amongst them from time to time, a dull exchange of shoving back and forth, but these quarrels died almost at once in the punishing heat.</p>
                  <p class="para-p">Temeraire lay disconsolately upon the dragondeck, gazing towards the white haze of the open ocean, the aviators on duty lying half-asleep in his great shadow. Laurence himself had sacrificed dignity so far as to take off his coat, as he was sitting in the crook of Temeraire’s foreleg and so concealed from view.</p>
                  <p class="para-p">“I am sure I could pull the ship out of the harbor,” Temeraire said, not for the first time in the past week; and sighed when this amiable plan was again refused: in a calm he might indeed have been able to tow even the enormous dragon transport, but against a direct headwind he could only exhaust himself to no purpose.</p>
                  <span epub:type="pagebreak" id="page_10" role="doc-pagebreak" title="10"/>
                  <p class="para-p">“Even in a calm you could scarcely pull her any great distance,” Laurence added consolingly. “A few miles may be of some use out in the open ocean, but at present we may as well stay in harbor, and be a little more comfortable; we would make very little speed even if we could get her out.”</p>
                  <p class="para-p">“It seems a great pity to me that we must always be waiting on the wind, when everything else is ready and we are also,” Temeraire said. “I would so like to be home <i class="char-i">soon:</i> there is so very much to be done.” His tail thumped hollowly upon the boards, for emphasis.</p>
                  <p class="para-p">“I beg you will not raise your hopes too high,” Laurence said, himself a little hopelessly: urging Temeraire to restraint had so far not produced any effect, and he did not expect a different event now. “You must be prepared to endure some delays; at home as much as here.”</p>
                </div>
              </body>
            </html>
            """
    
        let expected = """
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en-US" xml:lang="en-US">
              <head>
                <title>Chapter 1, Black Powder War</title>
                <meta charset="utf-8"/>
                <link href="../css/prh_resets.css" rel="stylesheet" type="text/css"/>
                <link href="../css/rh_static.css" rel="stylesheet" type="text/css"/>
                <link href="../css/9780345493439_style.css" rel="stylesheet" type="text/css"/>
              <meta content="urn:uuid:52698e83-e600-48be-b763-c64bde1e3e0c" name="Adept.expected.resource"/>
              </head>
              <body>
                <a id="d1-d2s6d3s2"/>
                <div class="page_top_padding">
                  <span epub:type="pagebreak" id="page_9" role="doc-pagebreak" title="9"/>
                  <h1 class="para-cn-chap-pg trajan-pro-3"><span id="chapter_one-sentence0">CHAPTER 1</span></h1>
                  <div class="para-orn">
                   <span class="figure figure_dingbat"><img alt="" class="height_1em" role="presentation" src="../images/Novi_9780345493439_epub3_001_r1.jpg"/></span></div>
                  <p class="para-pf dropcaps3line char-dropcap-DC trajan-pro-3-dc" style="text-indent:0;"><span id="chapter_one-sentence1">The hot wind blowing into Macao was sluggish and unrefreshing, only stirring up the rotting salt smell of the harbor, the fish-corpses and great knots of black-red seaweed, the effluvia of human and dragon wastes.</span> <span id="chapter_one-sentence2">Even so the sailors were sitting crowded along the rails of the <i class="char-i">Allegiance</i> for a breath of the moving air, leaning against one another to get a little room.</span> <span id="chapter_one-sentence3">A little scuffling broke out amongst them from time to time, a dull exchange of shoving back and forth, but these quarrels died almost at once in the punishing heat.</span></p>
                  <p class="para-p"><span id="chapter_one-sentence4">Temeraire lay disconsolately upon the dragondeck, gazing towards the white haze of the open ocean, the aviators on duty lying half-asleep in his great shadow.</span> <span id="chapter_one-sentence5">Laurence himself had sacrificed dignity so far as to take off his coat, as he was sitting in the crook of Temeraire’s foreleg and so concealed from view.</span></p>
                  <p class="para-p"><span id="chapter_one-sentence6">“I am sure I could pull the ship out of the harbor,” Temeraire said, not for the first time in the past week; and sighed when this amiable plan was again refused: in a calm he might indeed have been able to tow even the enormous dragon transport, but against a direct headwind he could only exhaust himself to no purpose.</span></p>
                  <span epub:type="pagebreak" id="page_10" role="doc-pagebreak" title="10"/>
                  <p class="para-p"><span id="chapter_one-sentence7">“Even in a calm you could scarcely pull her any great distance,” Laurence added consolingly.</span> <span id="chapter_one-sentence8">“A few miles may be of some use out in the open ocean, but at present we may as well stay in harbor, and be a little more comfortable; we would make very little speed even if we could get her out.”</span></p>
                  <p class="para-p"><span id="chapter_one-sentence9">“It seems a great pity to me that we must always be waiting on the wind, when everything else is ready and we are also,” Temeraire said.</span> <span id="chapter_one-sentence10">“I would so like to be home <i class="char-i">soon:</i> there is so very much to be done.”</span> <span id="chapter_one-sentence11">His tail thumped hollowly upon the boards, for emphasis.</span></p>
                  <p class="para-p"><span id="chapter_one-sentence12">“I beg you will not raise your hopes too high,” Laurence said, himself a little hopelessly: urging Temeraire to restraint had so far not produced any effect, and he did not expect a different event now.</span> <span id="chapter_one-sentence13">“You must be prepared to endure some delays; at home as much as here.”</span></p>
                </div>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanHandleBooleanLikeTextValues() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
            <p>true</p>
            </body>
            </html>
            """

        let expected = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
            <p><span id="chapter_one-sentence0">true</span></p>
            </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanHandleNumberLikeTextValues() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
            <p>5.000</p>
            </body>
            </html>
            """

        let expected = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
            <p><span id="chapter_one-sentence0">5.000</span></p>
            </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testCanHandleNullLikeTextValues() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
            <p>null</p>
            </body>
            </html>
            """
 
        let expected = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
            <p><span id="chapter_one-sentence0">null</span></p>
            </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testNoDupIdsCreated() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
               <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.1">Bren escorted me, with no one else, no shiftparents, though he had no official role in Embassytown. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.2">(I didn’t know that then.) That was a time, though, before he withdrew from the last of such informal Staff-like roles. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.3">He tried to be kind to me. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.4">I remember we skirted Embassytown’s edges and I saw for the first time the scale of the enormous throats that delivered biorigging and supplies to us. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.5">They flexed, wet and warm ends of siphons extending kilometres beyond our boundaries. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.6">I saw other craft over the city: some biorigged, some old Terretech, some chimerical.</span>
               </p>
            </body>
            </html>
"""
        let expected = """
          <?xml version="1.0" encoding="UTF-8" standalone="no"?>
          <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
           <head></head>
           <body>
            <p class="indent">
              <span id="chapter_one-sentence0">
                 <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.1">
                     Bren escorted me, with no one else, no shiftparents, though he had no official role in Embassytown.
                 </span>
             </span>
             <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.2">
              <span id="chapter_one-sentence1">(I didn’t know that then.)</span>
              <span id="chapter_one-sentence2">That was a time, though, before he withdrew from the last of such informal Staff-like roles.</span>
             </span>
             <span id="chapter_one-sentence3">
                 <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.3">
                      He tried to be kind to me.</span>
                 </span>
             </span>
             <span id="chapter_one-sentence4">
                 <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.4">
                     I remember we skirted Embassytown’s edges and I saw for the first time the scale of the enormous throats that delivered biorigging and supplies to us.
                 </span>
             </span>
              <span id="chapter_one-sentence5">
                  <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.5">
                      They flexed, wet and warm ends of siphons extending kilometres beyond our boundaries.
                  </span>
             </span>
             <span id="chapter_one-sentence6">
                 <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.6">
                     I saw other craft over the city: some biorigged, some old Terretech, some chimerical.</span>
                 </span>
             </span> 
            </p>  
           </body>
          </html>
"""
        
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
        
       
    }
    
    func testLastWithNewlineBeforeP() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
               <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.1">Bren escorted me, with no one else, no shiftparents, though he had no official role in Embassytown. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.6">I saw other craft over the city: some biorigged, some old Terretech, some chimerical.</span>
                </p>
            </body>
            </html>
"""
        
        let expected = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
               <p class="indent">
                    <span id="chapter_one-sentence0">
                        <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.1">Bren escorted me, with no one else, no shiftparents, though he had no official role in Embassytown. </span>
                    </span>
                    <span id="chapter_one-sentence1">
                        <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.70.6">I saw other craft over the city: some biorigged, some old Terretech, some chimerical.</span>
                    </span>
                </p>
            </body>
            </html>
            """

        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testComplexNoDupIdsCreated() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
                <p class="indent">
                    <span class="koboSpan" id="kobo.70.2" xmlns="http://www.w3.org/1999/xhtml">(I didn’t know that then.) That was a time, though, before he withdrew from the last of such informal <i>Staff like</i> roles.</span></p>
            </body>
            </html>
        """
        
        let expected = """
              <?xml version="1.0" encoding="UTF-8" standalone="no"?>
              <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
               <head></head>
                <body>
                 <p class="indent">
                  <span class="koboSpan" id="kobo.70.2" xmlns="http://www.w3.org/1999/xhtml">
                   <span id="chapter_one-sentence0">(I didn’t know that then.)</span>
                   <span id="chapter_one-sentence1">That was a time, though, before he withdrew from the last of such informal 
                    <i>
                     Staff like
                    </i> roles.</span>
                  </span>
                 </p>
                </body>
              </html>
        """

        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
        
    }
    
    
    func testItalicsInMiddleOfSentence() throws {
        //<p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.1">“You think they knew?” </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.2">I said. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.3">“And who went </span><i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.87.1">what</span></i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.88.1">?”</span></p>
        
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>

                 <p class="indent">
                     <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.1">
                             “You think they knew?” 
                    </span>
                    <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.2">
                        I said. 
                    </span>
                    <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.3">
                          “And who went 
                    </span>
                         <i>
                            <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.87.1">what</span>
                        </i>
                    <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.88.1">?”</span></p>
            </body>
            </html>
"""
        
        let expected = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head></head>
             <body>
              <p class="indent">
               <span id="chapter_one-sentence0">
                   <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.1">
                       “You think they knew?”</span>
                   </span>
               </span>
               <span id="chapter_one-sentence1">
                   <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.2">
                      I said.
                   </span>
               </span>
               <span id="chapter_one-sentence2">
                   <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.86.3">
                        “And who went
                   </span>
                       <i> 
                           <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.87.1">
                              what
                           </span>
                       </i>
                   <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.88.1">
                     ?”
                   </span>
                </span>
              </span>
              </p>  
             </body>
             </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    
    
    func testPunctuationIsolated() throws {
        //
        
        /*
        let xml = """
            <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
            </head>
            <body>
        
            <p class="indent">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.4">They think I can do anything now. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.5">Except they don’t, really: they just want the opportunity to say ‘floak.’
                ”</span>
              </p>  
             </body>
             </html>
        """
         */
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <head>
        </head>
        <body>
            <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.1">“Did they tell you I can floak?” </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.2">I said. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.3">“I wish I’d never told them that fucking word. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.4">They think I can do anything now. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.5">Except they don’t, really: they just want the opportunity to say ‘floak.’”</span></p>
                <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.1">“They’re talking to the exots.” </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.2">Ra said. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.3">“The Ambassadors have to let the Kedis and the others know something’s happening. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.4">They were obviously hoping they’d have things under control, but …” My doorbell sounded again. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.5">“Wait,” he said, but I was already up and out of the room.</span>
        </p>
        </body>
        </html>
        """
        
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <head/>
              <body>
                <p class="indent">
                  <span id="chapter_one-sentence0"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.1">“Did they tell you I can floak?” </span></span>
                  <span id="chapter_one-sentence1"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.2">I said. </span></span>
                  <span id="chapter_one-sentence2"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.3">“I wish I’d never told them that fucking word. </span></span>
                  <span id="chapter_one-sentence3"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.4">They think I can do anything now. </span></span>
                  <span id="chapter_one-sentence4"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.71.5">Except they don’t, really: they just want the opportunity to say ‘floak.’”</span></span>
                </p>
                <p class="indent">
                  <span id="chapter_one-sentence5"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.1">“They’re talking to the exots.” </span></span>
                  <span id="chapter_one-sentence6"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.2">Ra said. </span></span>
                  <span id="chapter_one-sentence7"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.3">“The Ambassadors have to let the Kedis and the others know something’s happening. </span></span>
                  <span id="chapter_one-sentence8"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.4">They were obviously hoping they’d have things under control, but …” My doorbell sounded again. </span></span>
                  <span id="chapter_one-sentence9"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.72.5">“Wait,” he said, but I was already up and out of the room.</span></span>
                </p>
              </body>
            </html>
            """
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    
    func testTagDots() throws {
        let xml = """
                <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                <head>
                </head>
                <body>
                <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.15.1">“What do you mean ‘it goes by Theuth,’ ” he said. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.15.2">“It doesn’t go by anything.…”</span></p>
                <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.16.1">“</span><i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.17.1">We</span></i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.1"> call it Theuth,” I said. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.2">“So that’s what it goes by. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.3">I’ll show you how to write that down. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.4">Or better, Theuth will.”</span></p>
                </body>
                </html>
        """
        let expected = """
             <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
             <head>
             </head>
             <body>
              <p class="indent">
               <span id="chapter_one-sentence0">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.15.1">
                 “What do you mean ‘it goes by Theuth,’ ” he said.
                </span>
               </span>
               <span id="chapter_one-sentence1">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.15.2">
                 “It doesn’t go by anything.…”
                </span>
               </span>
              </p>
              <p class="indent">
               <span id="chapter_one-sentence2">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.16.1">
                 “
                </span>
                <i>
                 <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.17.1">
                  We
                 </span>
                </i>
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.1">
                  call it Theuth,” I said.
                </span>
               </span>
               <span id="chapter_one-sentence3">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.2">
                 “So that’s what it goes by.
                </span>
               </span>
               <span id="chapter_one-sentence4">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.3">
                 I’ll show you how to write that down.
                </span>
               </span>
               <span id="chapter_one-sentence5">
                <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.18.4">
                 Or better, Theuth will.”
                </span>
               </span>
              </p>
             </body>
            </html>
            """
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    
    func testTagPunct() throws {
        
        let xml = """
         <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
         <head>
         </head>
         <body>
          <p class="indent"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.93.1">“There’s no other language that works like this,” Scile said. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.93.2">“ ‘The human voice can apprehend itself as the sounding of the soul itself.’ ”</span></p>
         </body>
         </html>
        """
        
        let expected = """
         <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
         <head>
         </head>
         <body>
         <p class="indent">
            <span id="chapter_one-sentence0">
              <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.93.1">
               “There’s no other language that works like this,” Scile said. 
              </span>
            </span>
            <span id="chapter_one-sentence1">
             <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.93.2">
                    “ ‘The human voice can apprehend itself as the sounding of the soul itself.’ ”
              </span>
            </span>
            </p>
        </body>
       </html> 
       """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        XCTAssertEqual(try normalize(xml: result), try normalize(xml: expected))
    }
    
    func testRetainStyleAndComments() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?><!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" lang="en-US" xml:lang="en-US">
                    <head>
                            <title>Latterday, 1, Embassytown</title>
                            <link href="../css/9780345524515_style.css" rel="stylesheet" type="text/css"/>

            <!-- kobo-style -->
            <script xmlns="http://www.w3.org/1999/xhtml" type="text/javascript" src="../../js/kobo.js"/>
            <style xmlns="http://www.w3.org/1999/xhtml" type="text/css" id="koboSpanStyle">.koboSpan { -webkit-text-combine: inherit; }</style>

            </head>
            <body lang="en-US" xml:lang="en-US">
                <h1 id="c01" class="chapter"><span id="page42"/><span id="page43"/><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.1.1">Latterday, 1</span></h1>
            </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        
        if !result.contains("<!-- kobo-style -->") {
            XCTFail()
        }
        if !result.contains(".koboSpan { -webkit-text-combine: inherit; }") {
            XCTFail()
        }
    }
    
    func testTagEm() throws {
        
        let xml = """
         <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
         <head>
         </head>
         <body>
           <p>Recall what I told you above. All beings in Flatland, animate or inanimate, no matter what their form, present <em>to our view</em> the same, or nearly the same, appearance, <abbr>viz.</abbr> that of a straight Line. How then can one be distinguished from another, where all appear the same?</p>
         </body>
         </html>
        """
        
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <head/>
              <body>
                <p>
                  <span id="chapter_one-sentence0">Recall what I told you above. </span>
                  <span id="chapter_one-sentence1">All beings in Flatland, animate or inanimate, no matter what their form, present <em>to our view</em> the same, or nearly the same, appearance, <abbr>viz.</abbr> that of a straight Line. </span>
                  <span id="chapter_one-sentence2">How then can one be distinguished from another, where all appear the same?</span>
                </p>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    func testTagVarEm() throws {
        
        let xml = """
            <p>Now in the case of (<var>1</var>) the Merchant, what shall I see? I shall see a straight line <var>DAE</var>, in which the middle point (<var>A</var>) will be very bright because it is nearest to me; but on either side the line will shade away <em>rapidly into dimness</em>, because the sides <var>AC</var> and <var>AB</var> <em>recede rapidly into the fog</em> and what appear to me as the Merchant’s <b>ext</b>remities, <abbr>viz.</abbr> <var>D</var> and <var>E</var>, will be <em>very dim indeed</em>.</p>
            """
        
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <p>
                  <span id="chapter_one-sentence0">Now in the case of (<var>1</var>) the Merchant, what shall I see? </span>
                  <span id="chapter_one-sentence1">I shall see a straight line <var>DAE</var>, in which the middle point (<var>A</var>) will be very bright because it is nearest to me; but on either side the line will shade away <em>rapidly into dimness</em>, because the sides <var>AC</var> and <var>AB</var> <em>recede rapidly into the fog</em> and what appear to me as the Merchant’s <b>ext</b>remities, <abbr>viz.</abbr></span>
                  <span id="chapter_one-sentence2"><var>D</var> and <var>E</var>, will be <em>very dim indeed</em>.</span>
                </p>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    func testTagInWordSpanBold() throws {
        let xml = """
            <div class="tx1"><b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.2.1">K</span></b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.3.1">asia took the pitcher of beer, only slightly watered because the four merchants at the large table were regular patrons, and headed back from the kitchen toward the common room.</span></div>
            """
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <div class="tx1">
                  <span id="chapter_one-sentence0"><b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.2.1">K</span></b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.3.1">asia took the pitcher of beer, only slightly watered because the four merchants at the large table were regular patrons, and headed back from the kitchen toward the common room.</span></span>
                </div>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    func testSpaceBetween3() throws {
        let xml = """
            <hgroup>
              <h2>
                <span epub:type="label">Part</span> 
                <span epub:type="ordinal z3998:roman">II</span>
              </h2>
              <p epub:type="title">Other Worlds</p>
            </hgroup>
        """
        
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <hgroup>
                  <h2>
                    <span id="chapter_one-sentence0"><span epub:type="label">Part</span> <span epub:type="ordinal z3998:roman">II</span></span>
                  </h2>
                  <p epub:type="title">
                    <span id="chapter_one-sentence1">Other Worlds</span>
                  </p>
                </hgroup>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    func testWhitespace4() throws {
        let xml = """
            <span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.2.4">They were paying him a peppercorn retainer and keeping his access accounts live, with a view to ultimately publishing </span><i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.3.1">Forked Tongues: The SocioPsychoLinguistics of the Ariekei</span></i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.1">.</span></p>
            """
        
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <span id="chapter_one-sentence0"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.2.4">They were paying him a peppercorn retainer and keeping his access accounts live, with a view to ultimately publishing </span> <i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.3.1">Forked Tongues: The SocioPsychoLinguistics of the Ariekei</span></i><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.1">.</span></span>
                <p/>
              </body>
            </html>
            """
        
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    func testWhitespace5() throws {
        let xml = """
            <div class="tx1"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.2.1">“</span><b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.3.1">J</span></b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.1">ad boil the bastard in his own fish sauce!” </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.2">Rasic snarled under his breath as he scrubbed at a stained pot. </span><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.3">“We might as well have joined the Sleepless Ones and gotten some holy credit for being up all fucking night!”</span></div>
            """
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <div class="tx1">
                  <span id="chapter_one-sentence0"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.2.1">“</span><b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.3.1">J</span></b><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.1">ad boil the bastard in his own fish sauce!” </span></span>
                  <span id="chapter_one-sentence1"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.2">Rasic snarled under his breath as he scrubbed at a stained pot. </span></span>
                  <span id="chapter_one-sentence2"><span xmlns="http://www.w3.org/1999/xhtml" class="koboSpan" id="kobo.4.3">“We might as well have joined the Sleepless Ones and gotten some holy credit for being up all fucking night!”</span></span>
                </div>
              </body>
            </html>
            """
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    
    func testMergeDup2() throws {
        let xml = """
            <div class="fmtx"><span id="kobo.85.1" class="calibre3">An unpleasantness was a cart rumbling through the street below one’s bedroom too early in the morning.</span><span id="kobo.85.2" class="calibre3"> It was water in one’s boots on winter roads, a chest cough on a cold day, a bitter wind finding a chink in walls; it was sour wine, stringy meat, a tedious sermon in chapel, a ceremony running long in summer heat.</span></div>
            <div class="fmtx"><span id="kobo.86.1" class="calibre3">Unpleasantness was not the plague and burying children, it was not Sarantine Fire, not the Day of the Dead, or the <i class="calibre7">zubir</i> of the Aldwood appearing out of fog with blood dripping from its horns, it was not .</span><span id="kobo.86.2" class="calibre3"> .</span><span id="kobo.86.3" class="calibre3"> .</span><span id="kobo.86.4" class="calibre3"> this.</span><span id="kobo.86.5" class="calibre3"> It was not this.</span></div>
            """
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <div class="fmtx">
                  <span id="chapter_one-sentence0"><span id="kobo.85.1" class="calibre3">An unpleasantness was a cart rumbling through the street below one’s bedroom too early in the morning.</span></span>
                  <span id="chapter_one-sentence1"><span id="kobo.85.2" class="calibre3">It was water in one’s boots on winter roads, a chest cough on a cold day, a bitter wind finding a chink in walls; it was sour wine, stringy meat, a tedious sermon in chapel, a ceremony running long in summer heat.</span></span>
                </div>
                <div class="fmtx">
                  <span id="kobo.86.1" class="calibre3"><span id="chapter_one-sentence2">Unpleasantness was not the plague and burying children, it was not Sarantine Fire, not the Day of the Dead, or the <i class="calibre7">zubir</i> of the Aldwood appearing out of fog with blood dripping from its horns, it was not . <span id="kobo.86.2" class="calibre3"> .</span> <span id="kobo.86.3" class="calibre3"> .</span> <span id="kobo.86.4" class="calibre3"> this.</span></span></span>
                  <span id="chapter_one-sentence3"><span id="kobo.86.5" class="calibre3">It was not this.</span></span>
                </div>
              </body>
            </html>
            """
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
    
    
    func testEmptySpan() throws {
        let xml = """
                <p class="TX">He spread his hands. &#x201C;I told you, Marty. The status quo is rot<span role="doc-pagebreak" epub:type="pagebreak" id="pg_139" aria-label=" Page 139. "/>ten, but it&#x2019;s our kind of rotten. We don&#x2019;t want you to die&#x2014;our job is to protect you. But we&#x2019;re also protecting all the other people who will be collateral damage if you <i>don&#x2019;t</i> die. We have substantial resources&#x2014;the civil asset forfeiture program means that any time we run short on funds, we just seize one of the many bank accounts we&#x2019;re keeping tabs on. We can afford this, and it solves everyone&#x2019;s problems.&#x201D;</p>
            """
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <html>
              <head/>
              <body>
                <p class="TX">
                  <span id="chapter_one-sentence0">He spread his hands. </span>
                  <span id="chapter_one-sentence1">“I told you, Marty. </span>
                  <span id="chapter_one-sentence2">The status quo is rot<span role="doc-pagebreak" epub:type="pagebreak" id="pg_139" aria-label=" Page 139. "/>ten, but it’s our kind of rotten. </span>
                  <span id="chapter_one-sentence3">We don’t want you to die—our job is to protect you. </span>
                  <span id="chapter_one-sentence4">But we’re also protecting all the other people who will be collateral damage if you <i>don’t</i> die. </span>
                  <span id="chapter_one-sentence5">We have substantial resources—the civil asset forfeiture program means that any time we run short on funds, we just seize one of the many bank accounts we’re keeping tabs on. </span>
                  <span id="chapter_one-sentence6">We can afford this, and it solves everyone’s problems.”</span>
                </p>
              </body>
            </html>
            """
        let sentences = try XHTMLTagger().getXHtmlSentences(from: xml)
        let doc: Document = try SwiftSoup.parse(xml)
        let result = try xmlTagger.tag(sentences: sentences, in: doc, chapterId: "chapter_one")
        XCTAssert(result == expected)
    }
}


