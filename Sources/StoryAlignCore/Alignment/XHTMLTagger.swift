//
// XHTMLTagger.swift
//
// SPDX-License-Identifier: MIT
//
// Original source Copyright (c) 2023 Shane Friedman
// Translated and modified Copyright (c) 2025 Rich Waters
//


import SwiftSoup
import NaturalLanguage


struct XHTMLTagger {
    static let dataSpaceAfterAttrName = "data-storyalign-space-after"
    
    let blocks = HTMLTags.blocks
    
    private func lastLeafElement(in el: Element) -> Element {
        var cur = el
        while let last = cur.getChildNodes().last as? Element, !last.getChildNodes().isEmpty {
            cur = last
        }
        return cur
    }
    
    private func markSpaceAfter(in parent: Element) throws {
        let nodes = parent.getChildNodes()
        guard !nodes.isEmpty else { return }
        if let el = nodes.last as? Element {
            try lastLeafElement(in: el).attr(Self.dataSpaceAfterAttrName, "1")
            return
        }
        if nodes.count >= 2, let prevEl = nodes[nodes.count - 2] as? Element {
            try lastLeafElement(in: prevEl).attr(Self.dataSpaceAfterAttrName, "1")
            return
        }
        try parent.attr("data-space-after", "1")
    }
     

    func isXmlTextNode(_ node: Node) -> Bool {
        node is TextNode
    }

    func getXmlElementName(_ node: Node) -> String {
        (node as! Element).tagName()
    }

    func getXmlChildren(_ elem: Element) -> Element {
        elem
    }

    func appendTextNode(
        chapterId: String,
        xml: Element,
        text: String,
        marks: [Mark],
        taggedSentences: inout Set<Int>,
        sentenceId: Int? = nil
    ) throws {
        guard !text.isEmpty else { return }
        let textNode = TextNode(text, "")
        try appendLeafNode(
            chapterId: chapterId,
            xml: xml,
            node: textNode,
            marks: marks,
            taggedSentences: &taggedSentences,
            sentenceId: sentenceId
        )
    }

    func appendLeafNode(
        chapterId: String,
        xml: Element,
        node: Node,
        marks: [Mark],
        taggedSentences: inout Set<Int>,
        sentenceId: Int? = nil
    ) throws {
        // Detect any true leaf element (no children) and clone it
        let isLeafElement: Bool = {
            if let el = node as? Element {
                return el.getChildNodes().isEmpty
            }
            return false
        }()
        
        let nodeToAppend: Node = try  {
            guard isLeafElement, let el = node as? Element else {
                return node
            }
            let orphan = Element(Tag(el.tagName()), "")
            for attr in (el.getAttributes() ?? Attributes()).asList() {
                try orphan.attr(attr.getKey(), attr.getValue())
            }
            return el.copy(clone: orphan)
        }()
        
        // Skip pure-whitespace for everything except those cloned leaf elements
        if !isLeafElement {
            if let tn = nodeToAppend as? TextNode {
                if tn.getWholeText().trimmed().isEmpty {
                    if !tn.getWholeText().isEmpty {
                        try markSpaceAfter(in: xml)
                    }
                    return
                }
            } else if let el = nodeToAppend as? Element {
                if try el.text().trimmed().isEmpty { return }
            }
        }
        
        // Wrap in any accumulated inline marks
        var marked: Node = nodeToAppend
        for mark in marks.reversed() {
            let wrapper = Element(Tag(mark.elementName), "")
            for attr in mark.attributes.asList() {
                try wrapper.attr(attr.getKey(), attr.getValue())
            }
            try wrapper.appendChild(marked)
            marked = wrapper
        }
        
        // Now either nest into an existing sentence <span> or start a new one
        let tagId = "\(chapterId)-sentence\(sentenceId.map(String.init) ?? "")"
        if let last = xml.getChildNodes().last,
           !isXmlTextNode(last),
           let lastElem = last as? Element,
           try lastElem.attr("id") == tagId
        {
            try lastElem.appendChild(marked)
        }
        else if sentenceId == nil || taggedSentences.contains(sentenceId!) {
            try xml.appendChild(marked)
        }
        else {
            let span = Element(Tag("span"), "")
            try span.attr("id", tagId)
            try span.appendChild(marked)
            taggedSentences.insert(sentenceId!)
            try xml.appendChild(span)
        }
    }


    @discardableResult
    func tagSentencesInXml(
        chapterId: String,
        currentSentenceIndex: Int,
        currentSentenceProgress: Int,
        sentences: [String],
        currentNode: Node,
        currentNodeProgress: Int,
        taggedSentences: inout Set<Int>,
        marks: [Mark],
        taggedXml: Element
    ) throws -> TagState {
        
        if isXmlTextNode(currentNode), let textNode = currentNode as? TextNode {
            let sentence = sentences[currentSentenceIndex]
            let remStart = sentence.index(sentence.startIndex, offsetBy: currentSentenceProgress)
            let remainingSentence = String(sentence[remStart...])
            let fullText = textNode.text()

            let nodeStart = fullText.index(fullText.startIndex, offsetBy: currentNodeProgress)
            let remainingNodeText = String(fullText[nodeStart...])

            let range:Range<String.Index>? = {
                guard let firstChar = remainingSentence.first else {
                    return nil
                }
                let range = remainingNodeText.range(of: String(firstChar))
                return range
            }()
            guard let range else {
                try appendTextNode(
                    chapterId: chapterId,
                    xml: taggedXml,
                    text: remainingNodeText,
                    marks: marks,
                    taggedSentences: &taggedSentences
                )
                return TagState(currentSentenceIndex: currentSentenceIndex,
                                currentSentenceProgress: currentSentenceProgress,
                                currentNodeProgress: -1)
            }
            let idx = remainingNodeText.distance(from: remainingNodeText.startIndex, to: range.lowerBound)
            let charsLeft = remainingNodeText.count - idx

            if charsLeft < remainingSentence.count {
                try appendTextNode(
                    chapterId: chapterId,
                    xml: taggedXml,
                    text: String(remainingNodeText.prefix(idx)),
                    marks: marks,
                    taggedSentences: &taggedSentences
                )
                try appendTextNode(
                    chapterId: chapterId,
                    xml: taggedXml,
                    text: String(remainingNodeText.suffix(charsLeft)),
                    marks: marks,
                    taggedSentences: &taggedSentences,
                    sentenceId: currentSentenceIndex
                )
                return TagState(currentSentenceIndex: currentSentenceIndex,
                                currentSentenceProgress: currentSentenceProgress + charsLeft,
                                currentNodeProgress: -1)
            } else {
                try appendTextNode(
                    chapterId: chapterId,
                    xml: taggedXml,
                    text: String(remainingNodeText.prefix(idx)),
                    marks: marks,
                    taggedSentences: &taggedSentences
                )
                try appendTextNode(
                    chapterId: chapterId,
                    xml: taggedXml,
                    text: remainingSentence,
                    marks: marks,
                    taggedSentences: &taggedSentences,
                    sentenceId: currentSentenceIndex
                )
                if currentSentenceIndex + 1 == sentences.count {
                    let trailIdx = idx + remainingSentence.count
                    let trailStart = remainingNodeText.index(remainingNodeText.startIndex, offsetBy: trailIdx)
                    let trailing = String(remainingNodeText[trailStart...])
                    try appendTextNode(
                        chapterId: chapterId,
                        xml: taggedXml,
                        text: trailing,
                        marks: marks,
                        taggedSentences: &taggedSentences
                    )
                }
                let newPos = currentNodeProgress + idx + remainingSentence.count
                return TagState(currentSentenceIndex: currentSentenceIndex + 1,
                                currentSentenceProgress: 0,
                                currentNodeProgress: newPos)
            }
        }

        
        guard let elem = currentNode as? Element else {
            return TagState(currentSentenceIndex: currentSentenceIndex,
                            currentSentenceProgress: currentSentenceProgress,
                            currentNodeProgress: -1)
        }
        var state = TagState(currentSentenceIndex: currentSentenceIndex,
                             currentSentenceProgress: currentSentenceProgress,
                             currentNodeProgress: currentNodeProgress)

        for child in elem.getChildNodes() {
            if state.currentSentenceIndex > sentences.count - 1 {
                // orphan-copy branch once we're past all sentences

                // drop pure-whitespace
                if let tn = child as? TextNode {
                    if tn.getWholeText().trimmed().isEmpty {
                        if !tn.getWholeText().isEmpty {
                            try markSpaceAfter(in: taggedXml)
                        }
                        continue
                    }
                }

                let orphan: Node
                if let childElem = child as? Element {
                    orphan = Element(Tag(childElem.tagName()), "")
                } else if let text = child as? TextNode {
                    orphan = TextNode(text.text(), "")
                } else {
                    orphan = child
                }
                let childCopy = child.copy(clone: orphan)
                try taggedXml.appendChild(childCopy)
                continue
            }
            state.currentNodeProgress = 0
            let nextTaggedXml = taggedXml
            let nextMarks = marks

            if !isXmlTextNode(child), let childElem = child as? Element {
                let name           = childElem.tagName()
                let lower          = name.lowercased()
                let isBlock        = blocks.contains(lower)

                if childElem.getChildNodes().isEmpty {
                    let hasText = ((try? !childElem.text().trimmed().isEmpty) == true)
                    let sentenceId = (isBlock || state.currentSentenceProgress == 0 || (!hasText && taggedSentences.isEmpty)) ? nil : state.currentSentenceIndex
                    try appendLeafNode(
                        chapterId: chapterId,
                        xml: taggedXml,
                        node: childElem,
                        marks: marks,
                        taggedSentences: &taggedSentences,
                        sentenceId: sentenceId
                    )
                    continue
                }

                if isBlock {
                    let wrapper = Element(Tag(name), "")
                    for attr in (childElem.getAttributes() ?? Attributes()).asList() {
                        try wrapper.attr(attr.getKey(), attr.getValue())
                    }

                    // apply any accumulated inline marks to the wrapper
                    var nodeToInsert: Node = wrapper
                    for mark in marks.reversed() {
                        let markEl = Element(Tag(mark.elementName), "")
                        for attr in mark.attributes.asList() {
                            try markEl.attr(attr.getKey(), attr.getValue())
                        }
                        try markEl.appendChild(nodeToInsert)
                        nodeToInsert = markEl
                    }

                    try taggedXml.appendChild(nodeToInsert)

                    // marks are “consumed” now that we’ve wrapped them
                    state = try tagSentencesInXml(
                        chapterId: chapterId,
                        currentSentenceIndex: state.currentSentenceIndex,
                        currentSentenceProgress: state.currentSentenceProgress,
                        sentences: sentences,
                        currentNode: childElem,
                        currentNodeProgress: 0,
                        taggedSentences: &taggedSentences,
                        marks: [],              // safe to drop—already applied
                        taggedXml: wrapper
                    )
                }
                else {
                    // INLINE: accumulate as marks, keep same parent
                    let attrs = childElem.getAttributes() ?? Attributes()
                    let inlineMark = Mark(elementName: name, attributes: attrs)
                    state = try tagSentencesInXml(
                        chapterId: chapterId,
                        currentSentenceIndex: state.currentSentenceIndex,
                        currentSentenceProgress: state.currentSentenceProgress,
                        sentences: sentences,
                        currentNode: childElem,
                        currentNodeProgress: 0,
                        taggedSentences: &taggedSentences,
                        marks: marks + [inlineMark],
                        taggedXml: taggedXml
                    )
                }
                continue
            }

            while state.currentSentenceIndex < sentences.count && state.currentNodeProgress != -1 {
                state = try tagSentencesInXml(
                    chapterId: chapterId,
                    currentSentenceIndex: state.currentSentenceIndex,
                    currentSentenceProgress: state.currentSentenceProgress,
                    sentences: sentences,
                    currentNode: child,
                    currentNodeProgress: state.currentNodeProgress,
                    taggedSentences: &taggedSentences,
                    marks: nextMarks,
                    taggedXml: nextTaggedXml
                )
            }
        }

        state.currentNodeProgress = -1
        return state
    }
}

extension XHTMLTagger {
    
    func tag( sentences:[String], in doc:Document, chapterId: String ) throws -> String {
        guard let body = try doc.select("body").first() else {
            throw StoryAlignError("no <body> found")
        }

        //  make a deep-clone of <body> (with all its children)
        //  by passing in an empty <body> orphan as the “clone” target
        //
        guard let bodyClone = body.copy(clone: Element(Tag("body"), "")) as? Element else {
          throw StoryAlignError("couldn't clone <body>")
        }

        // clear out the real body so it can be repopulated
        body.empty()
        
        
        var taggedSentences = Set<Int>()
        try tagSentencesInXml(
            chapterId: chapterId,
            currentSentenceIndex: 0,
            currentSentenceProgress: 0,
            sentences: sentences,
            currentNode: bodyClone,
            currentNodeProgress: 0,
            taggedSentences: &taggedSentences,
            marks: [],
            taggedXml: body
        )

        try mergeDupSpans(in: doc)
        return try prepareXhtmlOutput(from: doc)
    }
    
    func tag( epub:EpubDocument, manifestItem:EpubManifestItem, chapterId: String) async throws -> String {
        let xhtml = manifestItem.xmlText
        let doc = try SwiftSoup.parse(xhtml)
     
        guard let head = doc.head() else {
            throw StoryAlignError("no <head> found")
        }
        
        let rootUrl = epub.opfURL.deletingLastPathComponent()
        let manifestUrl = manifestItem.filePath?.deletingLastPathComponent() ?? rootUrl
        let relUrlStr = rootUrl.relative(to: manifestUrl )
        let styleCss = "\(AssetPaths.styles)/storyalign.css"
        let stylePath = relUrlStr.isEmpty ? styleCss : "\(relUrlStr)/\(styleCss)"
        
        try head.appendElement("link")
            .attr("rel", "stylesheet")
            .attr("href", stylePath)
            .attr("type", "text/css")
        
        let retStr = try tag(sentences:manifestItem.xhtmlSentences,  in: doc, chapterId:chapterId)
        return retStr
    }
}

struct TagState {
    var currentSentenceIndex: Int
    var currentSentenceProgress: Int
    var currentNodeProgress: Int
}

struct Mark {
    let elementName: String
    let attributes: Attributes
}



extension XHTMLTagger {
    func getXHtmlSentences(from element: Element) throws -> [String] {
        var sentences = [String]()
        var stagedText = ""
        
        for node in element.getChildNodes() {
            if let textNode = node as? TextNode {
                stagedText += textNode.text()
            } else if let childElem = node as? Element {
                let tagName = childElem.tagName()
                
                if !blocks.contains(tagName) {
                    stagedText += try getXhtmlTextContent(from:[childElem])
                } else {
                    sentences += NLTokenizer.tokenizeSentences(text:stagedText).map { $0 }
                    stagedText = ""
                    sentences += try getXHtmlSentences(from: childElem)
                }
            }
        }
        
        sentences += NLTokenizer.tokenizeSentences(text:stagedText).map { $0 }
        return sentences
    }
    
    func isMergeableSentence(_ text:String ) -> Bool {
        if text.isAllWhiteSpaceOrPunct {
            return true
        }
        return false
    }

    
    func getXHtmlSentences( from xmlText:String ) throws -> [String] {
        let doc = try SwiftSoup.parse(xmlText)
        guard let body = try doc.select("body").first() else {
            throw StoryAlignError("no <body> found")
        }
        let sentences = try getXHtmlSentences(from: body)
        var mergedSentences:[String] = []
        var i = 0
        while i < sentences.count {
            let sentence = sentences[i]
            if i < sentences.count-1 {
                let nextSentence = sentences[i+1]
                if isMergeableSentence(nextSentence) {
                    let nuSentence = sentence + nextSentence
                    mergedSentences.append(nuSentence)
                    i += 2
                    continue
                }
            }
            mergedSentences.append(sentence)
            i += 1
        }
        
        return mergedSentences
    }
    
    func getXhtmlTextContent(from nodes: [Node]) throws -> String {
        var text = ""
        for node in nodes {
            if let tn = node as? TextNode {
                text += tn.text()
                //text += tn.getWholeText()
            } else if let el = node as? Element {
                text += try getXhtmlTextContent(from: el.getChildNodes())
            }
        }
        return text
    }
}

extension XHTMLTagger {
    func mergeDupSpans(in doc: Document) throws {
        let allSpans = try doc.select("span[id]").array()
        var seen = Set<String>()

        // group spans by their id
        var spansById = [String: [Element]]()
        for span in allSpans {
             let id = try span.attr("id")
             spansById[id, default: []].append(span)
        }
        
        for (id, group) in spansById where group.count > 1 {
            guard !seen.contains(id) else { continue }
            seen.insert(id)

            let merged = Element(Tag("span"), "")
            for attr in (group[0].getAttributes() ?? Attributes()).asList() {
                try merged.attr(attr.getKey(), attr.getValue())
            }
            
            // figure out their enclosing sentence-spans
            let sentenceSpans = group.compactMap { $0.parent() }
            guard let firstSentence = sentenceSpans.first else { continue }
            
            try firstSentence.before(merged)
            
            for chapSpan in sentenceSpans {
                // lift out its inner text/nodes from the little
                if let innerSpan = try chapSpan.select("span[id=\(id)]").first() {
                    let children = innerSpan.getChildNodes()
                    for child in children {
                        try innerSpan.before(child)
                    }
                    try innerSpan.remove()
                }
                try merged.appendChild(chapSpan)
            }
        }
    }
}

extension XHTMLTagger {
    func prepareXhtmlOutput( from doc:Document ) throws -> String {
        doc.outputSettings()
            .syntax(syntax:.xml)

        let html = try doc.xmlFormatted()
        return html
    }
}


