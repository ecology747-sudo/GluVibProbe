//
//  UnitsSettingsSection.swift
//  GluVibProbe
//
//  Settings — Units Section
//  Purpose:
//  - Renders the unit selection section for glucose, distance, and body weight.
//
//  Data Flow (SSoT):
//  - SettingsView / SettingsDomain screen -> Binding values -> UnitsSettingsSection -> UI
//
//  Key Connections:
//  - GlucoseUnit
//  - DistanceUnit
//  - WeightUnit
//

import SwiftUI

struct UnitsSettingsSection: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var distanceUnit: DistanceUnit
    @Binding var weightUnit: WeightUnit

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let sectionSpacing: CGFloat = 18
    private let blockSpacing: CGFloat = 14

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {

            unitBlock( // 🟨 UPDATED
                title: String(
                    localized: "Blood Glucose",
                    defaultValue: "Blood Glucose",
                    comment: "Section title for blood glucose unit selection"
                ),
                accessibilityLabel: String(
                    localized: "Blood Glucose Unit",
                    defaultValue: "Blood Glucose Unit",
                    comment: "Accessibility label for blood glucose unit picker"
                )
            ) {
                Picker("", selection: $glucoseUnit) {
                    ForEach(GlucoseUnit.allCases) { unit in
                        Text(unit.label)
                            .font(segmentFont)
                            .tag(unit)
                    }
                }
            }

            unitBlock(
                title: String(
                    localized: "Distance",
                    defaultValue: "Distance",
                    comment: "Section title for distance unit selection"
                ),
                accessibilityLabel: String(
                    localized: "Distance Unit",
                    defaultValue: "Distance Unit",
                    comment: "Accessibility label for distance unit picker"
                )
            ) {
                Picker("", selection: $distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.label)
                            .font(segmentFont)
                            .tag(unit)
                    }
                }
            }

            unitBlock(
                title: String(
                    localized: "Body Weight",
                    defaultValue: "Body Weight",
                    comment: "Section title for body weight unit selection"
                ),
                accessibilityLabel: String(
                    localized: "Body Weight Unit",
                    defaultValue: "Body Weight Unit",
                    comment: "Accessibility label for body weight unit picker"
                )
            ) {
                Picker("", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.label)
                            .font(segmentFont)
                            .tag(unit)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    @ViewBuilder
    private func unitBlock<Content: View>(
        title: String,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: blockSpacing) {
            Text(title)
                .font(sectionTitleFont)
                .foregroundStyle(titleColor)

            content()
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(titleColor)
                .padding(.vertical, 2)
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("UnitsSettingsSection") {
    NavigationStack {
        Form {
            UnitsSettingsSection(
                glucoseUnit: .constant(.mgdL),
                distanceUnit: .constant(.kilometers),
                weightUnit: .constant(.kg)
            )
        }
        .tint(Color.Glu.systemForeground)
    }
}
