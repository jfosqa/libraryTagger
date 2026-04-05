//
//  ResultsFilter.swift
//  libraryTagger
//

import Foundation

struct ResultsFilter: Equatable {
    var titlePattern: String = ""
    var titleEnabled: Bool = false

    var artistPattern: String = ""
    var artistEnabled: Bool = false

    var albumPattern: String = ""
    var albumEnabled: Bool = false

    var selectedAlerts: Set<TagIssue> = []
    var alertsEnabled: Bool = false

    var correctionStatus: CorrectionStatusFilter = .all
    var correctionStatusEnabled: Bool = false

    enum CorrectionStatusFilter: String, CaseIterable, Equatable {
        case all = "All"
        case corrected = "Corrected"
        case needsCorrection = "Needs Correction"
    }

    /// True when at least one filter is enabled with meaningful criteria.
    var isActive: Bool {
        (titleEnabled && !titlePattern.isEmpty) ||
        (artistEnabled && !artistPattern.isEmpty) ||
        (albumEnabled && !albumPattern.isEmpty) ||
        (alertsEnabled && !selectedAlerts.isEmpty) ||
        (correctionStatusEnabled && correctionStatus != .all)
    }

    /// Reset all filters to defaults.
    mutating func clear() {
        self = ResultsFilter()
    }

    /// Apply this filter to an array of table items. Enabled filters are ANDed.
    /// Alert filter uses OR logic (item matches if it has ANY of the selected alerts).
    func apply(to items: [ScanResultTableItem]) -> [ScanResultTableItem] {
        items.filter { item in
            if titleEnabled, !titlePattern.isEmpty {
                guard WildcardMatcher.matches(text: item.title, pattern: titlePattern) else { return false }
            }
            if artistEnabled, !artistPattern.isEmpty {
                guard WildcardMatcher.matches(text: item.artistName, pattern: artistPattern) else { return false }
            }
            if albumEnabled, !albumPattern.isEmpty {
                guard WildcardMatcher.matches(text: item.albumTitle, pattern: albumPattern) else { return false }
            }
            if alertsEnabled, !selectedAlerts.isEmpty {
                guard item.issues.contains(where: { selectedAlerts.contains($0) }) else { return false }
            }
            if correctionStatusEnabled {
                switch correctionStatus {
                case .all: break
                case .corrected: guard item.isCorrected else { return false }
                case .needsCorrection: guard !item.isCorrected else { return false }
                }
            }
            return true
        }
    }
}
