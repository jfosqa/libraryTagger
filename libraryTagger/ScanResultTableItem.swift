//
//  ScanResultTableItem.swift
//  libraryTagger
//

import Foundation
import MusicKit

/// A table-friendly wrapper around ScanResult with concrete, sortable properties.
struct ScanResultTableItem: Identifiable, Hashable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let albumTitle: String
    let issues: [TagIssue]
    let isCorrected: Bool
    let scanResult: ScanResult

    var alertCount: Int { issues.count }
    var correctionSortValue: Int { isCorrected ? 1 : 0 }

    init(scanResult: ScanResult, isCorrected: Bool) {
        self.id = scanResult.id
        self.title = scanResult.title
        self.artistName = scanResult.artistName
        self.albumTitle = scanResult.albumTitle ?? ""
        self.issues = scanResult.issues
        self.isCorrected = isCorrected
        self.scanResult = scanResult
    }
}
