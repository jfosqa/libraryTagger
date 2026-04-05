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

        // 0. Scene release naming: "01-artist_name-track_title-group"
        //    Hyphens separate fields, underscores separate words within fields.
        //    Must run BEFORE underscore replacement or track number stripping.
        if issues.contains(.sceneRelease) {
            // Strip leading track number
            let stripped = cleaned.replacingOccurrences(
                of: #"^\d{1,3}-"#, with: "", options: .regularExpression
            )
            var segments = stripped.components(separatedBy: "-")

            // Drop the last segment (release group tag)
            if segments.count >= 3 {
                segments.removeLast()
            }

            // First segment is artist, rest is the title
            if segments.count >= 2 {
                parsedArtist = segments[0].replacingOccurrences(of: "_", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                cleaned = segments.dropFirst().joined(separator: "-")
                    .replacingOccurrences(of: "_", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            } else if let only = segments.first {
                cleaned = only.replacingOccurrences(of: "_", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            }

            // Scene release handling replaces underscore and dash processing,
            // so skip directly to the remaining cleanup steps below.
        } else {
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

        // Strip bare "Feat."/"Ft."/"featuring" and everything after it
        if issues.contains(.featuringArtist) {
            cleaned = cleaned.replacingOccurrences(
                of: #"\s*(feat\.?|ft\.?|featuring)\b.*$"#,
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

        // Strip featuring text from parsed artist (e.g., "Chase & Status Ft.Kano" → "Chase & Status")
        if let art = parsedArtist {
            parsedArtist = art.replacingOccurrences(
                of: #"\s*(feat\.?|ft\.?|featuring)\b.*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Collapse multiple spaces and trim
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#, with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return (query: cleaned, parsedArtist: parsedArtist)
    }
}
