//
//  TitleCleaner.swift
//  libraryTagger
//

import Foundation

struct TitleCleaner {

    /// Strip known noise from a title to produce a cleaner Discogs search query.
    /// Uses the detected issues to apply only relevant cleanups.
    /// Returns the cleaned query and an optionally parsed artist (from "Artist - Title" patterns).
    static func cleanForSearch(title: String, artist: String, issues: [TagIssue]) -> (query: String, parsedArtist: String?) {
        var cleaned = title
        var parsedArtist: String? = nil

        // 1. Replace underscores with spaces first (affects all subsequent parsing)
        if issues.contains(.underscoresAsSpaces) {
            cleaned = cleaned.replacingOccurrences(of: "_", with: " ")
        }

        // 2. Remove leading track numbers BEFORE parsing dash separators
        //    so "01 - Cypress Hill - Pigs" becomes "Cypress Hill - Pigs"
        if issues.contains(.leadingTrackNumber) {
            cleaned = cleaned.replacingOccurrences(
                of: #"^\d{1,3}[\.\s\-]+"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)
        }

        // 2b. Strip leading vinyl side indicators like (A), (B), (AA), (B1), etc.
        cleaned = cleaned.replacingOccurrences(
            of: #"^\([A-Z]{1,2}\d?\)\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // 3. Handle "Artist - Title" dash separator pattern
        //    Now that track numbers are stripped, the first segment is the artist
        if issues.contains(.dashSeparator) {
            let normalized = cleaned.replacingOccurrences(of: " - ", with: " - ")
            let parts = normalized.components(separatedBy: " - ")
            if parts.count >= 2 {
                parsedArtist = parts[0].trimmingCharacters(in: .whitespaces)
                cleaned = parts.dropFirst().joined(separator: " - ")
            }
        }

        // Remove square bracket content
        if issues.contains(.squareBracketContent) {
            cleaned = cleaned.replacingOccurrences(
                of: #"\[.*?\]"#, with: "",
                options: .regularExpression
            )
        }

        // Remove suspicious parenthetical content
        if issues.contains(.suspiciousParentheses) {
            let pattern = #"\((feat\.?|ft\.?|official|hq|hd|remix|bootleg|free|download|original mix|vip|clip|video)[^)]*\)"#
            cleaned = cleaned.replacingOccurrences(
                of: pattern, with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Strip file extensions
        if issues.contains(.fileExtension) {
            cleaned = cleaned.replacingOccurrences(
                of: #"\.(mp3|flac|wav|aac|ogg|m4a|aiff|wma)"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Remove embedded artist name to avoid redundancy in search
        if issues.contains(.artistNameInTitle) {
            cleaned = cleaned.replacingOccurrences(
                of: artist, with: "",
                options: .caseInsensitive
            )
        }

        // Collapse multiple spaces and trim
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#, with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return (query: cleaned, parsedArtist: parsedArtist)
    }
}
