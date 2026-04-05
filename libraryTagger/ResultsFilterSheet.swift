//
//  ResultsFilterSheet.swift
//  libraryTagger
//

import SwiftUI
import MusicKit

struct ResultsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The live filter binding — only written on Apply.
    @Binding var filter: ResultsFilter

    /// Local editing copy so Cancel discards changes.
    @State private var editingFilter: ResultsFilter

    // Unique values for combo box dropdowns, computed once at init.
    let uniqueTitles: [String]
    let uniqueArtists: [String]
    let uniqueAlbums: [String]
    let presentAlerts: [TagIssue]

    init(filter: Binding<ResultsFilter>, items: [ScanResultTableItem]) {
        _filter = filter
        _editingFilter = State(initialValue: filter.wrappedValue)
        self.uniqueTitles = Array(Set(items.map(\.title))).sorted()
        self.uniqueArtists = Array(Set(items.map(\.artistName))).sorted()
        self.uniqueAlbums = Array(Set(items.map(\.albumTitle).filter { !$0.isEmpty })).sorted()
        self.presentAlerts = TagIssue.allCases.filter { issue in
            items.contains { $0.issues.contains(issue) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // MARK: Title filter
                Section {
                    Toggle("Enable", isOn: $editingFilter.titleEnabled)
                    ComboBoxView(
                        text: $editingFilter.titlePattern,
                        items: uniqueTitles,
                        placeholder: "Title pattern (* for wildcard)"
                    )
                    .frame(height: 24)
                    .disabled(!editingFilter.titleEnabled)
                } header: {
                    Text("Title")
                }

                // MARK: Artist filter
                Section {
                    Toggle("Enable", isOn: $editingFilter.artistEnabled)
                    ComboBoxView(
                        text: $editingFilter.artistPattern,
                        items: uniqueArtists,
                        placeholder: "Artist pattern (* for wildcard)"
                    )
                    .frame(height: 24)
                    .disabled(!editingFilter.artistEnabled)
                } header: {
                    Text("Artist")
                }

                // MARK: Album filter
                Section {
                    Toggle("Enable", isOn: $editingFilter.albumEnabled)
                    ComboBoxView(
                        text: $editingFilter.albumPattern,
                        items: uniqueAlbums,
                        placeholder: "Album pattern (* for wildcard)"
                    )
                    .frame(height: 24)
                    .disabled(!editingFilter.albumEnabled)
                } header: {
                    Text("Album")
                }

                // MARK: Alerts filter
                Section {
                    Toggle("Enable", isOn: $editingFilter.alertsEnabled)
                    ForEach(presentAlerts) { alert in
                        Toggle(alert.rawValue, isOn: alertBinding(for: alert))
                            .disabled(!editingFilter.alertsEnabled)
                            .foregroundStyle(editingFilter.alertsEnabled ? alert.color : .secondary)
                    }
                    if presentAlerts.isEmpty {
                        Text("No alerts in current results")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Alerts")
                }

                // MARK: Correction Status filter
                Section {
                    Toggle("Enable", isOn: $editingFilter.correctionStatusEnabled)
                    Picker("Status", selection: $editingFilter.correctionStatus) {
                        ForEach(ResultsFilter.CorrectionStatusFilter.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .disabled(!editingFilter.correctionStatusEnabled)
                } header: {
                    Text("Correction Status")
                }
            }
            .formStyle(.grouped)

            // MARK: Buttons
            HStack {
                Button("Clear") {
                    editingFilter = ResultsFilter()
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Apply") {
                    filter = editingFilter
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .navigationTitle("Filter Results")
        .frame(minWidth: 450, idealWidth: 500, minHeight: 500, idealHeight: 600)
    }

    private func alertBinding(for issue: TagIssue) -> Binding<Bool> {
        Binding(
            get: { editingFilter.selectedAlerts.contains(issue) },
            set: { isOn in
                if isOn {
                    editingFilter.selectedAlerts.insert(issue)
                } else {
                    editingFilter.selectedAlerts.remove(issue)
                }
            }
        )
    }
}
