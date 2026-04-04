//
//  MusicAppService.swift
//  libraryTagger
//

import Foundation

enum MusicAppError: LocalizedError {
    case scriptError(String)
    case trackNotFound
    case noCorrectionsToApply

    var errorDescription: String? {
        switch self {
        case .scriptError(let detail):
            return "AppleScript error: \(detail)"
        case .trackNotFound:
            return "Track not found in Music app. It may be streaming-only or not downloaded."
        case .noCorrectionsToApply:
            return "No corrections to apply."
        }
    }
}

struct TrackCorrection {
    let title: String?
    let artist: String?
    let album: String?
}

struct MusicAppService {

    /// Apply corrections to a track in the Music app, identified by its current title and artist.
    /// Returns the number of fields actually changed.
    @MainActor
    static func applyCorrections(
        currentTitle: String,
        currentArtist: String,
        correction: TrackCorrection
    ) throws -> Int {
        var setStatements: [String] = []

        if let newTitle = correction.title {
            setStatements.append("set name of matchedTrack to \(appleScriptString(newTitle))")
        }
        if let newArtist = correction.artist {
            setStatements.append("set artist of matchedTrack to \(appleScriptString(newArtist))")
        }
        if let newAlbum = correction.album {
            setStatements.append("set album of matchedTrack to \(appleScriptString(newAlbum))")
        }

        guard !setStatements.isEmpty else {
            throw MusicAppError.noCorrectionsToApply
        }

        let script = """
        tell application "Music"
            set matchedTracks to (every track of library playlist 1 \
        whose name is \(appleScriptString(currentTitle)) \
        and artist is \(appleScriptString(currentArtist)))
            if (count of matchedTracks) is 0 then
                error "Track not found"
            end if
            set matchedTrack to item 1 of matchedTracks
            \(setStatements.joined(separator: "\n            "))
        end tell
        """

        try executeAppleScript(script)
        return setStatements.count
    }

    // MARK: - Private Helpers

    private static func executeAppleScript(_ source: String) throws {
        let script = NSAppleScript(source: source)
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)

        if let errorDict = errorDict {
            let message = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            if message.contains("Track not found") {
                throw MusicAppError.trackNotFound
            }
            throw MusicAppError.scriptError(message)
        }
    }

    /// Escape a string for safe inclusion in AppleScript as a quoted literal.
    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
