//
//  EpubTocEntry.swift
//  StoryAlign
//
//  Created by Rich Waters on 10/17/25.
//

import Foundation

public struct EpubDocument : Codable, Sendable {
    let opfPath: String
    let opfXmlData: Data
    let metaInfo: EpubMetaInfo
    let unzippedURL: URL
    let guide:[EpubGuideItem]
    let manifest: [EpubManifestItem]
    let spine:EpubSpine
    var nav:EpubNav? = nil
    
    public var opfURL: URL {
        return unzippedURL.appendingPathComponent(opfPath)
    }

    init(opfPath:String, opfXmlData: Data, metaInfo: EpubMetaInfo, unzippedURL: URL, guide: [EpubGuideItem], manifest: [EpubManifestItem], spine: EpubSpine, nav:EpubNav?) throws {
        self.opfPath = opfPath
        self.opfXmlData = opfXmlData
        self.metaInfo = metaInfo
        self.unzippedURL = unzippedURL
        self.guide = guide
        self.manifest = manifest
        self.spine = spine
        self.nav = nav
    }
}

extension EpubDocument {
    var fullText:String {
        let textItems:[String] = self.spine.items.compactMap { spineItem in
            guard let item = self.manifest.first( where: { $0.id == spineItem.idref } ) else {
                return nil
            }
            return item.text
        }
        return textItems.joined(separator: "\n")
    }
}

struct EpubManifestItem : Codable {
    let id: String
    let href: String
    let mediaType: String?
    let properties: [String]?
    var spineItemIndex:Int = -1
    var text:String?
    var xmlData:Data?
    var hasScript:Bool?
    var xhtmlSentences:[String] = []
    var name:String?    
    var filePath:URL?
    
    var startTxt:String {
        String(self.text?.prefix(128) ?? "")
    }
    var endTxt:String {
        String(self.text?.suffix(128) ?? "")
    }
    
    var xmlText:String {
        guard let xmlData else {
            return ""
        }
        return String(data:xmlData, encoding:.utf8) ?? ""
    }
    
    var nameOrId : String {
        name ?? id
    }
}

struct EpubGuideItem : Codable {
    let type: String
    let title: String?
    let href: String
}

struct EpubSpine : Codable {
    let toc:String
    let items:[EpubSpineItem]
    
    func contains( manifestItemId:String ) -> Bool {
        return items.first { $0.idref == manifestItemId } != nil
    }
}
struct EpubSpineItem : Codable {
    let idref:String
    let id:String?
    let index:Int
}

struct EpubTocEntry:Codable {
    var href:String
    var title:String
}

struct EpubNav : Codable {
    var href:String = ""
    var bodymatterHrefs:[String] = []
    var backmatterHrefs:[String] = []
    var hasScript = false

    var toc:[EpubTocEntry] = []
    
    var tocDict:[String:String] {
        toc.reduce(into: [:]) { result, entry in
            result[entry.href] = entry.title
        }
    }
}

struct EpubMetaInfo : Codable {
    var title: String?
    var creator: String?
    var language: String?
    var identifier: String?
    var date:String?
    var publisher:String?
    var subject:String?
}

struct EpubContainer {
    var opfPath: String = ""
}
