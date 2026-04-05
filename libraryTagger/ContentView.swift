//
//  ContentView.swift
//  libraryTagger
//
//  Created by Jon Foley on 3/16/26.
//

import SwiftUI
import CoreData
import MusicKit

/// The field to filter library songs by.
enum SongFilterField: String, CaseIterable, Identifiable {
    case name = "Name"
    case artist = "Artist"
    case album = "Album"
    case genre = "Genre"

    var id: String { rawValue }
}

/// Filters an array of ScanResults locally using true substring matching.
struct DirectedSearchFilter {
    /// Returns only the results that match ALL non-empty filters (AND logic).
    /// Each filter checks whether the corresponding field contains the search text
    /// using case-insensitive substring matching.
    static func apply(
        _ results: [ScanResult],
        filters: [(field: SongFilterField, text: String)]
    ) -> [ScanResult] {
        let activeFilters = filters.filter { !$0.text.isEmpty }
        guard !activeFilters.isEmpty else { return results }

        return results.filter { result in
            activeFilters.allSatisfy { filter in
                switch filter.field {
                case .name:
                    return result.title.localizedCaseInsensitiveContains(filter.text)
                case .artist:
                    return result.artistName.localizedCaseInsensitiveContains(filter.text)
                case .album:
                    return result.albumTitle?.localizedCaseInsensitiveContains(filter.text) ?? false
                case .genre:
                    // Genre filtering is handled by MusicKit at fetch time
                    return true
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @State private var scanResults: [ScanResult] = []
    @State private var isScanning = false
    @State private var totalSongsScanned = 0
    @State private var maxSongs = 0
    @State private var correctedIDs: Set<MusicItemID> = []
    @State private var showDirectedSearch = false
    @State private var isDirectedSearchActive = false
    @State private var sortOrder = [KeyPathComparator(\ScanResultTableItem.title, comparator: .localizedStandard)]
    @State private var selectedResultID: MusicItemID?
    @State private var navigationPath = NavigationPath()
    @State private var resultsFilter = ResultsFilter()
    @State private var showFilterSheet = false

    private let maxSongsOptions = [0, 50, 100, 250, 500, 1000]

    /// All table items (unfiltered) — used for filter sheet dropdown values.
    private var allTableItems: [ScanResultTableItem] {
        scanResults.map { ScanResultTableItem(scanResult: $0, isCorrected: correctedIDs.contains($0.id)) }
    }

    /// Table items after filtering and sorting.
    private var tableItems: [ScanResultTableItem] {
        let items = allTableItems
        let filtered = resultsFilter.isActive ? resultsFilter.apply(to: items) : items
        return filtered.sorted(using: sortOrder)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isScanning {
                    ProgressView("Scanning library...")
                        .padding()
                } else if scanResults.isEmpty && (totalSongsScanned > 0 || isDirectedSearchActive) {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            isDirectedSearchActive ? "No Songs Found" : "No Issues Found",
                            systemImage: isDirectedSearchActive ? "magnifyingglass" : "checkmark.circle",
                            description: Text(
                                isDirectedSearchActive
                                    ? "No songs matched your search filters."
                                    : "Scanned \(totalSongsScanned) songs. All titles look clean."
                            )
                        )

                        HStack(spacing: 12) {
                            Button {
                                scanResults = []
                                totalSongsScanned = 0
                                isDirectedSearchActive = false
                                resultsFilter.clear() // Bug 0003: reset filter on new search
                            } label: {
                                Label("Start Over", systemImage: "arrow.uturn.backward")
                                    .frame(minWidth: 140)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            if isDirectedSearchActive {
                                Button {
                                    showDirectedSearch = true
                                } label: {
                                    Label("Search Again", systemImage: "text.magnifyingglass")
                                        .frame(minWidth: 140)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                    }
                } else if scanResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Music Library Scanner")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Scan your library for poorly tagged song titles.")
                            .foregroundStyle(.secondary)

                        Picker("Max Songs", selection: $maxSongs) {
                            ForEach(maxSongsOptions, id: \.self) { value in
                                Text(value == 0 ? "All" : "\(value)")
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 400)

                        Button {
                            Task { await runScan() }
                        } label: {
                            Label("Scan Library", systemImage: "magnifyingglass")
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)

                        Button {
                            showDirectedSearch = true
                        } label: {
                            Label("Directed Search", systemImage: "text.magnifyingglass")
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding()
                } else {
                    ResultsTableView(
                        items: tableItems,
                        selectedID: $selectedResultID,
                        sortOrder: $sortOrder
                    )
                    .navigationDestination(for: ScanResult.self) { result in
                        SongDetailView(result: result, allScanResults: scanResults) { ids in
                            correctedIDs.formUnion(ids)
                        }
                    }
                    .onChange(of: selectedResultID) { _, newID in
                        guard navigationPath.isEmpty,
                              let id = newID,
                              let result = scanResults.first(where: { $0.id == id }) else { return }
                        navigationPath.append(result)
                        selectedResultID = nil
                    }
                }
            }
            .navigationTitle("Tag Scanner")
            .toolbar {
                if !scanResults.isEmpty || totalSongsScanned > 0 || isDirectedSearchActive {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            scanResults = []
                            totalSongsScanned = 0
                            isDirectedSearchActive = false
                            resultsFilter.clear() // Bug 0003: reset filter on new search
                        } label: {
                            Label("New Search", systemImage: "magnifyingglass")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showDirectedSearch = true
                        } label: {
                            Label("Directed Search", systemImage: "text.magnifyingglass")
                        }
                    }
                    if !scanResults.isEmpty {
                        ToolbarItem(placement: .automatic) {
                            Button {
                                showFilterSheet = true
                            } label: {
                                Label("Filter", systemImage: resultsFilter.isActive
                                      ? "line.3.horizontal.decrease.circle.fill"
                                      : "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await runScan() }
                        } label: {
                            Label("Scan Again", systemImage: "arrow.clockwise")
                        }
                        .disabled(isScanning)
                    }
                }
            }
            .sheet(isPresented: $showDirectedSearch) {
                DirectedSearchSheet { filters in
                    showDirectedSearch = false
                    Task { await runDirectedSearch(filters: filters) }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                ResultsFilterSheet(filter: $resultsFilter, items: allTableItems)
            }
        }
    }

    private func runScan() async {
        isScanning = true
        isDirectedSearchActive = false
        scanResults = []
        resultsFilter.clear() // Bug 0003: reset filter on new search

        let songs = await fetchLibrarySongs(limit: maxSongs)
        totalSongsScanned = songs.count
        scanResults = TitleScanner.scanAll(songs)

        isScanning = false
    }

    private func runDirectedSearch(filters: [(field: SongFilterField, text: String)]) async {
        isScanning = true
        isDirectedSearchActive = true
        scanResults = []
        correctedIDs = []
        resultsFilter.clear() // Bug 0003: reset filter on new search

        // Genre filters still use MusicKit (relationship-based); string filters are applied locally.
        let genreFilters = filters.filter { $0.field == .genre }
        let stringFilters = filters.filter { $0.field != .genre }

        let songs = await fetchLibrarySongs(filters: genreFilters)
        totalSongsScanned = songs.count
        let allResults = TitleScanner.scanAllIncludingClean(songs)
        scanResults = DirectedSearchFilter.apply(allResults, filters: stringFilters)

        isScanning = false
    }

    /// Fetches songs from the user's library, optionally filtered by multiple AND-combined fields.
    /// - Parameters:
    ///   - filters: Array of (field, text) pairs. Each narrows results further (AND logic).
    ///   - limit: Maximum number of songs to return (0 means no limit).
    private func fetchLibrarySongs(
        filters: [(field: SongFilterField, text: String)] = [],
        limit: Int = 0
    ) async -> [Song] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            print("Music authorization denied: \(status)")
            return []
        }

        do {
            var request = MusicLibraryRequest<Song>()
            request.sort(by: \.title, ascending: true)
            if limit > 0 {
                request.limit = limit
            }

            for filter in filters {
                guard !filter.text.isEmpty else { continue }
                switch filter.field {
                case .name:
                    request.filter(matching: \.title, contains: filter.text)
                case .artist:
                    request.filter(matching: \.artistName, contains: filter.text)
                case .album:
                    request.filter(matching: \.albumTitle, contains: filter.text)
                case .genre:
                    var genreRequest = MusicLibraryRequest<Genre>()
                    genreRequest.filter(matching: \.name, contains: filter.text)
                    let genreResponse = try await genreRequest.response()
                    if let genre = genreResponse.items.first {
                        request.filter(matching: \.genres, contains: genre)
                    } else {
                        return []
                    }
                }
            }

            let response = try await request.response()
            print("Fetched \(response.items.count) songs from library")
            return Array(response.items)
        } catch {
            print("Failed to fetch library songs: \(error)")
            return []
        }
    }

}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
