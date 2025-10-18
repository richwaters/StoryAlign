//
//  MediaOverlay.swift
//  StoryAlign
//
//  Created by Rich Waters on 10/17/25.
//


import Foundation

struct MediaOverlay {
    let baseURL: URL
    let manifestItem: EpubManifestItem
    let sentenceRanges: [SentenceRange]

    var itemId: String {
        manifestItem.id + "_overlay"
    }

    var href: String {
        let basename = manifestItem.filePath!.deletingPathExtension().lastPathComponent
        return "MediaOverlays/\(basename).smil"
    }

    var filePath: URL {
        baseURL.appendingPathComponent(href)
    }

    var audioFiles: [AudioFile] {
        Array(Set(sentenceRanges.map(\.audioFile))).sorted { $0.filePath.path() < $1.filePath.path() }
    }

    var overlayXml: String {
        var xml = """
        <smil xmlns=\"http://www.w3.org/ns/SMIL\" xmlns:epub=\"http://www.idpf.org/2007/ops\" version=\"3.0\">
          <body>
            <seq id=\"\(itemId)\" epub:textref=\"../\(manifestItem.href)\" epub:type=\"chapter\">
        """

        for sr in sentenceRanges {
            let sid = "\(manifestItem.id)-sentence\(sr.id)"
            let clipBegin = String(format: "%.3fs", sr.start)
            let clipEnd = String(format: "%.3fs", sr.end)

            xml += """
              <par id=\"\(sid)\">
                <text src=\"../\(manifestItem.href)#\(sid)\"/>
                <audio src=\"../Audio/\(sr.audioFile.filePath.lastPathComponent)\" clipBegin=\"\(clipBegin)\" clipEnd=\"\(clipEnd)\"/>
              </par>
            """
        }

        xml += """
            </seq>
          </body>
        </smil>
        """
        return xml
    }
}
