# libraryTagger

A macOS application that scans your Apple Music library for poorly tagged songs, looks up corrections via the Discogs API, and applies fixes directly to your Music.app library via AppleScript.

---

## Architecture

| File | Purpose |
|------|---------|
| `ContentView.swift` | Main scan UI — scan button, max songs picker, results list |
| `ScanResultRow.swift` | Row view for each flagged song in the scan results list |
| `SongDetailView.swift` | Detail view for a single song — shows metadata, Discogs results, corrections, tracklist |
| `SongDetailViewModel.swift` | Business logic — search pipeline, track matching, correction building, sibling matching |
| `TitleScanner.swift` | Detects tag quality issues in song titles (10 rules) |
| `TitleCleaner.swift` | Cleans detected issues to produce search queries and parse artist/title |
| `TagIssue.swift` | Enum of 10 tag issue types + `ScanResult` model |
| `DiscogsService.swift` | Discogs API client (search + release detail), actor-based |
| `DiscogsModels.swift` | Codable models for Discogs API responses |
| `DiscogsConfig.swift` | API token and base URL configuration |
| `MusicAppService.swift` | AppleScript bridge to modify tracks in Music.app |
| `CorrectionRow.swift` | Reusable view showing current vs. suggested field values |

---

## Core Workflow

1. **Scan** — `ContentView` fetches songs via MusicKit (`MusicLibraryRequest<Song>`) and runs `TitleScanner.scanAll()` to find songs with tagging issues.
2. **Review** — User taps a flagged song to open `SongDetailView`, which automatically searches Discogs.
3. **Match** — User selects a Discogs release. The app auto-matches a track from the tracklist, or the user can manually tap a track.
4. **Correct** — User reviews suggested corrections (title, artist, album) and applies them. Sibling tracks from the same album can be batch-corrected.

---

## Tag Issue Detection (`TitleScanner`)

10 rules are applied to every song title:

| # | Issue | Detection | Example |
|---|-------|-----------|---------|
| 1 | `artistNameInTitle` | Artist name (≥3 chars) found in title, excluding self-titled tracks | `"Proktah & Hedj-Rhino"` by Proktah |
| 2 | `albumNameInTitle` | Album name (≥3 chars) found in title, excluding title tracks | `"Album Name - Track"` |
| 3 | `underscoresAsSpaces` | Title contains `_` | `"Some_Track_Name"` |
| 4 | `squareBracketContent` | `[...]` content found | `"Track [Flight Recordings]"` |
| 5 | `suspiciousParentheses` | Parentheses containing feat/ft/remix/bootleg/official/etc. | `"Track (feat. Someone)"` |
| 6 | `featuringArtist` | Bare `Feat.`/`Ft.`/`featuring` outside parentheses | `"Track Feat. Xzibit"` |
| 7 | `fileExtension` | `.mp3`, `.flac`, `.wav`, etc. in title | `"Track.mp3"` |
| 8 | `dashSeparator` | ` - ` or `_-_` pattern (concatenated fields) | `"Artist - Title"` |
| 9 | `leadingTrackNumber` | Starts with 1–3 digits followed by `.`, space, or `-` | `"01 - Track"` |
| 10 | `sceneRelease` | Starts with `NN-` (no space) and has 2+ hyphen-separated segments | `"01-artist-title-group"` |

---

## Title Cleaning (`TitleCleaner`)

`cleanForSearch(title:artist:issues:)` returns a cleaned search query and an optionally parsed artist name. Processing order matters:

### Scene Release Path (when `.sceneRelease` detected)
Runs **before** all other processing to preserve bare hyphens as field delimiters:

1. Strip leading track number (`^\d{1,3}-`)
2. Split remaining text on `-`
3. Drop last segment if 3+ segments (release group tag, e.g., `-skotch`)
4. First segment → parsed artist, remaining → title
5. Replace `_` with spaces in both

**Example:** `01-dj_hype-jack_to_a_king-skotch` → artist: `"dj hype"`, title: `"jack to a king"`

### Standard Path (non-scene releases)

1. Replace underscores with spaces
2. Strip leading track numbers (`^\d{1,3}[.\s-]+`)
3. Strip vinyl side indicators (`(A)`, `(B)`, `(AA)`, `(B1)`, etc.)
4. Parse `Artist - Title` dash separator pattern

### Common Steps (both paths)

5. Remove square bracket content
6. Remove suspicious parenthetical content (feat, remix, etc.)
7. Strip file extensions
8. Strip bare featuring text and everything after it
9. Remove embedded artist name
10. **Strip featuring text from parsed artist** (universal — handles `Ft.`/`Feat.`/`featuring` fused to artist without word boundary, e.g., `"Chase & Status Ft.Kano"` → `"Chase & Status"`)
11. Collapse multiple spaces and trim

---

## Discogs Search Pipeline (`SongDetailViewModel.search()`)

A multi-step fallback search strategy:

| Step | Strategy | Example |
|------|----------|---------|
| 1 | `query=cleanedTitle` + `artist=parsedArtist` | `"violent killa"` by `"dillinja"` |
| 2 | **Swap** artist and title (handles `Title - Artist` ordering) | `"dillinja"` by `"violent killa"` |
| 3a | **`and`→`&` normalization** in query and artist | `"deep blue & blame"` |
| 3b | **`&`→`and` normalization** in query and artist | `"craggz and parallel forces"` |
| 4 | **Drop artist constraint** — combined query without `artist` param | `"d type capone"` (no artist filter) |
| 5 | **Album fallback** — search by album title + artist | `"2001"` by `"Dr. Dre"` |

Each step only runs if all previous steps returned zero results.

---

## Track Matching (`findMatchingTrack`)

After a Discogs release is selected, the app attempts to auto-match a track from the tracklist using three strategies (in order):

1. **Exact match** — case-insensitive string equality
2. **Contains match** — either string contains the other (handles suffixes like "(Remastered)")
3. **Normalized match** — strips punctuation (`,.'`), converts `&`→`and`, collapses whitespace, then compares

If auto-matching fails, the user can **manually tap any track** in the "Release Tracklist" section to select it.

---

## Track-Level Artist Support

`DiscogsTrack` includes an optional `artists` field decoded from the Discogs API. For split/compilation releases (e.g., "Dillinja / Lemon D"), individual tracks may have their own artist credits.

When building corrections, the app prefers:
1. **Track-level artist** (from `matchedTrack.artistName`)
2. **Release-level `artistsSort`**
3. **First release artist**

Discogs disambiguation suffixes like `" (2)"` are automatically stripped.

The tracklist UI displays per-track artist names when available.

---

## Correction Application

### Single Track (`MusicAppService`)
- Builds an AppleScript that finds the track by current title + artist in Music.app's library
- Sets `name`, `artist`, and/or `album` properties via `set` statements
- Only includes fields that actually differ from current values
- Properly escapes strings for AppleScript literal inclusion

### Cleaned Data (no Discogs needed)
- `cleanedCorrection` builds a `TrackCorrection` from the parsed/cleaned data
- Available when no Discogs release is selected but the cleaned data differs from current metadata
- Applies title and artist corrections only (no album)

### Album Batch Correction
- When a release is selected, the app finds **sibling tracks** from the same album in the scan results
- Each sibling is cleaned and matched against the release tracklist
- Matched siblings are pre-selected; unmatched siblings are deselected by default
- User can toggle individual siblings on/off
- "Apply All (N tracks)" applies corrections to the primary track + selected siblings
- Corrected tracks are visually dimmed in the main scan results list

---

## Navigation

### Scan Results List
- `NavigationStack` with `NavigationLink` to song detail
- Configurable max songs (50/100/250/500/1000/All)
- "New Search" and "Scan Again" toolbar buttons
- Corrected tracks show a green checkmark badge and reduced opacity

### Song Detail View
- **Previous/Next navigation** — toolbar buttons with chevron icons and `"N / Total"` position indicator
- Uses `.task(id: currentIndex)` to re-trigger Discogs search when navigating
- Creates a fresh `SongDetailViewModel` on each navigation

---

## UI Components

### `ScanResultRow`
- Song title (headline), artist name (subheadline)
- Color-coded issue capsule tags (orange/red/purple)
- Green "Corrected" badge when already applied

### `SongDetailView` Sections
1. **Current Metadata** — title, artist, album, issue tags
2. **Search Query** — cleaned title, parsed artist, swap indicator
3. **Discogs Results** — tappable list of search results with year
4. **Apply Cleaned Data** — shown when no Discogs release selected but parsed data differs
5. **Suggested Corrections** — `CorrectionRow` for each differing field (title/artist/album)
6. **Other Album Tracks** — toggleable sibling corrections with match status
7. **Apply Corrections** — button with track count, success/error feedback
8. **Release Tracklist** — tappable tracks with position, title, per-track artist, duration; selected track highlighted in green with checkmark

### `CorrectionRow`
- Shows field label, current value (struck through in red), suggested value (green)
- "Already correct" label when values match

---

## Discogs API Integration

### `DiscogsService` (Actor)
- **Search**: `GET /database/search` with `q`, `type=release`, optional `artist`, pagination
- **Release Detail**: `GET /releases/{id}` for full tracklist and metadata
- Rate limiting: catches HTTP 429 and reports `retryAfter` interval
- Error types: `invalidURL`, `httpError`, `rateLimited`, `decodingError`, `networkError`

### Models
- `DiscogsSearchResponse` / `DiscogsPagination` / `DiscogsSearchResult`
- `DiscogsRelease` — includes `artistsSort`, `artists`, `tracklist`, `genres`, `styles`
- `DiscogsArtist` — `name`, `id`, `role`
- `DiscogsTrack` — `position`, `title`, `duration`, optional `artists` array with computed `artistName`

---

## Test Suite

56 tests across 4 test suites, using the Swift Testing framework (`@Test`, `@Suite`, `#expect`).

### `TitleCleanerTests` (30 tests)

| Test | What it verifies |
|------|-----------------|
| `underscoresReplacedWithSpaces` | `_` → spaces with dash separator parsing |
| `leadingTrackNumberStripped` | `"03 Some Track"` → `"Some Track"` |
| `trackNumberStrippedBeforeDashParsing` | `"01 - Cypress Hill - Pigs"` → artist: `"Cypress Hill"`, title: `"Pigs"` |
| `vinylSideIndicatorStripped` | `"(B) piece of mind - phobia"` → artist: `"piece of mind"` |
| `vinylSideWithNumberStripped` | `"(A1) Some Artist - Some Title"` → correct parsing |
| `doubleSidedVinylIndicatorStripped` | `"(AA) Artist Name - Track Name"` → correct parsing |
| `dashSeparatorParsesArtistAndTitle` | `"Noisia - Stigma"` → artist: `"Noisia"`, title: `"Stigma"` |
| `multipleDashesKeepsRemainderAsTitle` | `"Artist - Title - Remix"` → title: `"Title - Remix"` |
| `squareBracketsRemoved` | `"Rhino[Flight Recordings]"` → `"Rhino"` |
| `featParenthesesRemoved` | `"Some Song (feat. Someone)"` → `"Some Song"` |
| `remixParenthesesRemoved` | `"Track Name (Remix)"` → `"Track Name"` |
| `mp3ExtensionRemoved` | `"Some Track.mp3"` → `"Some Track"` |
| `flacExtensionRemoved` | `"Another Track.flac"` → `"Another Track"` |
| `artistNameRemovedFromTitle` | Removes embedded artist name |
| `underscoresAndDashSeparatorCombined` | Combined underscore + dash handling |
| `trackNumberDashAndBracketsCombined` | Combined track number + dash + brackets |
| `allIssuesCombined` | All issue types applied together |
| `bareFeatStripped` | `"Lolo (Intro) Feat. Xzibit & Tray Deee"` → `"Lolo (Intro)"` |
| `bareFtStripped` | `"Still D.R.E. ft. Snoop Dogg"` → `"Still D.R.E."` |
| `bareFeaturingStripped` | `"Light Speed featuring Hittman"` → `"Light Speed"` |
| `trackNumberAndFeaturingCombined` | Track number stripping + featuring removal together |
| `sceneReleaseExtractsArtistAndTitle` | `"01-dj_hype-jack_to_a_king-skotch"` → artist/title parsed |
| `sceneReleaseDropsGroupTag` | Last segment (group tag) removed from 3+ segment names |
| `sceneReleaseMultiWordSegments` | Multi-word underscore segments handled correctly |
| `sceneReleaseStripsFeatFromArtist` | `"Chase_&_Status_Ft.Kano"` → `"Chase & Status"` |
| `dashSeparatorStripsFeatFromArtist` | Featuring stripped from artist in standard dash path |
| `sceneReleaseSingleWordSegments` | `"01-coaxial-freebasin-skotch"` → single-word segments work |
| `sceneReleaseDoesNotAffectNormalDashSeparator` | `_-_` pattern uses standard path, not scene release |
| `noIssuesReturnsOriginalTitle` | Empty issues returns original title unchanged |
| `multipleSpacesCollapsed` | Whitespace normalization after bracket removal |

### `MusicAppServiceTests` (3 tests)

| Test | What it verifies |
|------|-----------------|
| `trackCorrectionWithAllFields` | All three fields populated |
| `trackCorrectionWithPartialFields` | Only title populated, artist/album nil |
| `trackCorrectionAllNil` | All fields nil |

### `TagIssueTests` (3 tests)

| Test | What it verifies |
|------|-----------------|
| `allCasesExist` | Exactly 10 issue types defined |
| `identifiableUsesRawValue` | `id` matches `rawValue` for all cases |
| `colorsAssigned` | Every case has a non-crashing color assignment |

### `AlbumBatchCorrectionTests` (17 tests)

| Test | What it verifies |
|------|-----------------|
| `findMatchingTrackExactMatch` | Exact title match in tracklist |
| `findMatchingTrackCaseInsensitive` | Case-insensitive matching |
| `findMatchingTrackSubstringMatch` | `"Pigs"` matches `"Pigs (Remastered)"` |
| `findMatchingTrackNoMatch` | Returns nil for unmatched title |
| `findMatchingTrackNormalizedAndVsAmpersand` | `"and"` matches `"&"` after normalization |
| `findMatchingTrackNormalizedPunctuation` | `"dont stop"` matches `"Don't Stop"` |
| `buildCorrectionWithDifferences` | All three fields corrected when all differ |
| `buildCorrectionNilWhenAllMatch` | Returns nil when nothing differs |
| `buildCorrectionPartialDifferences` | Only differing fields included |
| `buildCorrectionWithNoMatchedTrack` | No title correction without matched track, but artist/album still apply |
| `siblingsFilteredByAlbum` | Only same-album tracks included as siblings |
| `siblingsFilteredCaseInsensitive` | Album matching is case-insensitive |
| `siblingWithNoMatchExcludedByDefault` | Unmatched siblings have `isIncluded = false` |
| `siblingWithMatchIncludedByDefault` | Matched siblings have `isIncluded = true` |
| `cleanedCorrectionReturnsTitleAndArtist` | Scene release produces correct title + artist correction |
| `cleanedCorrectionNilWhenNothingDiffers` | Returns nil when cleaned data matches current |
| `cleanedCorrectionTitleOnlyWhenArtistMatches` | Only title correction when artist already matches |

---

## Dependencies

- **MusicKit** — library access and authorization (`MusicLibraryRequest<Song>`, `MusicAuthorization`)
- **SwiftUI** — UI framework
- **Foundation** — regex, URL handling, JSON decoding
- **CoreData** — persistence (scaffolded, not heavily used)
- **Discogs API** — external metadata lookup (requires personal access token)
- **NSAppleScript** — Music.app track modification (requires automation entitlement)
