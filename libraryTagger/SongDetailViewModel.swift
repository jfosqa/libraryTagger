//
//  SongDetailViewModel.swift
//  libraryTagger
//

import Foundation

@Observable
class SongDetailViewModel {
    let scanResult: ScanResult

    // State
    var isSearching = false
    var searchResults: [DiscogsSearchResult] = []
    var selectedRelease: DiscogsRelease? = nil
    var matchedTrack: DiscogsTrack? = nil
    var errorMessage: String? = nil
    var isLoadingRelease = false
    var didSwapArtistAndTitle = false

    // Cleaned query info (computed once and cached)
    private(set) var cleanedTitle: String = ""
    private(set) var parsedArtist: String? = nil

    init(scanResult: ScanResult) {
        self.scanResult = scanResult

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
            matchedTrack = findMatchingTrack(in: release)
        } catch let error as DiscogsError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRelease = false
    }

    // MARK: - Track Matching

    private func findMatchingTrack(in release: DiscogsRelease) -> DiscogsTrack? {
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

        return nil
    }

    // MARK: - Suggested Corrections

    var suggestedTitle: String? {
        matchedTrack?.title
    }

    var suggestedArtist: String? {
        guard let release = selectedRelease else { return nil }
        let raw = release.artistsSort ?? release.artists.first?.name
        // Clean Discogs disambiguation suffixes like " (2)"
        return raw?.replacingOccurrences(
            of: #"\s*\(\d+\)$"#, with: "",
            options: .regularExpression
        )
    }

    var suggestedAlbum: String? {
        selectedRelease?.title
    }
}
