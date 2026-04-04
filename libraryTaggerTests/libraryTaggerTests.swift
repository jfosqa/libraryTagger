//
//  libraryTaggerTests.swift
//  libraryTaggerTests
//
//  Created by Jon Foley on 3/16/26.
//

import Testing
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
        #expect(TagIssue.allCases.count == 8)
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
