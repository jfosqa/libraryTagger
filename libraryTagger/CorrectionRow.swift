//
//  CorrectionRow.swift
//  libraryTagger
//

import SwiftUI

struct CorrectionRow: View {
    let field: String
    let current: String
    let suggested: String

    private var isDifferent: Bool {
        current.localizedCaseInsensitiveCompare(suggested) != .orderedSame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isDifferent {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(current)
                            .font(.subheadline)
                            .strikethrough()
                            .foregroundStyle(.red)
                        Text(suggested)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Text(current)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Already correct")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}
