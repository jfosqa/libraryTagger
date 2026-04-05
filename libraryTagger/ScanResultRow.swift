//
//  ScanResultRow.swift
//  libraryTagger
//

import SwiftUI

struct ScanResultRow: View {
    let result: ScanResult
    var isCorrected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                if isCorrected {
                    Spacer()
                    Label("Corrected", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }

            Text(result.artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                if result.issues.isEmpty {
                    Text("No Issues")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else {
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
        .opacity(isCorrected ? 0.6 : 1.0)
    }

}
