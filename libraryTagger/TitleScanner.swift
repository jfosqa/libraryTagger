//
//  TitleScanner.swift
//  libraryTagger
//

import Foundation
import MusicKit

struct TitleScanner {

    /// Analyze a single song and return any detected issues.
    static func scan(_ song: Song) -> [TagIssue] {
        var issues: [TagIssue] = []
        let title = song.title

        // 1. Artist name embedded in title (min 3 chars to avoid false positives)
        // Skip if the title IS the artist name (self-titled tracks)
        if song.artistName.count >= 3,
           title.localizedCaseInsensitiveContains(song.artistName),
           title.localizedCaseInsensitiveCompare(song.artistName) != .orderedSame {
            issues.append(.artistNameInTitle)
        }

        // 2. Album name embedded in title (min 3 chars)
        // Skip if the title IS the album name (title tracks like "...And Justice for All")
        if let album = song.albumTitle, album.count >= 3,
           title.localizedCaseInsensitiveContains(album),
           title.localizedCaseInsensitiveCompare(album) != .orderedSame {
            issues.append(.albumNameInTitle)
        }

        // 3. Underscores used as word separators
        if title.contains("_") {
            issues.append(.underscoresAsSpaces)
        }

        // 4. Content in square brackets (e.g., [Flight Recordings])
        if title.range(of: #"\[.*?\]"#, options: .regularExpression) != nil {
            issues.append(.squareBracketContent)
        }

        // 5. Suspicious parenthetical content
        let suspiciousParenPattern = #"\((feat\.?|ft\.?|official|hq|hd|remix|bootleg|free|download|original mix|vip|clip|video)\b"#
        if title.range(of: suspiciousParenPattern,
                       options: [.regularExpression, .caseInsensitive]) != nil {
            issues.append(.suspiciousParentheses)
        }

        // 6. Bare "Feat."/"Ft."/"featuring" not inside parentheses
        let featuringPattern = #"(?<!\()\b(feat\.?|ft\.?|featuring)\b"#
        if title.range(of: featuringPattern,
                       options: [.regularExpression, .caseInsensitive]) != nil {
            issues.append(.featuringArtist)
        }

        // 7. File extensions in the title
        let extensionPattern = #"\.(mp3|flac|wav|aac|ogg|m4a|aiff|wma)\b"#
        if title.range(of: extensionPattern,
                       options: [.regularExpression, .caseInsensitive]) != nil {
            issues.append(.fileExtension)
        }

        // 8. Dash separator patterns suggesting concatenated fields (" - " or "_-_")
        if title.range(of: #"(\s-\s|_-_)"#, options: .regularExpression) != nil {
            issues.append(.dashSeparator)
        }

        // 9. Leading track number (e.g., "01 -", "01.", "03 ")
        if title.range(of: #"^\d{1,3}[\.\s\-]"#, options: .regularExpression) != nil {
            issues.append(.leadingTrackNumber)
        }

        // 10. Scene release naming: "NN-artist-title[-group]" format.
        //     Bare hyphens as field separators with either underscores or single words.
        //     Detected when: starts with NN- (digit-hyphen, no space) and has 2+ segments.
        //     (2 segments = artist-title, 3+ = artist-title-group)
        if title.range(of: #"^\d{1,3}-[^\s]"#, options: .regularExpression) != nil {
            let stripped = title.replacingOccurrences(
                of: #"^\d{1,3}-"#, with: "", options: .regularExpression
            )
            let segments = stripped.components(separatedBy: "-")
            if segments.count >= 2 {
                issues.append(.sceneRelease)
            }
        }

        return issues
    }

    /// Scan an array of songs, returning only those with at least one issue.
    static func scanAll(_ songs: [Song]) -> [ScanResult] {
        songs.compactMap { song in
            let issues = scan(song)
            guard !issues.isEmpty else { return nil }
            return ScanResult(
                id: song.id,
                title: song.title,
                artistName: song.artistName,
                albumTitle: song.albumTitle,
                issues: issues
            )
        }
    }
}
