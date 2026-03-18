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

    private let maxSongsOptions = [0, 50, 100, 250, 500, 1000]

    var body: some View {
        NavigationStack {
            Group {
                if isScanning {
                    ProgressView("Scanning library...")
                        .padding()
                } else if scanResults.isEmpty && totalSongsScanned > 0 {
                    ContentUnavailableView(
                        "No Issues Found",
                        systemImage: "checkmark.circle",
                        description: Text("Scanned \(totalSongsScanned) songs. All titles look clean.")
                    )
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
                    }
                    .padding()
                } else {
                    List(scanResults) { result in
                        NavigationLink(value: result) {
                            ScanResultRow(result: result)
                        }
                    }
                    .navigationDestination(for: ScanResult.self) { result in
                        SongDetailView(result: result)
                    }
                }
            }
            .navigationTitle("Tag Scanner")
            .toolbar {
                if !scanResults.isEmpty || totalSongsScanned > 0 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            scanResults = []
                            totalSongsScanned = 0
                        } label: {
                            Label("New Search", systemImage: "magnifyingglass")
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
        }
    }

    private func runScan() async {
        isScanning = true
        scanResults = []

        let songs = await fetchLibrarySongs(limit: maxSongs)
        totalSongsScanned = songs.count
        scanResults = TitleScanner.scanAll(songs)

        isScanning = false
    }

    /// Fetches songs from the user's library, optionally filtered by a field and search text.
    /// - Parameters:
    ///   - field: The song property to filter on (nil fetches all songs).
    ///   - searchText: The text to match against the chosen field.
    ///   - limit: Maximum number of songs to return (0 means no limit).
    private func fetchLibrarySongs(filterBy field: SongFilterField? = nil, searchText: String = "", limit: Int = 0) async -> [Song] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            print("Music authorization denied: \(status)")
            return []
        }

        do {
            var request = MusicLibraryRequest<Song>()
            request.sort(by: \.title, ascending: true)
            request.limit = limit

            if let field, !searchText.isEmpty {
                switch field {
                case .name:
                    request.filter(matching: \.title, contains: searchText)
                case .artist:
                    request.filter(matching: \.artistName, contains: searchText)
                case .album:
                    request.filter(matching: \.albumTitle, contains: searchText)
                case .genre:
                    // Genre filtering requires fetching a Genre object first,
                    // then using it with the relationship filter.
                    var genreRequest = MusicLibraryRequest<Genre>()
                    genreRequest.filter(matching: \.name, contains: searchText)
                    let genreResponse = try await genreRequest.response()
                    if let genre = genreResponse.items.first {
                        request.filter(matching: \.genres, contains: genre)
                    } else {
                        // No matching genre found — return empty results
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
