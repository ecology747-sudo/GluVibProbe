//
//  UnitsSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Globale Units-Settings (Glucose, Distance, Weight, Height)
///
/// - Kein eigener Domain-Farbcode (Units gelten für alle Domains)
/// - Verwendet Primary Blue als Akzentfarbe
/// - Optik analog zu ActivitySettingsSection / NutritionSettingsSection
struct UnitsSettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var distanceUnit: DistanceUnit
    @Binding var weightUnit: WeightUnit
    @Binding var heightUnit: HeightUnit

    // MARK: - Body

    var body: some View {
        Section {
            ZStack {
                // Hintergrundkarte
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.primaryBlue.opacity(0.03))

                // Rahmen
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.primaryBlue.opacity(0.20), lineWidth: 1)

                VStack(alignment: .leading, spacing: 16) {


                    // BLOOD GLUCOSE UNIT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Blood Glucose")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        Picker("", selection: $glucoseUnit) {
                            ForEach(GlucoseUnit.allCases) { unit in
                                Text(unit.label)
                                    .foregroundColor(Color.Glu.primaryBlue)
                                    .tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // DISTANCE UNIT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Distance")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        Picker("", selection: $distanceUnit) {
                            ForEach(DistanceUnit.allCases) { unit in
                                Text(unit.label)
                                    .foregroundColor(Color.Glu.primaryBlue)
                                    .tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // WEIGHT UNIT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body Weight Unit")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        Picker("", selection: $weightUnit) {
                            ForEach(WeightUnit.allCases) { unit in
                                Text(unit.label)
                                    .foregroundColor(Color.Glu.primaryBlue)
                                    .tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // HEIGHT UNIT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body Height Unit")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        Picker("", selection: $heightUnit) {
                            ForEach(HeightUnit.allCases) { unit in
                                Text(unit.label)
                                    .foregroundColor(Color.Glu.primaryBlue)
                                    .tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

// MARK: - Preview

#Preview("UnitsSettingsSection") {
    NavigationStack {
        Form {
            UnitsSettingsSection(
                glucoseUnit: .constant(.mgdL),
                distanceUnit: .constant(.kilometers),
                weightUnit: .constant(.kg),
                heightUnit: .constant(.cm)
            )
        }
    }
}
