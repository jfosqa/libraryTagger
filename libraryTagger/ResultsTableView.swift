//
//  ResultsTableView.swift
//  libraryTagger
//

import SwiftUI
import MusicKit

struct ResultsTableView: View {
    var items: [ScanResultTableItem]
    @Binding var selectedID: MusicItemID?
    @Binding var sortOrder: [KeyPathComparator<ScanResultTableItem>]

    var body: some View {
        Table(items, selection: $selectedID, sortOrder: $sortOrder) {
            TableColumn("Title", sortUsing: KeyPathComparator(\.title, comparator: .localizedStandard)) { item in
                Text(item.title)
                    .lineLimit(2)
            }
            .width(min: 150, ideal: 250)

            TableColumn("Artist", sortUsing: KeyPathComparator(\.artistName, comparator: .localizedStandard)) { item in
                Text(item.artistName)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Album", sortUsing: KeyPathComparator(\.albumTitle, comparator: .localizedStandard)) { item in
                Text(item.albumTitle)
                    .foregroundStyle(item.albumTitle.isEmpty ? .tertiary : .primary)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Alerts", sortUsing: KeyPathComparator(\.alertCount)) { item in
                HStack(spacing: 4) {
                    if item.issues.isEmpty {
                        Text("No Issues")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    } else {
                        ForEach(item.issues) { issue in
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
            .width(min: 100, ideal: 250)

            TableColumn("Status", sortUsing: KeyPathComparator(\.correctionSortValue)) { item in
                if item.isCorrected {
                    Label("Corrected", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                } else {
                    Label("Needs Correction", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
            .width(min: 80, ideal: 140)
        }
    }
}
