//
// EpubParser.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//

import Foundation
import ZIPFoundation
import NaturalLanguage



public struct EpubParser : SessionConfigurable {
    public var sessionConfig: SessionConfig

    public init(sessionConfig:SessionConfig) {
        self.sessionConfig = sessionConfig
    }
    
    public func parse(url epubURL: URL ) async throws -> EpubDocument {
        let fileManager = FileManager.default
        let tempDir = sessionConfig.sessionDir.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: epubURL, to: tempDir)
        
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        let containerData = try Data(contentsOf: containerPath)
        let container = try parseContainer(from: containerData)
        
        let opfFullURL = tempDir.appendingPathComponent(container.opfPath)
        let opfData = try Data(contentsOf: opfFullURL)
        let metadata = try parseMetaInfo(from: opfData)
        let spine = try parseSpine(from: opfData)
        
        let manifestItems = try parseManifest(from: opfData)
        
        
        let nav:EpubNav? = try? {
            let navHref = manifestItems.filter { $0.properties?.contains("nav") == true }.first?.href
            guard let navHref else {
                return nil
            }
            let baseUrl = opfFullURL.deletingLastPathComponent()
            let navUrl = baseUrl.appendingPathComponent(navHref)
            var nav = try parseNav( from:navUrl )
            nav?.href = navHref
            return nav

        }() ?? nil
    
        let tocDict = nav?.tocDict ?? [:]
        
        let spindItemsByIdRef = spine.items.reduce(into: [String:EpubSpineItem]()) { result, item in
            result[item.idref] = item
        }

        let manifest = try manifestItems.enumerated().map { (index,itemArg) in
            var item = itemArg
            let navDir = URL(filePath: nav?.href ?? "").deletingLastPathComponent().path()

            let itemName = {
                if let name = tocDict[item.href] {
                    return name
                }
                let hrefUrl = URL(filePath: item.href)
                if hrefUrl.deletingLastPathComponent().path() == navDir {
                    if let name = tocDict[hrefUrl.lastPathComponent] {
                        return name
                    }
                }
                return item.id
            }()
            item.name = String(itemName.prefix(32))

            guard let url = URL( string:item.href, relativeTo: opfFullURL.deletingLastPathComponent() ) else {
                throw StoryAlignError("Cannot find manifest item content" )
            }
            defer {
                sessionConfig.progressUpdater?.updateProgress(for: .epub, msgPrefix: "Processing '\(item.nameOrId)'", increment: 1, total: manifestItems.count, unit:.none)
            }
            item.filePath = url
            if !spine.contains(manifestItemId: item.id) {
                logger.log( .info, "Ignoring manifest item \(item.id)")
                return item
            }

            logger.log(.info, "Parsing manifest item \(item.id)")
            let xmlData = try Data(contentsOf: url)
            item.xmlData = xmlData
            (item.text, item.hasScript) = try parseText(from:xmlData )
            item.xhtmlSentences = try XHTMLTagger(sessionConfig: sessionConfig).getXHtmlSentences(from: item.xmlText)

            guard let spineItem = spindItemsByIdRef[item.id] else {
                throw StoryAlignError("Cannot find spine item for \(item.id)")
            }
            item.spineItemIndex = spineItem.index
            return item
        }

        
        let guide = try parseGuide(from: opfData)
        
        return try EpubDocument(opfPath: container.opfPath, opfXmlData: opfData, metaInfo: metadata, unzippedURL: tempDir, guide: guide, manifest: manifest, spine: spine, nav:nav)
    }
}


////////////////////////////////////////
// MARK: Container Parser
//
fileprivate extension EpubParser {
    func parseContainer( from containerData: Data ) throws -> EpubContainer {
        let parser = XMLParser(data: containerData)
        let containerDelegate = ContainerXMLParserDelegate()
        parser.delegate = containerDelegate
        guard parser.parse() else {
            throw StoryAlignError( "Failed to parse container" )
        }
        if containerDelegate.container.opfPath.isEmpty {
            throw StoryAlignError( "Missing opfPath in container" )
        }
        return containerDelegate.container
    }
    
    
    class ContainerXMLParserDelegate: NSObject, XMLParserDelegate {
        var container:EpubContainer = EpubContainer()
        
        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            if elementName == "rootfile", let fullPath = attributeDict["full-path"] {
                container.opfPath = fullPath
            }
        }
    }
}


////////////////////////////////////////
// MARK: Meta Info Parser
//
fileprivate extension EpubParser {
    func parseMetaInfo(from opfData:Data) throws -> EpubMetaInfo {
        let parser = XMLParser(data: opfData)
        let delegate = OPFMetaInfoParserDelegate()
            parser.delegate = delegate
        guard parser.parse() else {
            if let err = delegate.error {
                throw err
            }
            throw NSError(domain: "MetaInfoParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse meta info."])
        }
        return delegate.metaInfo
    }
        
    class OPFMetaInfoParserDelegate: NSObject, XMLParserDelegate {
        var metaInfo:EpubMetaInfo = EpubMetaInfo()
        var error: Error? = nil
        
        private var currentElement = ""
        private var foundCharacters = ""
        
        
        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            foundCharacters = ""
            
            if elementName.lowercased() == "package" {
                if attributeDict["version"] == "2.0" {
                    error = StoryAlignError( "This looks like an epub 2.0 file. Only 3.0 is supported currently." )
                    parser.abortParsing()
                    return
                }
            }
            if elementName == "dc:contributor" {
                if let id = attributeDict["id"] {
                    if id.starts(with: "storyalign-contributor") {
                        error = StoryAlignError( "It looks as those this epub has already been aligned by storyalign. Please use a different epub file." )
                        parser.abortParsing()
                        return
                    }
                }
            }
            if elementName == "meta" {
                if let property = attributeDict["property"] {
                    if property.starts(with: "storyteller") {
                        error = StoryAlignError( "It looks as those this epub has already been aligned by storyteller-platform. Please use a different epub file." )
                        parser.abortParsing()
                    }
                }
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            foundCharacters += string
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            let trimmed = foundCharacters.trimmed()
            switch elementName {
                case "dc:identifier":
                    metaInfo.identifier = trimmed
                case "dc:title":
                    metaInfo.title = trimmed
                case "dc:creator":
                    metaInfo.creator = trimmed
                case "dc:language":
                    metaInfo.language = trimmed
                case "dc:publisher":
                    metaInfo.publisher = trimmed
                case "dc:date":
                    metaInfo.date = trimmed
                case "dc:subject":
                    metaInfo.subject = trimmed
                default:
                    break
            }
        }
    }
}

////////////////////////////////////////
// MARK: Manifest Parser
//
fileprivate extension EpubParser {
    func parseManifest(from opfData: Data) throws -> [EpubManifestItem] {
        let parser = XMLParser(data: opfData)
        let delegate = ManifestParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw NSError(domain: "ManifestParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse manifest."])
        }
        return delegate.manifestItems
    }
    
    
    class ManifestParserDelegate: NSObject, XMLParserDelegate {
        var manifestItems = [EpubManifestItem]()
        private var inManifest = false
        
        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            
            if elementName == "manifest" {
                inManifest = true
                return
            }
            
            if inManifest && elementName == "item" {
                if let id = attributeDict["id"], let href = attributeDict["href"] {
                    let mediaType = attributeDict["media-type"]
                    let props = attributeDict["properties"]?.split(separator: " ").map { String($0) }
                    manifestItems.append(EpubManifestItem(id: id, href: href, mediaType: mediaType, properties: props))
                }
            }
        }
        
        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "manifest" {
                inManifest = false
            }
        }
    }
}

////////////////////////////////////////
// MARK: Guide Parser
//
fileprivate extension EpubParser {
    func parseGuide(from opfData: Data) throws -> [EpubGuideItem] {
        let parser = XMLParser(data: opfData)
        let delegate = GuideParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw NSError(domain: "GuideParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse guide."])
        }
        return delegate.guideItems
    }
    
    class GuideParserDelegate: NSObject, XMLParserDelegate {
        var guideItems = [EpubGuideItem]()
        private var inGuide = false
        
        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {

            if elementName == "guide" {
                inGuide = true
                return
            }
            if inGuide && elementName == "reference" {
                if let type = attributeDict["type"], let href = attributeDict["href"] {
                    let title = attributeDict["title"]
                    guideItems.append(EpubGuideItem(type: type, title: title, href: href))
                }
            }
        }
        
        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "guide" {
                inGuide = false
            }
        }
    }
}



////////////////////////////////////////
// MARK: Spine Parser
//
fileprivate extension EpubParser {
    func parseSpine(from opfData: Data) throws -> EpubSpine {
        let parser = XMLParser(data: opfData)
        let delegate = SpineParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw NSError(domain: "Spine Parsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse spine."])
        }
        let spine = EpubSpine(toc: delegate.toc, items: delegate.spineItems )
        return spine
    }
    
    
    class SpineParserDelegate: NSObject, XMLParserDelegate {
        var toc:String = ""
        var spineItems:[EpubSpineItem] = []
        var index:Int = 0
        private var inSpine = false
        
        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            
            if elementName == "spine" {
                inSpine = true
                return
            }
            
            if inSpine && elementName == "itemref" {
                let id = attributeDict["id"]
                guard let idref = attributeDict["idref"] else {
                    return
                }
                let spineItem = EpubSpineItem(idref: idref, id: id, index: index)
                index += 1
                spineItems.append(spineItem)
            }
        }
        
        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "spine" {
                inSpine = false
            }
        }
    }
}





extension EpubParser {
    func parseText(from xmlData:Data) throws -> (String,Bool) {
        let parser = XMLParser(data: xmlData)
        let delegate = XmlTextParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw StoryAlignError( "Parsing text from xml failed" )
        }
        return (delegate.extractedText, delegate.hasScript )
    }
    
    
    class XmlTextParserDelegate: NSObject, XMLParserDelegate {
        var text = String()
        var hasScript:Bool = false
        private var inBody = false
        
        var extractedText = ""
          
        let blockElements: Set<String> = ["p", "br", "div", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol"]
          
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inBody {
                extractedText += string
            }
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName == "script" {
                hasScript = true
            }
            if elementName == "body" {
                inBody = true
            }
        }
          
        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if blockElements.contains(elementName.lowercased()),
               !extractedText.hasSuffix("\n") {
                extractedText.append("\n")
            }
            if elementName == "body" {
                inBody = false
            }
        }
    }
}


////////////////////////////////////////
// MARK: Nav Parser
//
fileprivate extension EpubParser {
    func parseNav(from navUrl:URL) throws -> EpubNav? {
        let navData = try Data(contentsOf: navUrl)
        let parser = XMLParser(data: navData)
        let delegate = NavParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            throw StoryAlignError( "Failed to parse nav." )
        }
        return delegate.nav
    }
    
    class NavParserDelegate: NSObject, XMLParserDelegate {
        var nav = EpubNav()
        private var inLandmarks = false
        private var inToc = false
        private var tocEntries: [EpubTocEntry] = []
        private var foundCharacters = ""
        private var curHref = ""
        
        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {


            if elementName == "nav" && !inLandmarks && !inToc {
                guard let epubtype = attributeDict["epub:type"] else {
                    return
                }
                if epubtype == "landmarks" {
                    inLandmarks = true
                    return
                }
                if epubtype == "toc" {
                    inToc = true
                    return
                }
            }
            if elementName == "a" {
                foundCharacters = ""
                curHref = ""
                
                guard let href = attributeDict["href"] else {
                    return
                }
                
                if inLandmarks {
                    guard let epubtype = attributeDict["epub:type"] else {
                        return
                    }

                    let epubtypeWords = epubtype.split(separator: " ").filter { !$0.isEmpty }
                    if epubtypeWords.first == "bodymatter" {
                        nav.bodymatterHrefs.append( href )
                    }
                    if epubtypeWords.first == "backmatter"  {
                        nav.backmatterHrefs.append(href)
                    }
                    return
                }
                if inToc {
                    curHref = href
                }
            }
            if elementName == "script" {
                nav.hasScript = true
            }
        }
        
        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "nav" {
                inLandmarks = false
                inToc = false
            }
            if elementName == "a" {
                if curHref.isEmpty {
                    return
                }
                if foundCharacters.trimmed().isEmpty {
                    return
                }
                let tocEntry = EpubTocEntry(href: curHref, title: foundCharacters)
                tocEntries.append(tocEntry)
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            foundCharacters += string
        }
        
        func parserDidEndDocument(_ parser: XMLParser) {
            nav.toc.append(contentsOf: tocEntries)
        }
    }
}
