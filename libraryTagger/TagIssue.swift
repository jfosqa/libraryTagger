//
//  TagIssue.swift
//  libraryTagger
//

import Foundation
import SwiftUI
import MusicKit

/// Each case represents one kind of tag quality problem detected in a song title.
enum TagIssue: String, CaseIterable, Identifiable {
    case artistNameInTitle   = "Artist in Title"
    case albumNameInTitle    = "Album in Title"
    case underscoresAsSpaces = "Underscores"
    case squareBracketContent = "Square Brackets"
    case suspiciousParentheses = "Suspicious Parens"
    case fileExtension       = "File Extension"
    case dashSeparator       = "Dash Separator"
    case leadingTrackNumber  = "Track Number"
    case featuringArtist     = "Featuring Artist"
    case sceneRelease        = "Scene Release"

    var id: String { rawValue }
}

/// The result of scanning a single song — pairs a song's metadata with its detected issues.
struct ScanResult: Identifiable, Hashable {
    let id: MusicItemID
    let title: String
    let artistName: String
    let albumTitle: String?
    let issues: [TagIssue]
}

extension TagIssue {
    var color: Color {
        switch self {
        case .artistNameInTitle, .albumNameInTitle:
            return .orange
        case .underscoresAsSpaces, .dashSeparator, .leadingTrackNumber, .fileExtension:
            return .red
        case .squareBracketContent, .suspiciousParentheses, .featuringArtist, .sceneRelease:
            return .purple
        }
    }
}
