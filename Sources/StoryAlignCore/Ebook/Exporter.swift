//
// Exporter.swift
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Rich Waters
//


import Foundation
import ZIPFoundation

public struct EpubExporter : SessionConfigurable {
    public init(sessionConfig: SessionConfig) {
        self.sessionConfig = sessionConfig
    }
    public let sessionConfig:SessionConfig
    
    public func export (eBook:EpubDocument, to outputFile:URL) throws {
        logger.log(.info, "Exporting to: \(outputFile)" )
        
        let totalBytes = Int( try FileManager.default.du( eBook.unzippedURL ))
        
        let archive = try Archive(url: outputFile, accessMode: .create)
        let folderURL = eBook.unzippedURL.standardizedFileURL
        logger.log(.debug, "folderURL \(folderURL)")
        try archive.addEntry(with: "mimetype", relativeTo: folderURL, compressionMethod: .none)

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: resourceKeys)!
        try enumerator.compactMap { ($0 as? URL)?.standardizedFileURL }.forEach { fileURL in
            let resourceVals = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey] )

            defer {
                sessionConfig.progressUpdater?.updateProgress(for: .export, msgPrefix: "Exporting", increment: resourceVals.fileSize ?? 0, total: totalBytes, unit:.bytes)
            }
            
            logger.log(.debug, "Processing \(fileURL)")
            let isDir = resourceVals.isDirectory ?? false
            let entryName = fileURL.path.replacingOccurrences(of: folderURL.path + "/", with: "")
            if entryName == "mimetype" {
                return
            }
            if isDir {
                return
            }
            logger.log( .info, "Adding \(entryName)")
            try archive.addEntry(with: entryName, relativeTo: folderURL, compressionMethod: .deflate)
        }
        
        logger.log(.info, "Export complete" )
    }
}
