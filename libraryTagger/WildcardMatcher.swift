//
//  WildcardMatcher.swift
//  libraryTagger
//

import Foundation

struct WildcardMatcher {
    /// Returns true if `text` matches `pattern`.
    /// - If pattern is empty, matches everything.
    /// - If pattern contains no `*`, performs case-insensitive substring match.
    /// - If pattern contains `*`, each `*` matches zero or more characters (anchored full match).
    static func matches(text: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return true }

        // No wildcard: plain case-insensitive substring match
        guard pattern.contains("*") else {
            return text.localizedCaseInsensitiveContains(pattern)
        }

        // Wildcard mode: convert to anchored regex
        // 1. Escape all regex-special characters
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        // 2. The escaping turned our `*` into `\*` — replace those back with `.*`
        let regexPattern = "^" + escaped.replacingOccurrences(of: "\\*", with: ".*") + "$"

        return text.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
