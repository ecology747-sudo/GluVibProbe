//
//  UnitsSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Globale Units-Settings (Glucose, Distance, Weight)
///
/// - Kein eigener Domain-Farbcode (Units gelten für alle Domains)
/// - Verwendet Primary Blue als Akzentfarbe
/// - Optik analog zu ActivitySettingsSection / NutritionSettingsSection
struct UnitsSettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var distanceUnit: DistanceUnit
    @Binding var weightUnit: WeightUnit
    // @Binding var energyUnit: EnergyUnit                         // !!! REMOVED

    // MARK: - Body

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {                                 // !!! UPDATED

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

                // ENERGY UNIT
                // !!! REMOVED (kJ vollständig entfernt; Energie ist immer kcal)

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

                // !!! UPDATED: Height Unit wurde entfernt (nicht mehr benötigt)
            }
            .padding(16)
            // !!! UPDATED: leichte Units-Tönung innen (ohne eigenen Stroke)
            .background(                                                              // !!! UPDATED
                RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous) // !!! UPDATED
                    .fill(Color.Glu.primaryBlue.opacity(0.03))                        // !!! UPDATED
            )
            // !!! UPDATED: zentraler Card-Style (Stroke-Dicke + Highlight + Shadow)
            .gluVibCardFrame(domainColor: Color.Glu.primaryBlue)                      // !!! UPDATED
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
                weightUnit: .constant(.kg)
            )
        }
    }
}
