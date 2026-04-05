//
//  DirectedSearchSheet.swift
//  libraryTagger
//

import SwiftUI

struct SearchFilter: Identifiable {
    let id = UUID()
    var field: SongFilterField = .artist
    var text: String = ""
}

struct DirectedSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var filters: [SearchFilter] = [SearchFilter()]

    /// Callback delivering active filters back to ContentView.
    var onSearch: ([(field: SongFilterField, text: String)]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Search Filters") {
                    ForEach($filters) { $filter in
                        HStack(spacing: 8) {
                            Picker("Field", selection: $filter.field) {
                                ForEach(SongFilterField.allCases) { field in
                                    Text(field.rawValue).tag(field)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)

                            TextField("Contains...", text: $filter.text)
                                .textFieldStyle(.roundedBorder)

                            if filters.count > 1 {
                                Button {
                                    filters.removeAll { $0.id == filter.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if filters.count < 3 {
                        Button {
                            filters.append(SearchFilter())
                        } label: {
                            Label("Add Filter", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    Text("All matching songs will be shown, including those with no tag issues.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .navigationTitle("Directed Search")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Search") {
                    let activeFilters = filters
                        .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
                        .map { (field: $0.field, text: $0.text.trimmingCharacters(in: .whitespaces)) }
                    onSearch(activeFilters)
                }
                .disabled(!hasValidFilter)
            }
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 250, idealHeight: 300)
    }

    private var hasValidFilter: Bool {
        filters.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
