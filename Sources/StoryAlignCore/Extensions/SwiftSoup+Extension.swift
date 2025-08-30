//
//  SwiftSoup+Extension.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2009-2025 Jonathan Hedley <https://jsoup.org/>
// Swift port copyright (c) 2016-2025 Nabil Chatbi
// Extension Copyright (c) 2025 Rich Waters
//
//

import SwiftSoup

fileprivate let s_skipSet:Set<Character> = ["(", "[", "{",
                                            "\"",  // straight double
                                            "'",   // straight single
                                            "“",   // left double curly
                                            "”",   // right double curly
                                            "‘",   // left single curly
                                            "’",   // right single curly
                                            "—"    // em-dash
]

fileprivate let s_skipTags:Set<String> = HTMLTags.inline.filter { $0 != "span" }


extension Node {
    private var inlineTags: Set<String> {
        HTMLTags.inline
    }
    private var blockTags:Set<String> {
        HTMLTags.blocks
    }
    
    func xmlFormatted(indentLevel: Int = 0) throws -> String {

        if let dt = self as? DocumentType {
            return try dt.outerHtml()
        }

        // 1) Strip off the SwiftSoup “#root” wrapper, but add our XML prolog
        if let el = self as? Element, el.tagName() == "#root" {
            let header = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            let doctypeDecls = try el.getChildNodes().compactMap { node in
                node is DocumentType
                    ? try node.xmlFormatted(indentLevel: 0)
                    : nil
            }.joined(separator: "\n")

            let body = try el
                .getChildNodes()
                .filter { !($0 is DocumentType) }
                .map { try $0.xmlFormatted(indentLevel: indentLevel) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            return [header, doctypeDecls, body]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        
        let indent = String(repeating: "  ", count: indentLevel)
        
        if let cmt = self as? Comment {
            let cmtHtml = try cmt.outerHtml()
            if cmtHtml.trimmed().starts(with: "<!--?xml") {
                return ""
            }
            return indent + cmtHtml
        }
        
        if let dataNode = self as? DataNode {
            let raw = dataNode.getWholeData()
            let normalized = try Entities.unescape(raw)
            let escaped = normalized.escapingXMLEntities()
            if escaped.trimmed().isEmpty {
                return ""
            }
            return indent + escaped
        }
        
        if let text = self as? TextNode {
            //let t = text.getWholeText()
            //if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
            //return indent + t
            
            let raw = text.getWholeText()
            let normalized = try Entities.unescape(raw)
            let escaped = normalized.escapingXMLEntities()
            guard !escaped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
            return indent + escaped
        }
        guard let el = self as? Element else {
            return ""
        }
        let name = el.tagName()
        let lower = name.lowercased()

        //let attrs = (el.getAttributes()?.asList() ?? [])
        //    .map { "\($0.getKey())=\"\($0.getValue())\"" }
        //    .joined(separator: " ")

        /*
        let attrs = try (el.getAttributes()?.asList() ?? []).map {
            let raw = $0.getValue()
            let normalized = try Entities.unescape(raw)
            let escaped = normalized.escapingXMLEntities()
            return "\($0.getKey())=\"\(escaped)\""
        }.joined(separator: " ")
         */
        let attrs = try el.attributesAsNormalizedString()
        
        let openTag = attrs.isEmpty
            ? "<\(name)>"
            : "<\(name) \(attrs)>"
        let closeTag = "</\(name)>"
        
        let meaningfulChildren = el.getChildNodes().filter {
          if let tn = $0 as? TextNode {
            return !tn.getWholeText()
                      .trimmingCharacters(in: .whitespacesAndNewlines)
                      .isEmpty
          }
          return true
        }
        if meaningfulChildren.isEmpty {
          let slash = attrs.isEmpty ? "/>" : "/>"
          return indent + "<\(name)\(attrs.isEmpty ? "" : " \(attrs)")\(slash)"
        }

        let children = el.getChildNodes()
        let isBlock = blockTags.contains(lower)
        let hasInlineOnly = children.allSatisfy {
            if let el = $0 as? Element {
                return inlineTags.contains(el.tagName().lowercased())
            }
            if let tn = $0 as? TextNode {
                return !tn.getWholeText()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            }
            return false
        }
        /*
        if inlineTags.contains(lower) || (!isBlock && hasInlineOnly) {
            var body = ""
            for c in children {
                body += try c.xmlFormatted(indentLevel: 0)
            }
            return indent + openTag + body + closeTag
        }
         */
        if inlineTags.contains(lower) || (!isBlock && hasInlineOnly) {
            var body = ""
            var sawText = false
            var skipLeadingSpaceNext = false

            try children.pairs().forEach { (prev, c) in
                if let tn = c as? TextNode {
                    let raw = tn.getWholeText()
                    let normalized = try Entities.unescape(raw)
                    let escaped = normalized.escapingXMLEntities()
                    if skipLeadingSpaceNext && !body.isEmpty && body.last!.isWhitespace {
                        body += String(escaped.drop { $0.isWhitespace })
                    } else {
                        body += escaped
                    }
                    skipLeadingSpaceNext = false
                    sawText = true
                    return
                }
                if let elc = c as? Element {
                    if sawText && !body.isEmpty {
                        if !body.last!.isWhitespace && !s_skipSet.contains(body.last!) {
                            let tag = prev?.nodeName() ?? ""
                            if !s_skipTags.contains(tag) {
                                body += " "
                            }
                        }
                    }
                    body += try elc.xmlFormatted(indentLevel: 0)
                    //sawText = false
                    sawText = true
                }
            }
            return indent + openTag + body + closeTag
        }

        var out = indent + openTag + "\n"
        for c in children {
            let line = try c.xmlFormatted(indentLevel: indentLevel+1)
            if !line.isEmpty {
                out += line + "\n"
            }
        }
        out += indent + closeTag
        return out
    }
}

extension Element {
    func attributesAsNormalizedString() throws -> String {
        let mediaOverlay = try attr("media-overlay")
        let attributes = (getAttributes()?.asList() ?? [])
        let shouldSort =  (parent()?.tagName() == "manifest" && !mediaOverlay.isEmpty)
        let sortedAttributes = shouldSort ? try sortAttributes(attributes) : attributes
        let attrString = try sortedAttributes.map {
            let raw = $0.getValue()
            let normalized = try Entities.unescape(raw)
            let escaped = normalized.escapingXMLEntities()
            return "\($0.getKey())=\"\(escaped)\""
        }.joined(separator: " ")
        return attrString
    }
    
    // This is just to get things closer to the order that StoryTeller-Platform uses when it emits xhtml. It's unnecessary, but it makes for cleaner diffs
    //
    func sortAttributes(_ attributes:[Attribute]) throws -> [Attribute] {
        let origAttrKeysOrder = attributes.map { $0.getKey() }
        let attributesOrder = ["id", "href", "media-type", "media-overlay"]
        
        let compIndex = { (index0:Int?,index1:Int?) -> Bool? in
            if index0 != nil && index1 != nil {
                return index0! < index1!
            }
            if index0 != nil && index1 == nil {
                return true
            }
            if index0 == nil && index1 != nil {
                return false
            }
            return nil
        }

        let sortedAttributes = attributes.sorted( by: {
            let index0 = attributesOrder.firstIndex(of: $0.getKey())
            let index1 = attributesOrder.firstIndex(of: $1.getKey())
            if let comp = compIndex(index0,index1) {
                return comp
            }
            
            let origIndex0 = origAttrKeysOrder.firstIndex(of: $0.getKey())
            let origIndex1 = origAttrKeysOrder.firstIndex(of: $1.getKey())
            if let origComp = compIndex(origIndex0,origIndex1) {
                return origComp
            }
            return $0.getKey() < $1.getKey()
        })
        
        return sortedAttributes
    }
}
