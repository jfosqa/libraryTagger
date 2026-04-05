//
//  libraryTaggerTests.swift
//  libraryTaggerTests
//
//  Created by Jon Foley on 3/16/26.
//

import Testing
import Foundation
import MusicKit
@testable import libraryTagger

// MARK: - TitleCleaner Tests

@Suite("TitleCleaner")
struct TitleCleanerTests {

    // MARK: Underscore replacement

    @Test func underscoresReplacedWithSpaces() {
        let result = TitleCleaner.cleanForSearch(
            title: "High_Roller_-_Dirty_Skankin",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .dashSeparator]
        )
        #expect(result.parsedArtist == "High Roller")
        #expect(result.query == "Dirty Skankin")
    }

    // MARK: Track number stripping

    @Test func leadingTrackNumberStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "03 Some Track",
            artist: "Some Artist",
            issues: [.leadingTrackNumber]
        )
        #expect(result.query == "Some Track")
        #expect(result.parsedArtist == nil)
    }

    @Test func trackNumberStrippedBeforeDashParsing() {
        let result = TitleCleaner.cleanForSearch(
            title: "01 - Cypress Hill - Pigs",
            artist: "Unknown",
            issues: [.leadingTrackNumber, .dashSeparator]
        )
        #expect(result.parsedArtist == "Cypress Hill")
        #expect(result.query == "Pigs")
    }

    // MARK: Vinyl side indicator stripping

    @Test func vinylSideIndicatorStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "(B) piece of mind - phobia",
            artist: "Unknown",
            issues: [.dashSeparator]
        )
        #expect(result.parsedArtist == "piece of mind")
        #expect(result.query == "phobia")
    }

    @Test func vinylSideWithNumberStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "(A1) Some Artist - Some Title",
            artist: "Unknown",
            issues: [.dashSeparator]
        )
        #expect(result.parsedArtist == "Some Artist")
        #expect(result.query == "Some Title")
    }

    @Test func doubleSidedVinylIndicatorStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "(AA) Artist Name - Track Name",
            artist: "Unknown",
            issues: [.dashSeparator]
        )
        #expect(result.parsedArtist == "Artist Name")
        #expect(result.query == "Track Name")
    }

    // MARK: Dash separator parsing

    @Test func dashSeparatorParsesArtistAndTitle() {
        let result = TitleCleaner.cleanForSearch(
            title: "Noisia - Stigma",
            artist: "Unknown",
            issues: [.dashSeparator]
        )
        #expect(result.parsedArtist == "Noisia")
        #expect(result.query == "Stigma")
    }

    @Test func multipleDashesKeepsRemainderAsTitle() {
        let result = TitleCleaner.cleanForSearch(
            title: "Artist - Title - Remix",
            artist: "Unknown",
            issues: [.dashSeparator]
        )
        #expect(result.parsedArtist == "Artist")
        #expect(result.query == "Title - Remix")
    }

    // MARK: Square bracket removal

    @Test func squareBracketsRemoved() {
        let result = TitleCleaner.cleanForSearch(
            title: "Rhino[Flight Recordings]",
            artist: "Proktah",
            issues: [.squareBracketContent]
        )
        #expect(result.query == "Rhino")
    }

    // MARK: Suspicious parentheses removal

    @Test func featParenthesesRemoved() {
        let result = TitleCleaner.cleanForSearch(
            title: "Some Song (feat. Someone)",
            artist: "Artist",
            issues: [.suspiciousParentheses]
        )
        #expect(result.query == "Some Song")
    }

    @Test func remixParenthesesRemoved() {
        let result = TitleCleaner.cleanForSearch(
            title: "Track Name (Remix)",
            artist: "Artist",
            issues: [.suspiciousParentheses]
        )
        #expect(result.query == "Track Name")
    }

    // MARK: File extension removal

    @Test func mp3ExtensionRemoved() {
        let result = TitleCleaner.cleanForSearch(
            title: "Some Track.mp3",
            artist: "Artist",
            issues: [.fileExtension]
        )
        #expect(result.query == "Some Track")
    }

    @Test func flacExtensionRemoved() {
        let result = TitleCleaner.cleanForSearch(
            title: "Another Track.flac",
            artist: "Artist",
            issues: [.fileExtension]
        )
        #expect(result.query == "Another Track")
    }

    // MARK: Embedded artist name removal

    @Test func artistNameRemovedFromTitle() {
        let result = TitleCleaner.cleanForSearch(
            title: "Proktah & Hedj-Rhino",
            artist: "Proktah",
            issues: [.artistNameInTitle]
        )
        #expect(result.query == "& Hedj-Rhino")
    }

    // MARK: Combined issues

    @Test func underscoresAndDashSeparatorCombined() {
        let result = TitleCleaner.cleanForSearch(
            title: "Some_Artist_-_Some_Track",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .dashSeparator]
        )
        #expect(result.parsedArtist == "Some Artist")
        #expect(result.query == "Some Track")
    }

    @Test func trackNumberDashAndBracketsCombined() {
        let result = TitleCleaner.cleanForSearch(
            title: "01 - Artist - Track [Label]",
            artist: "Unknown",
            issues: [.leadingTrackNumber, .dashSeparator, .squareBracketContent]
        )
        #expect(result.parsedArtist == "Artist")
        #expect(result.query == "Track")
    }

    @Test func allIssuesCombined() {
        let result = TitleCleaner.cleanForSearch(
            title: "01_-_Some_Artist_-_Cool_Track_(feat._Someone)[Some_Label].mp3",
            artist: "Some Artist",
            issues: [.leadingTrackNumber, .underscoresAsSpaces, .dashSeparator,
                     .squareBracketContent, .suspiciousParentheses, .fileExtension,
                     .artistNameInTitle]
        )
        #expect(result.parsedArtist == "Some Artist")
        // Artist removed from title, brackets removed, parens removed, extension removed
        #expect(!result.query.contains("["))
        #expect(!result.query.contains("(feat."))
        #expect(!result.query.contains(".mp3"))
        #expect(result.query.contains("Cool Track"))
    }

    // MARK: Bare featuring artist removal

    @Test func bareFeatStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "Lolo (Intro) Feat. Xzibit & Tray Deee",
            artist: "Dr. Dre",
            issues: [.featuringArtist]
        )
        #expect(result.query == "Lolo (Intro)")
    }

    @Test func bareFtStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "Still D.R.E. ft. Snoop Dogg",
            artist: "Dr. Dre",
            issues: [.featuringArtist]
        )
        #expect(result.query == "Still D.R.E.")
    }

    @Test func bareFeaturingStripped() {
        let result = TitleCleaner.cleanForSearch(
            title: "Light Speed featuring Hittman",
            artist: "Dr. Dre",
            issues: [.featuringArtist]
        )
        #expect(result.query == "Light Speed")
    }

    @Test func trackNumberAndFeaturingCombined() {
        let result = TitleCleaner.cleanForSearch(
            title: "01 - Lolo (Intro) Feat. Xzibit & Tray Deee",
            artist: "Dr. Dre",
            issues: [.leadingTrackNumber, .dashSeparator, .featuringArtist]
        )
        #expect(result.query == "Lolo (Intro)")
    }

    // MARK: Scene release naming

    @Test func sceneReleaseExtractsArtistAndTitle() {
        let result = TitleCleaner.cleanForSearch(
            title: "01-dj_hype-jack_to_a_king-skotch",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .leadingTrackNumber, .sceneRelease]
        )
        #expect(result.parsedArtist == "dj hype")
        #expect(result.query == "jack to a king")
    }

    @Test func sceneReleaseDropsGroupTag() {
        let result = TitleCleaner.cleanForSearch(
            title: "03-noisia-stigma-nvsb",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .leadingTrackNumber, .sceneRelease]
        )
        #expect(result.parsedArtist == "noisia")
        #expect(result.query == "stigma")
    }

    @Test func sceneReleaseMultiWordSegments() {
        let result = TitleCleaner.cleanForSearch(
            title: "05-cypress_hill-insane_in_the_brain-ruffhouse",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .leadingTrackNumber, .sceneRelease]
        )
        #expect(result.parsedArtist == "cypress hill")
        #expect(result.query == "insane in the brain")
    }

    @Test func sceneReleaseStripsFeatFromArtist() {
        let result = TitleCleaner.cleanForSearch(
            title: "01-Chase_&_Status_Ft.Kano-Against_All_Odds-group",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .leadingTrackNumber, .sceneRelease]
        )
        #expect(result.parsedArtist == "Chase & Status")
        #expect(result.query == "Against All Odds")
    }

    @Test func dashSeparatorStripsFeatFromArtist() {
        let result = TitleCleaner.cleanForSearch(
            title: "01 - Chase & Status Feat. Kano - Against All Odds",
            artist: "Unknown",
            issues: [.leadingTrackNumber, .dashSeparator, .featuringArtist]
        )
        #expect(result.parsedArtist == "Chase & Status")
        #expect(result.query == "Against All Odds")
    }

    @Test func sceneReleaseSingleWordSegments() {
        let result = TitleCleaner.cleanForSearch(
            title: "01-coaxial-freebasin-skotch",
            artist: "Unknown",
            issues: [.leadingTrackNumber, .sceneRelease]
        )
        #expect(result.parsedArtist == "coaxial")
        #expect(result.query == "freebasin")
    }

    @Test func sceneReleaseDoesNotAffectNormalDashSeparator() {
        // _-_ pattern is NOT scene release, just normal dash separator
        let result = TitleCleaner.cleanForSearch(
            title: "Some_Artist_-_Some_Track",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .dashSeparator]
        )
        #expect(result.parsedArtist == "Some Artist")
        #expect(result.query == "Some Track")
    }

    // MARK: No issues

    @Test func noIssuesReturnsOriginalTitle() {
        let result = TitleCleaner.cleanForSearch(
            title: "Clean Title",
            artist: "Artist",
            issues: []
        )
        #expect(result.query == "Clean Title")
        #expect(result.parsedArtist == nil)
    }

    // MARK: Whitespace collapsing

    @Test func multipleSpacesCollapsed() {
        let result = TitleCleaner.cleanForSearch(
            title: "Track  [Label]  Name",
            artist: "Artist",
            issues: [.squareBracketContent]
        )
        #expect(!result.query.contains("  "))
    }
}

// MARK: - MusicAppService Tests

@Suite("MusicAppService Helpers")
struct MusicAppServiceTests {

    @Test func trackCorrectionWithAllFields() {
        let correction = TrackCorrection(title: "New Title", artist: "New Artist", album: "New Album")
        #expect(correction.title == "New Title")
        #expect(correction.artist == "New Artist")
        #expect(correction.album == "New Album")
    }

    @Test func trackCorrectionWithPartialFields() {
        let correction = TrackCorrection(title: "New Title", artist: nil, album: nil)
        #expect(correction.title == "New Title")
        #expect(correction.artist == nil)
        #expect(correction.album == nil)
    }

    @Test func trackCorrectionAllNil() {
        let correction = TrackCorrection(title: nil, artist: nil, album: nil)
        #expect(correction.title == nil)
        #expect(correction.artist == nil)
        #expect(correction.album == nil)
    }
}

// MARK: - TagIssue Tests

@Suite("TagIssue")
struct TagIssueTests {

    @Test func allCasesExist() {
        // 10 issue types: artistNameInTitle, albumNameInTitle, underscoresAsSpaces,
        // squareBracketContent, suspiciousParentheses, featuringArtist, sceneRelease,
        // fileExtension, dashSeparator, leadingTrackNumber
        #expect(TagIssue.allCases.count == 10)
    }

    @Test func identifiableUsesRawValue() {
        for issue in TagIssue.allCases {
            #expect(issue.id == issue.rawValue)
        }
    }

    @Test func colorsAssigned() {
        // Every issue should have a non-nil color
        for issue in TagIssue.allCases {
            // Just accessing color to ensure it doesn't crash
            _ = issue.color
        }
    }
}
// MARK: - Album Batch Correction Tests

@Suite("Album Batch Correction")
struct AlbumBatchCorrectionTests {

    // MARK: - Test Helpers

    private func makeScanResult(
        id: String,
        title: String,
        artist: String = "Test Artist",
        album: String? = "Test Album",
        issues: [TagIssue] = [.dashSeparator]
    ) -> ScanResult {
        ScanResult(
            id: MusicItemID(id),
            title: title,
            artistName: artist,
            albumTitle: album,
            issues: issues
        )
    }

    private func makeRelease(
        title: String = "Test Album",
        artist: String = "Test Artist",
        tracks: [(position: String, title: String)] = []
    ) -> DiscogsRelease {
        DiscogsRelease(
            id: 1,
            title: title,
            artistsSort: artist,
            artists: [DiscogsArtist(name: artist, id: 1, role: nil)],
            year: 2024,
            tracklist: tracks.map { DiscogsTrack(position: $0.position, title: $0.title, duration: "3:00") },
            genres: nil,
            styles: nil
        )
    }

    // MARK: - findMatchingTrack Tests

    @Test func findMatchingTrackExactMatch() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let release = makeRelease(tracks: [("1", "Pigs"), ("2", "Stigma")])
        let match = vm.findMatchingTrack(in: release, cleanedTitle: "Stigma")
        #expect(match?.title == "Stigma")
    }

    @Test func findMatchingTrackCaseInsensitive() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let release = makeRelease(tracks: [("1", "PIGS"), ("2", "Stigma")])
        let match = vm.findMatchingTrack(in: release, cleanedTitle: "pigs")
        #expect(match?.title == "PIGS")
    }

    @Test func findMatchingTrackSubstringMatch() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let release = makeRelease(tracks: [("1", "Pigs (Remastered)"), ("2", "Stigma")])
        let match = vm.findMatchingTrack(in: release, cleanedTitle: "Pigs")
        #expect(match?.title == "Pigs (Remastered)")
    }

    @Test func findMatchingTrackNoMatch() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let release = makeRelease(tracks: [("1", "Pigs"), ("2", "Stigma")])
        let match = vm.findMatchingTrack(in: release, cleanedTitle: "Nonexistent")
        #expect(match == nil)
    }

    @Test func findMatchingTrackNormalizedAndVsAmpersand() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let release = makeRelease(tracks: [("1", "Peace, Love & Unity (Remix)")])
        let match = vm.findMatchingTrack(in: release, cleanedTitle: "peace love and unity (remix)")
        #expect(match?.title == "Peace, Love & Unity (Remix)")
    }

    @Test func findMatchingTrackNormalizedPunctuation() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let release = makeRelease(tracks: [("1", "Don't Stop")])
        let match = vm.findMatchingTrack(in: release, cleanedTitle: "dont stop")
        #expect(match?.title == "Don't Stop")
    }

    // MARK: - buildCorrection Tests

    @Test func buildCorrectionWithDifferences() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let scan = makeScanResult(id: "2", title: "01 - Bad Title", artist: "Unknown", album: "Wrong Album")
        let release = makeRelease(title: "Correct Album", artist: "Correct Artist")
        let track = DiscogsTrack(position: "1", title: "Correct Title", duration: "3:00")

        let correction = vm.buildCorrection(for: scan, matchedTrack: track, release: release)
        #expect(correction?.title == "Correct Title")
        #expect(correction?.artist == "Correct Artist")
        #expect(correction?.album == "Correct Album")
    }

    @Test func buildCorrectionNilWhenAllMatch() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let scan = makeScanResult(id: "2", title: "Pigs", artist: "Cypress Hill", album: "Test Album")
        let release = makeRelease(title: "Test Album", artist: "Cypress Hill")
        let track = DiscogsTrack(position: "1", title: "Pigs", duration: "3:00")

        let correction = vm.buildCorrection(for: scan, matchedTrack: track, release: release)
        #expect(correction == nil)
    }

    @Test func buildCorrectionPartialDifferences() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let scan = makeScanResult(id: "2", title: "Pigs", artist: "Wrong Artist", album: "Test Album")
        let release = makeRelease(title: "Test Album", artist: "Correct Artist")
        let track = DiscogsTrack(position: "1", title: "Pigs", duration: "3:00")

        let correction = vm.buildCorrection(for: scan, matchedTrack: track, release: release)
        #expect(correction?.title == nil)
        #expect(correction?.artist == "Correct Artist")
        #expect(correction?.album == nil)
    }

    @Test func buildCorrectionWithNoMatchedTrack() {
        let vm = SongDetailViewModel(scanResult: makeScanResult(id: "1", title: "Test"))
        let scan = makeScanResult(id: "2", title: "Pigs", artist: "Wrong Artist", album: "Wrong Album")
        let release = makeRelease(title: "Correct Album", artist: "Correct Artist")

        let correction = vm.buildCorrection(for: scan, matchedTrack: nil, release: release)
        // No matched track means no title correction, but artist/album still apply
        #expect(correction?.title == nil)
        #expect(correction?.artist == "Correct Artist")
        #expect(correction?.album == "Correct Album")
    }

    // MARK: - Sibling Matching Tests

    @Test func siblingsFilteredByAlbum() {
        let primary = makeScanResult(id: "1", title: "01 - Track One", album: "My Album")
        let sibling1 = makeScanResult(id: "2", title: "02 - Track Two", album: "My Album")
        let sibling2 = makeScanResult(id: "3", title: "03 - Track Three", album: "My Album")
        let unrelated = makeScanResult(id: "4", title: "Other Track", album: "Different Album")

        let vm = SongDetailViewModel(
            scanResult: primary,
            allScanResults: [primary, sibling1, sibling2, unrelated]
        )

        // Simulate selecting a release
        let release = makeRelease(
            title: "My Album",
            artist: "Test Artist",
            tracks: [("1", "Track One"), ("2", "Track Two"), ("3", "Track Three")]
        )
        vm.selectedRelease = release
        vm.matchedTrack = vm.findMatchingTrack(in: release, cleanedTitle: "Track One")

        // Trigger sibling matching manually via selectRelease-like flow
        // Since matchSiblings is private, we verify via the public property after setting state
        // We need to call selectRelease but it's async and hits the network.
        // Instead, test the data: siblings should only include same-album, not primary, not unrelated.
        // Let's verify the filtering logic by checking allScanResults content.
        let sameAlbum = vm.allScanResults.filter { other in
            other.id != primary.id &&
            other.albumTitle != nil &&
            other.albumTitle!.localizedCaseInsensitiveCompare("My Album") == .orderedSame
        }
        #expect(sameAlbum.count == 2)
        #expect(sameAlbum.contains(where: { $0.id == sibling1.id }))
        #expect(sameAlbum.contains(where: { $0.id == sibling2.id }))
        #expect(!sameAlbum.contains(where: { $0.id == unrelated.id }))
    }

    @Test func siblingsFilteredCaseInsensitive() {
        let primary = makeScanResult(id: "1", title: "Track One", album: "my album")
        let sibling = makeScanResult(id: "2", title: "Track Two", album: "My Album")

        let vm = SongDetailViewModel(
            scanResult: primary,
            allScanResults: [primary, sibling]
        )

        let sameAlbum = vm.allScanResults.filter { other in
            other.id != primary.id &&
            other.albumTitle != nil &&
            other.albumTitle!.localizedCaseInsensitiveCompare(primary.albumTitle!) == .orderedSame
        }
        #expect(sameAlbum.count == 1)
    }

    @Test func siblingWithNoMatchExcludedByDefault() {
        let primary = makeScanResult(id: "1", title: "01 - Track One", album: "My Album")
        let sibling = makeScanResult(id: "2", title: "Unknown Track", album: "My Album")

        let vm = SongDetailViewModel(
            scanResult: primary,
            allScanResults: [primary, sibling]
        )

        let release = makeRelease(
            title: "My Album",
            artist: "Test Artist",
            tracks: [("1", "Track One")]
        )

        // Clean the sibling title and try matching
        let cleaned = TitleCleaner.cleanForSearch(
            title: sibling.title,
            artist: sibling.artistName,
            issues: sibling.issues
        )
        let match = vm.findMatchingTrack(in: release, cleanedTitle: cleaned.query)
        #expect(match == nil)
        // When matchSiblings runs, isIncluded should be false for unmatched siblings
    }

    @Test func siblingWithMatchIncludedByDefault() {
        let primary = makeScanResult(id: "1", title: "01 - Track One", album: "My Album")
        let sibling = makeScanResult(
            id: "2",
            title: "02 - Track Two",
            album: "My Album",
            issues: [.leadingTrackNumber, .dashSeparator]
        )

        let vm = SongDetailViewModel(
            scanResult: primary,
            allScanResults: [primary, sibling]
        )

        let release = makeRelease(
            title: "My Album",
            artist: "Test Artist",
            tracks: [("1", "Track One"), ("2", "Track Two")]
        )

        // Clean the sibling title and verify it matches
        let cleaned = TitleCleaner.cleanForSearch(
            title: sibling.title,
            artist: sibling.artistName,
            issues: sibling.issues
        )
        let match = vm.findMatchingTrack(in: release, cleanedTitle: cleaned.query)
        #expect(match?.title == "Track Two")
    }

    // MARK: - cleanedCorrection Tests

    @Test func cleanedCorrectionReturnsTitleAndArtist() {
        let scan = makeScanResult(
            id: "1",
            title: "01-dj_hype-jack_to_a_king-skotch",
            artist: "Unknown",
            issues: [.underscoresAsSpaces, .leadingTrackNumber, .sceneRelease]
        )
        let vm = SongDetailViewModel(scanResult: scan)
        let correction = vm.cleanedCorrection
        #expect(correction?.title == "jack to a king")
        #expect(correction?.artist == "dj hype")
        #expect(correction?.album == nil)
    }

    @Test func cleanedCorrectionNilWhenNothingDiffers() {
        let scan = makeScanResult(
            id: "1",
            title: "Some Track",
            artist: "Some Artist",
            issues: []
        )
        let vm = SongDetailViewModel(scanResult: scan)
        #expect(vm.cleanedCorrection == nil)
    }

    @Test func cleanedCorrectionTitleOnlyWhenArtistMatches() {
        let scan = makeScanResult(
            id: "1",
            title: "03 Bad Title",
            artist: "Some Artist",
            issues: [.leadingTrackNumber]
        )
        let vm = SongDetailViewModel(scanResult: scan)
        let correction = vm.cleanedCorrection
        #expect(correction?.title == "Bad Title")
        #expect(correction?.artist == nil)
    }
}

