//
//  SongDetailViewModel.swift
//  libraryTagger
//

import Foundation
import MusicKit

struct SiblingCorrection: Identifiable {
    let scanResult: ScanResult
    let matchedTrack: DiscogsTrack?
    let correction: TrackCorrection?
    var isIncluded: Bool

    var id: MusicItemID { scanResult.id }
}

@Observable
class SongDetailViewModel {
    let scanResult: ScanResult
    let allScanResults: [ScanResult]

    // State
    var isSearching = false
    var searchResults: [DiscogsSearchResult] = []
    var selectedRelease: DiscogsRelease? = nil
    var matchedTrack: DiscogsTrack? = nil
    var errorMessage: String? = nil
    var isLoadingRelease = false
    var didSwapArtistAndTitle = false

    // Sibling album tracks
    var siblingCorrections: [SiblingCorrection] = []

    // Cleaned query info (computed once and cached)
    private(set) var cleanedTitle: String = ""
    private(set) var parsedArtist: String? = nil

    init(scanResult: ScanResult, allScanResults: [ScanResult] = []) {
        self.scanResult = scanResult
        self.allScanResults = allScanResults

        let result = TitleCleaner.cleanForSearch(
            title: scanResult.title,
            artist: scanResult.artistName,
            issues: scanResult.issues
        )
        self.cleanedTitle = result.query
        self.parsedArtist = result.parsedArtist
    }

    // MARK: - Search

    @MainActor
    func search() async {
        guard !isSearching else { return }
        isSearching = true
        errorMessage = nil
        searchResults = []
        selectedRelease = nil
        matchedTrack = nil
        didSwapArtistAndTitle = false

        let artist = parsedArtist ?? scanResult.artistName

        do {
            // Try the normal order: cleanedTitle as query, parsed/known artist
            let response = try await DiscogsService.shared.searchTrack(
                query: cleanedTitle,
                artist: artist
            )

            if !response.results.isEmpty {
                searchResults = response.results
                print("[Search] Found \(response.results.count) results for query: \"\(cleanedTitle)\" artist: \"\(artist)\"")
            } else if parsedArtist != nil {
                // No results — try swapping artist and title in case the
                // original was in "Title - Artist" order instead of "Artist - Title"
                let swappedResponse = try await DiscogsService.shared.searchTrack(
                    query: artist,
                    artist: cleanedTitle
                )
                if !swappedResponse.results.isEmpty {
                    searchResults = swappedResponse.results
                    didSwapArtistAndTitle = true
                    // Update the cleaned values to reflect the swap
                    let formerTitle = cleanedTitle
                    cleanedTitle = artist
                    parsedArtist = formerTitle
                }
            }

            // Retry with "&" / "and" normalization in both directions
            if searchResults.isEmpty {
                // Try "and" → "&"
                let ampQuery = cleanedTitle.replacingOccurrences(
                    of: #"\band\b"#, with: "&", options: [.regularExpression, .caseInsensitive]
                )
                let ampArtist = artist.replacingOccurrences(
                    of: #"\band\b"#, with: "&", options: [.regularExpression, .caseInsensitive]
                )
                if ampQuery != cleanedTitle || ampArtist != artist {
                    print("[Search] Retrying with and→& normalization: \"\(ampQuery)\" by \"\(ampArtist)\"")
                    let ampResponse = try await DiscogsService.shared.searchTrack(
                        query: ampQuery, artist: ampArtist
                    )
                    if !ampResponse.results.isEmpty {
                        searchResults = ampResponse.results
                        print("[Search] and→& search found \(ampResponse.results.count) results")
                    }
                }

                // Try "&" → "and"
                if searchResults.isEmpty {
                    let andQuery = cleanedTitle.replacingOccurrences(of: "&", with: "and")
                    let andArtist = artist.replacingOccurrences(of: "&", with: "and")
                    if andQuery != cleanedTitle || andArtist != artist {
                        print("[Search] Retrying with &→and normalization: \"\(andQuery)\" by \"\(andArtist)\"")
                        let andResponse = try await DiscogsService.shared.searchTrack(
                            query: andQuery, artist: andArtist
                        )
                        if !andResponse.results.isEmpty {
                            searchResults = andResponse.results
                            print("[Search] &→and search found \(andResponse.results.count) results")
                        }
                    }
                }
            }

            // Fallback: search track title without artist constraint
            // (scene releases often have a track-level artist that doesn't match
            //  the release-level artist on Discogs)
            if searchResults.isEmpty, parsedArtist != nil {
                print("[Search] Retrying without artist constraint: \"\(cleanedTitle)\"")
                let noArtistResponse = try await DiscogsService.shared.searchTrack(
                    query: "\(cleanedTitle) \(artist)"
                )
                if !noArtistResponse.results.isEmpty {
                    searchResults = noArtistResponse.results
                    print("[Search] No-artist search found \(noArtistResponse.results.count) results")
                }
            }

            // Fallback: search by album title + artist when track search fails
            if searchResults.isEmpty, let album = scanResult.albumTitle, !album.isEmpty {
                print("[Search] Track search returned no results, falling back to album search: \"\(album)\" by \"\(artist)\"")
                let albumResponse = try await DiscogsService.shared.searchTrack(
                    query: album,
                    artist: artist
                )
                if !albumResponse.results.isEmpty {
                    searchResults = albumResponse.results
                    print("[Search] Album fallback found \(albumResponse.results.count) results")
                } else {
                    print("[Search] Album fallback also returned no results")
                }
            }
        } catch let error as DiscogsError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    // MARK: - Release Selection

    @MainActor
    func selectRelease(_ result: DiscogsSearchResult) async {
        isLoadingRelease = true
        errorMessage = nil

        do {
            let release = try await DiscogsService.shared.getRelease(id: result.id)
            selectedRelease = release
            matchedTrack = findMatchingTrack(in: release, cleanedTitle: self.cleanedTitle)
            matchSiblings()
        } catch let error as DiscogsError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRelease = false
    }

    // MARK: - Manual Track Selection

    /// Manually select a track from the release tracklist.
    @MainActor
    func selectTrack(_ track: DiscogsTrack) {
        matchedTrack = track
        // Reset apply state since correction changed
        didApplySuccessfully = false
        applyError = nil
        matchSiblings()
    }

    // MARK: - Track Matching

    func findMatchingTrack(in release: DiscogsRelease, cleanedTitle: String) -> DiscogsTrack? {
        let target = cleanedTitle.lowercased()

        // Exact match first
        if let exact = release.tracklist.first(where: {
            $0.title.lowercased() == target
        }) {
            return exact
        }

        // Contains match
        if let contains = release.tracklist.first(where: {
            $0.title.localizedCaseInsensitiveContains(target) ||
            target.localizedCaseInsensitiveContains($0.title.lowercased())
        }) {
            return contains
        }

        // Normalized match: strip punctuation, normalize "&"/"and"
        let normalizedTarget = Self.normalizeForMatching(target)
        if let normalized = release.tracklist.first(where: {
            Self.normalizeForMatching($0.title.lowercased()) == normalizedTarget
        }) {
            return normalized
        }

        return nil
    }

    /// Normalize a string for fuzzy matching by stripping punctuation and
    /// standardizing common substitutions.
    static func normalizeForMatching(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: #"[,\.'\-]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Suggested Corrections

    var suggestedTitle: String? {
        matchedTrack?.title
    }

    var suggestedArtist: String? {
        // Prefer track-level artist (for split/compilation releases)
        // over release-level artist
        let raw = matchedTrack?.artistName
            ?? selectedRelease?.artistsSort
            ?? selectedRelease?.artists.first?.name
        // Clean Discogs disambiguation suffixes like " (2)"
        return raw?.replacingOccurrences(
            of: #"\s*\(\d+\)$"#, with: "",
            options: .regularExpression
        )
    }

    var suggestedAlbum: String? {
        selectedRelease?.title
    }

    // MARK: - Correction Building

    /// Build a TrackCorrection for a scan result against matched track and release.
    /// Only includes fields that actually differ.
    func buildCorrection(
        for scan: ScanResult,
        matchedTrack: DiscogsTrack?,
        release: DiscogsRelease
    ) -> TrackCorrection? {
        let newTitle: String? = if let title = matchedTrack?.title,
            title.localizedCaseInsensitiveCompare(scan.title) != .orderedSame {
            title
        } else {
            nil
        }

        // Prefer track-level artist (for split/compilation releases)
        // over release-level artist
        let rawArtist = matchedTrack?.artistName
            ?? release.artistsSort
            ?? release.artists.first?.name
        let cleanArtist = rawArtist?.replacingOccurrences(
            of: #"\s*\(\d+\)$"#, with: "", options: .regularExpression
        )
        let newArtist = cleanArtist.flatMap {
            $0.localizedCaseInsensitiveCompare(scan.artistName) != .orderedSame ? $0 : nil
        }

        let newAlbum: String? = {
            let current = scan.albumTitle ?? ""
            return release.title.localizedCaseInsensitiveCompare(current) != .orderedSame ? release.title : nil
        }()

        guard newTitle != nil || newArtist != nil || newAlbum != nil else { return nil }
        return TrackCorrection(title: newTitle, artist: newArtist, album: newAlbum)
    }

    // MARK: - Apply Corrections

    var isApplying = false
    var applyError: String? = nil
    var didApplySuccessfully = false

    /// Pending correction for the primary track (from Discogs release).
    var pendingCorrection: TrackCorrection? {
        guard let release = selectedRelease else { return nil }
        return buildCorrection(for: scanResult, matchedTrack: matchedTrack, release: release)
    }

    /// Correction built from the cleaned/parsed data without needing a Discogs match.
    var cleanedCorrection: TrackCorrection? {
        let newTitle: String? = cleanedTitle.localizedCaseInsensitiveCompare(scanResult.title) != .orderedSame
            ? cleanedTitle : nil
        let newArtist: String? = parsedArtist.flatMap {
            $0.localizedCaseInsensitiveCompare(scanResult.artistName) != .orderedSame ? $0 : nil
        }
        guard newTitle != nil || newArtist != nil else { return nil }
        return TrackCorrection(title: newTitle, artist: newArtist, album: nil)
    }

    @MainActor
    func applyCleaned() {
        guard let correction = cleanedCorrection else {
            applyError = "No corrections to apply."
            return
        }

        isApplying = true
        applyError = nil

        do {
            let count = try MusicAppService.applyCorrections(
                currentTitle: scanResult.title,
                currentArtist: scanResult.artistName,
                correction: correction
            )
            didApplySuccessfully = true
            print("Applied \(count) cleaned correction(s) to \"\(scanResult.title)\"")
        } catch {
            applyError = error.localizedDescription
        }

        isApplying = false
    }

    @MainActor
    func applyCorrections() {
        guard let correction = pendingCorrection else {
            applyError = "No corrections to apply."
            return
        }

        isApplying = true
        applyError = nil

        do {
            let count = try MusicAppService.applyCorrections(
                currentTitle: scanResult.title,
                currentArtist: scanResult.artistName,
                correction: correction
            )
            didApplySuccessfully = true
            print("Applied \(count) correction(s) to \"\(scanResult.title)\"")
        } catch {
            applyError = error.localizedDescription
        }

        isApplying = false
    }

    // MARK: - Sibling Album Tracks

    private func matchSiblings() {
        guard let release = selectedRelease else {
            siblingCorrections = []
            return
        }

        let currentAlbum = scanResult.albumTitle ?? ""
        guard !currentAlbum.isEmpty else {
            print("[Siblings] No album title on primary track, skipping sibling match")
            siblingCorrections = []
            return
        }

        print("[Siblings] Looking for siblings of album: \"\(currentAlbum)\" in \(allScanResults.count) scan results")

        let siblings = allScanResults.filter { other in
            other.id != scanResult.id &&
            other.albumTitle != nil &&
            other.albumTitle!.localizedCaseInsensitiveCompare(currentAlbum) == .orderedSame
        }

        print("[Siblings] Found \(siblings.count) sibling(s) from same album")

        siblingCorrections = siblings.map { sibling in
            let cleaned = TitleCleaner.cleanForSearch(
                title: sibling.title,
                artist: sibling.artistName,
                issues: sibling.issues
            )
            let matched = findMatchingTrack(in: release, cleanedTitle: cleaned.query)
            let correction = buildCorrection(for: sibling, matchedTrack: matched, release: release)
            print("[Siblings]   \"\(sibling.title)\" → cleaned: \"\(cleaned.query)\" → match: \(matched?.title ?? "nil")")

            return SiblingCorrection(
                scanResult: sibling,
                matchedTrack: matched,
                correction: correction,
                isIncluded: matched != nil
            )
        }
    }

    @MainActor
    func applyAllCorrections() -> Set<MusicItemID> {
        var correctedIDs = Set<MusicItemID>()
        isApplying = true
        applyError = nil

        // Apply primary track correction
        if let correction = pendingCorrection {
            do {
                _ = try MusicAppService.applyCorrections(
                    currentTitle: scanResult.title,
                    currentArtist: scanResult.artistName,
                    correction: correction
                )
                correctedIDs.insert(scanResult.id)
            } catch {
                applyError = "Primary track: \(error.localizedDescription)"
            }
        }

        // Apply sibling corrections
        for i in siblingCorrections.indices where siblingCorrections[i].isIncluded {
            guard let correction = siblingCorrections[i].correction else { continue }
            let sibling = siblingCorrections[i].scanResult
            do {
                _ = try MusicAppService.applyCorrections(
                    currentTitle: sibling.title,
                    currentArtist: sibling.artistName,
                    correction: correction
                )
                correctedIDs.insert(sibling.id)
            } catch {
                print("Failed to correct \"\(sibling.title)\": \(error.localizedDescription)")
            }
        }

        didApplySuccessfully = !correctedIDs.isEmpty
        isApplying = false
        return correctedIDs
    }
}
