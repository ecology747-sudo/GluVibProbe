//
//  SettingsButtonBar.swift
//  GluVibProbe
//

import SwiftUI

// MARK: - Save Button State

enum SettingsSaveButtonState {
    case idle
    case saving
    case saved
}

// MARK: - Component

struct SettingsButtonBar: View {

    let saveButtonState: SettingsSaveButtonState
    let hasUnsavedChanges: Bool

    let onSaveTapped: () -> Void
    let onUndoTapped: () -> Void

    var body: some View {
        HStack(spacing: 26) {
            if hasUnsavedChanges {
                // SAVE + CANCEL nebeneinander
                Button(action: onSaveTapped) {
                    actionLabel(title: buttonText, isPrimary: true)
                }

                Button(action: onUndoTapped) {
                    actionLabel(title: "Cancel", isPrimary: false)
                }
            } else {
                // Nur SAVE, gleiche Größe wie oben,
                // weil der Label-Inhalt identisch ist
                Button(action: onSaveTapped) {
                    actionLabel(title: buttonText, isPrimary: true)
                }
            }
        }
        .buttonStyle(.plain)                 // wichtig: kein GluVibPrimaryButtonStyle hier
        .frame(maxWidth: .infinity)         // zentriert in der Breite
        .padding(.horizontal, 34)
        .padding(.vertical, 19)
    }

    // MARK: - Label im Domain-Picker-Stil

    private func actionLabel(title: String, isPrimary: Bool) -> some View {
        let color = Color.Glu.primaryBlue

        return Text(title)
            .font(.body.weight(.semibold))    // ⬆️ etwas größere, klare Schrift
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(.vertical, 8)            // ⬆️ größer, aber nicht massiv
            .padding(.horizontal, 22)         // ⬆️ breitere Kapsel
            .background(
                Capsule()
                    .fill(
                        isPrimary
                        ? color.opacity(0.15) // leicht stärkere Füllung
                        : color.opacity(0.0)  // Cancel nur Rahmen
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        color.opacity(isPrimary ? 1.0 : 0.7),
                        lineWidth: 1
                    )
            )
            .foregroundColor(color)
    }

    // MARK: - Save Button Text Wrapper

    private var buttonText: String {
        switch saveButtonState {
        case .idle:   return "Save"
        case .saving: return "Saving…"
        case .saved:  return "Saved"
        }
    }
}

// MARK: - Preview

#Preview("SettingsButtonBar – Save + Cancel") {
    SettingsButtonBar(
        saveButtonState: .idle,
        hasUnsavedChanges: true,
        onSaveTapped: {},
        onUndoTapped: {}
    )
    .padding()
}

#Preview("SettingsButtonBar – nur Save") {
    SettingsButtonBar(
        saveButtonState: .idle,
        hasUnsavedChanges: false,
        onSaveTapped: {},
        onUndoTapped: {}
    )
    .padding()
}
