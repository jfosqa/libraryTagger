//
//  ScanResultRow.swift
//  libraryTagger
//

import SwiftUI

struct ScanResultRow: View {
    let result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.headline)
                .lineLimit(2)

            Text(result.artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(result.issues) { issue in
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
        .padding(.vertical, 4)
    }

}
