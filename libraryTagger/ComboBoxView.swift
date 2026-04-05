//
//  ComboBoxView.swift
//  libraryTagger
//

import SwiftUI
import AppKit

/// A SwiftUI wrapper around NSComboBox for macOS.
/// Provides a dropdown populated with `items`, while allowing free-text input.
struct ComboBoxView: NSViewRepresentable {
    @Binding var text: String
    var items: [String]
    var placeholder: String = ""

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.isEditable = true
        comboBox.hasVerticalScroller = true
        comboBox.completes = true
        comboBox.numberOfVisibleItems = 8
        comboBox.placeholderString = placeholder
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.comboBoxValueChanged(_:))
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        comboBox.removeAllItems()
        comboBox.addItems(withObjectValues: items)
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: ComboBoxView

        init(_ parent: ComboBoxView) {
            self.parent = parent
        }

        @objc func comboBoxValueChanged(_ sender: NSComboBox) {
            parent.text = sender.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox,
                  comboBox.indexOfSelectedItem >= 0 else { return }
            parent.text = comboBox.itemObjectValue(at: comboBox.indexOfSelectedItem) as? String ?? ""
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }
    }
}
