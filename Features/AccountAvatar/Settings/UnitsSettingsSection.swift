//
//  UnitsSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

struct UnitsSettingsSection: View {

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var distanceUnit: DistanceUnit
    @Binding var weightUnit: WeightUnit

    private let titleColor: Color = Color.Glu.primaryBlue
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let blockSpacing: CGFloat = 14

    var body: some View {
        // UPDATED: no custom card frame / no rounded background
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: blockSpacing) {
                Text("Blood Glucose")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Picker("", selection: $glucoseUnit) {
                    ForEach(GlucoseUnit.allCases) { unit in
                        Text(unit.label)
                            .font(segmentFont)
                            .tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(titleColor)
                .padding(.vertical, 2)
                .accessibilityLabel("Blood Glucose Unit")
            }

            VStack(alignment: .leading, spacing: blockSpacing) {
                Text("Distance")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Picker("", selection: $distanceUnit) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.label)
                            .font(segmentFont)
                            .tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(titleColor)
                .padding(.vertical, 2)
                .accessibilityLabel("Distance Unit")
            }

            VStack(alignment: .leading, spacing: blockSpacing) {
                Text("Body Weight")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Picker("", selection: $weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.label)
                            .font(segmentFont)
                            .tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(titleColor)
                .padding(.vertical, 2)
                .accessibilityLabel("Body Weight Unit")
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview("UnitsSettingsSection") {
    NavigationStack {
        Form {
            UnitsSettingsSection(
                glucoseUnit: .constant(.mgdL),
                distanceUnit: .constant(.kilometers),
                weightUnit: .constant(.kg)
            )
        }
        .tint(Color.Glu.primaryBlue)
    }
}
