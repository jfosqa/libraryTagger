//
//  SongDetailView.swift
//  libraryTagger
//

import SwiftUI

struct SongDetailView: View {
    @State private var viewModel: SongDetailViewModel

    init(result: ScanResult) {
        _viewModel = State(initialValue: SongDetailViewModel(scanResult: result))
    }

    var body: some View {
        List {
            // MARK: Current Metadata
            Section("Current Metadata") {
                LabeledContent("Title", value: viewModel.scanResult.title)
                LabeledContent("Artist", value: viewModel.scanResult.artistName)
                if let album = viewModel.scanResult.albumTitle {
                    LabeledContent("Album", value: album)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(viewModel.scanResult.issues) { issue in
                            Text(issue.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(issue.color.opacity(0.15))
                                .foregroundStyle(issue.color)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // MARK: Search Query
            Section("Search Query") {
                LabeledContent("Cleaned Title", value: viewModel.cleanedTitle)
                if let parsed = viewModel.parsedArtist {
                    LabeledContent("Parsed Artist", value: parsed)
                }
                if viewModel.didSwapArtistAndTitle {
                    Label("Artist and title were swapped to find results.", systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // MARK: Discogs Results
            Section("Discogs Results") {
                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching Discogs...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else if viewModel.searchResults.isEmpty {
                    Text("No results found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.searchResults) { result in
                        Button {
                            Task { await viewModel.selectRelease(result) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let year = result.year, !year.isEmpty {
                                    Text(year)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Suggested Corrections
            if viewModel.isLoadingRelease {
                Section("Loading Release...") {
                    ProgressView()
                }
            } else if viewModel.selectedRelease != nil {
                Section("Suggested Corrections") {
                    if let title = viewModel.suggestedTitle {
                        CorrectionRow(
                            field: "Title",
                            current: viewModel.scanResult.title,
                            suggested: title
                        )
                    }
                    if let artist = viewModel.suggestedArtist {
                        CorrectionRow(
                            field: "Artist",
                            current: viewModel.scanResult.artistName,
                            suggested: artist
                        )
                    }
                    if let album = viewModel.suggestedAlbum {
                        CorrectionRow(
                            field: "Album",
                            current: viewModel.scanResult.albumTitle ?? "—",
                            suggested: album
                        )
                    }
                    if viewModel.matchedTrack == nil {
                        Text("Could not match a specific track in this release.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // MARK: Release Tracklist
                if let tracklist = viewModel.selectedRelease?.tracklist,
                   !tracklist.isEmpty {
                    Section("Release Tracklist") {
                        ForEach(tracklist) { track in
                            HStack {
                                Text(track.position)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .leading)
                                Text(track.title)
                                    .font(.subheadline)
                                Spacer()
                                Text(track.duration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Song Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await viewModel.search()
        }
    }
}
