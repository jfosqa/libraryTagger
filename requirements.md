# **Requirements Documentation for libraryTagger project**   

### Pattern for working
1. Read the requirements
2. Build an implementation plan - if unsure, ask questions before finalizing plan
3. Write test cases
4. Write the test code
5. Verify test(s) fails
6. Implement the functionality
7. Verify the test(s) passes
8. Update documentation

## Outstanding features

1. Fix Genre
2. Database of corrected tags and what the issue/bad tag was for display

## Completed Features

1. Directed search
2. Sort & Filter results view

## Directed Search Requirements

As a user of libraryTagger, I would like to be able to hone in on specific items in my library that I would like corrected. 

This search should be optional and in a separate window from the main search view. 
It should be brought up with a UI button named "Directed Search" on the main search view. 
The user should be able to choose what fields to search on using a drop down menu with a text box next to it. 
There should be the ability to add up to 3 search fields.
Search fields should accept up to 2 wildcard search parameters.
Results of the search takes the user to the same results view as non-directed search.

### Implementation Notes
- String field filters (Name, Artist, Album) use **local substring matching** (`localizedCaseInsensitiveContains`) instead of MusicKit's `filter(matching:contains:)`, which only performs tokenized word-prefix matching and misses mid-string substrings (e.g. "monk" in "02-ice_minus-monk_fish-skotch") and partial artist names (e.g. "Hazard" in "DJ Hazard").
- Genre filters still use MusicKit's relationship-based filter at fetch time.
- Local filtering is handled by `DirectedSearchFilter.apply(_:filters:)` in `ContentView.swift`.

## Sort & Filter Results view
As a user, I would like to be able to sort the results view.

Implement a table with headers for Title, Artist, Album, Alerts, Correction Status.
The column headers of the table should be interactive and allow user to sort ascending/descending based on the column header. 
The correction status field is net new - shows whether correction has been applied or not
Alerts should be a multi-value field that shows what the tag issues are in the currect results set
Filter - Should open a dialog to apply filter criteria. Each filter criteria has independent enable/disable:
 1. Title - combo box, allows wildcard
 2. Artist - combo box, allows wildcard
 3. Album - combo box, allows wildcard
 4. Alerts - list select
 5. Correction Status - toggle Corrected/Needs correction
Filter dialog will have buttons for Clear, Cancel & Apply/OK

### Implementation Notes
- Results are displayed in a SwiftUI `Table` with 5 sortable columns (Title, Artist, Album, Alerts, Status) in `ResultsTableView.swift`.
- All columns use `KeyPathComparator<ScanResultTableItem>` as a unified sort comparator type to satisfy Table's type requirements.
- `ScanResultTableItem` wraps `ScanResult` with concrete sortable properties: `alertCount` (Int), `correctionSortValue` (Int), and `albumTitle` defaulting to `""` for nil values.
- Row selection uses `Table(selection:)` binding with `.onChange(of: selectedResultID)` to push onto a `NavigationPath`, since Table rows don't support `NavigationLink`.
- Filtering uses `ResultsFilter` model with per-field pattern/enabled pairs. Enabled filters are ANDed; alert filters use OR logic within the selected set.
- Text field matching (title, artist, album) uses `WildcardMatcher`: no `*` does `localizedCaseInsensitiveContains` substring match; `*` present converts to anchored regex with special characters escaped.
- `ComboBoxView` is an `NSViewRepresentable` wrapping `NSComboBox` for native macOS combo box behavior (dropdown with typed override).
- `ResultsFilterSheet` uses a local `@State` copy of the filter so Cancel discards edits without side effects. Combo box dropdowns are populated from unique values in the current result set.
- Unfiltered `scanResults` are passed to `SongDetailView.allScanResults` so prev/next navigation covers the full set regardless of active filters.
- New files: `WildcardMatcher.swift`, `ScanResultTableItem.swift`, `ResultsFilter.swift`, `ComboBoxView.swift`, `ResultsFilterSheet.swift`, `ResultsTableView.swift`.
- Test coverage: 44 new tests across `WildcardMatcherTests` (13), `ScanResultTableItemTests` (8), and `ResultsFilterTests` (23).

