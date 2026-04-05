//
//  SongDetailView.swift
//  libraryTagger
//

import SwiftUI
import MusicKit

struct SongDetailView: View {
    @State private var viewModel: SongDetailViewModel
    @State private var currentIndex: Int
    var onCorrectionApplied: ((Set<MusicItemID>) -> Void)?

    private let allScanResults: [ScanResult]

    init(result: ScanResult,
         allScanResults: [ScanResult] = [],
         onCorrectionApplied: ((Set<MusicItemID>) -> Void)? = nil) {
        self.allScanResults = allScanResults
        let index = allScanResults.firstIndex(where: { $0.id == result.id }) ?? 0
        _currentIndex = State(initialValue: index)
        _viewModel = State(initialValue: SongDetailViewModel(
            scanResult: result,
            allScanResults: allScanResults
        ))
        self.onCorrectionApplied = onCorrectionApplied
    }

    private var hasPrevious: Bool { currentIndex > 0 }
    private var hasNext: Bool { currentIndex < allScanResults.count - 1 }

    private func navigateTo(index: Int) {
        guard index >= 0, index < allScanResults.count else { return }
        currentIndex = index
        viewModel = SongDetailViewModel(
            scanResult: allScanResults[index],
            allScanResults: allScanResults
        )
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

            // MARK: Apply Cleaned Data (no Discogs match needed)
            if viewModel.selectedRelease == nil,
               !viewModel.isSearching,
               let cleaned = viewModel.cleanedCorrection {
                Section("Apply Cleaned Data") {
                    if let title = cleaned.title {
                        CorrectionRow(
                            field: "Title",
                            current: viewModel.scanResult.title,
                            suggested: title
                        )
                    }
                    if let artist = cleaned.artist {
                        CorrectionRow(
                            field: "Artist",
                            current: viewModel.scanResult.artistName,
                            suggested: artist
                        )
                    }

                    if viewModel.didApplySuccessfully {
                        Label("Corrections applied successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if let error = viewModel.applyError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }

                    Button {
                        viewModel.applyCleaned()
                        if viewModel.didApplySuccessfully {
                            onCorrectionApplied?(Set([viewModel.scanResult.id]))
                        }
                    } label: {
                        HStack {
                            if viewModel.isApplying {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Label(
                                viewModel.didApplySuccessfully ? "Applied" : "Apply Cleaned Data",
                                systemImage: viewModel.didApplySuccessfully ? "checkmark" : "wand.and.stars"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.didApplySuccessfully ? .gray : .accentColor)
                    .disabled(viewModel.isApplying || viewModel.didApplySuccessfully)
                }
            }

            // MARK: Suggested Corrections
            if viewModel.isLoadingRelease {
                Section("Loading Release...") {
                    ProgressView()
                }
            } else if viewModel.selectedRelease != nil {
                Section("Suggested Corrections") {
                    if let correction = viewModel.pendingCorrection {
                        if let title = correction.title {
                            CorrectionRow(
                                field: "Title",
                                current: viewModel.scanResult.title,
                                suggested: title
                            )
                        }
                        if let artist = correction.artist {
                            CorrectionRow(
                                field: "Artist",
                                current: viewModel.scanResult.artistName,
                                suggested: artist
                            )
                        }
                        if let album = correction.album {
                            CorrectionRow(
                                field: "Album",
                                current: viewModel.scanResult.albumTitle ?? "—",
                                suggested: album
                            )
                        }
                    } else if viewModel.matchedTrack != nil {
                        Text("All fields already match this release.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if viewModel.matchedTrack == nil {
                        Text("Could not match a specific track in this release.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // MARK: Other Album Tracks
                if !viewModel.siblingCorrections.isEmpty {
                    Section {
                        ForEach($viewModel.siblingCorrections) { $sibling in
                            Toggle(isOn: $sibling.isIncluded) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sibling.scanResult.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    if let track = sibling.matchedTrack {
                                        Text(track.title)
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("No match found")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(sibling.correction == nil)
                        }
                    } header: {
                        let selected = viewModel.siblingCorrections.filter { $0.isIncluded && $0.correction != nil }.count
                        Text("Other Album Tracks (\(selected) selected)")
                    }
                }

                // MARK: Apply Corrections
                Section {
                    if viewModel.didApplySuccessfully {
                        Label("Corrections applied successfully!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if let error = viewModel.applyError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }

                    let includedSiblings = viewModel.siblingCorrections.filter { $0.isIncluded && $0.correction != nil }
                    let hasSiblings = !includedSiblings.isEmpty
                    let totalCount = (viewModel.pendingCorrection != nil ? 1 : 0) + includedSiblings.count

                    Button {
                        if hasSiblings {
                            let correctedIDs = viewModel.applyAllCorrections()
                            if !correctedIDs.isEmpty {
                                onCorrectionApplied?(correctedIDs)
                            }
                        } else {
                            viewModel.applyCorrections()
                            if viewModel.didApplySuccessfully {
                                onCorrectionApplied?(Set([viewModel.scanResult.id]))
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isApplying {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Label(
                                viewModel.didApplySuccessfully
                                    ? "Applied"
                                    : (hasSiblings ? "Apply All (\(totalCount) tracks)" : "Apply Corrections"),
                                systemImage: viewModel.didApplySuccessfully ? "checkmark" : "wand.and.stars"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.didApplySuccessfully ? .gray : .accentColor)
                    .disabled(
                        (viewModel.pendingCorrection == nil && !hasSiblings) ||
                        viewModel.isApplying ||
                        viewModel.didApplySuccessfully
                    )
                }

                // MARK: Release Tracklist
                if let tracklist = viewModel.selectedRelease?.tracklist,
                   !tracklist.isEmpty {
                    Section {
                        ForEach(tracklist) { track in
                            let isSelected = viewModel.matchedTrack?.id == track.id
                            Button {
                                viewModel.selectTrack(track)
                            } label: {
                                HStack {
                                    Text(track.position)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.subheadline)
                                            .foregroundStyle(isSelected ? .green : .primary)
                                        if let trackArtist = track.artistName {
                                            Text(trackArtist)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(track.duration)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Release Tracklist — tap to select track")
                    }
                }
            }
        }
        .navigationTitle("Song Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task(id: currentIndex) {
            await viewModel.search()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    navigateTo(index: currentIndex - 1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(!hasPrevious)

                Text("\(currentIndex + 1) / \(allScanResults.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button {
                    navigateTo(index: currentIndex + 1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(!hasNext)
            }
        }
    }
}
