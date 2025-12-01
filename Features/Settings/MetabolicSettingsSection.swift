//
//  MetabolicSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: METABOLIC – Glucose-Ziele & Schwellen
///
/// - Optik wie ActivitySettingsSection (Karte mit Rand)
/// - Nutzt die Domain-Farbe: Color.Glu.metabolicDomain
/// - Alle Texte in Glu-primaryBlue
struct MetabolicSettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var glucoseMin: Int
    @Binding var glucoseMax: Int
    @Binding var veryLowLimit: Int
    @Binding var veryHighLimit: Int

    // MARK: - Hilfsfunktionen mg/dL <-> mmol/L

    private func mgToMmol(_ mg: Int) -> Double {
        Double(mg) / 18.0
    }

    private func mmolToMg(_ mmol: Double) -> Int {
        Int((mmol * 18.0).rounded())
    }

    // MARK: - Anzeige TIR

    private var tirMinDisplay: String {
        if glucoseUnit == .mgdL {
            return "\(glucoseMin)"
        } else {
            return String(format: "%.1f", mgToMmol(glucoseMin))
        }
    }

    private var tirMaxDisplay: String {
        if glucoseUnit == .mgdL {
            return "\(glucoseMax)"
        } else {
            return String(format: "%.1f", mgToMmol(glucoseMax))
        }
    }

    // MARK: - Anzeige Very Low / High

    private var veryLowLineText: String {
        if glucoseUnit == .mgdL {
            return "< \(veryLowLimit) \(glucoseUnit.label)"
        } else {
            return String(
                format: "< %.1f %@",
                mgToMmol(veryLowLimit),
                glucoseUnit.label
            )
        }
    }

    private var veryHighLineText: String {
        if glucoseUnit == .mgdL {
            return "> \(veryHighLimit) \(glucoseUnit.label)"
        } else {
            return String(
                format: "> %.1f %@",
                mgToMmol(veryHighLimit),
                glucoseUnit.label
            )
        }
    }

    // MARK: - Body

    var body: some View {
        Section {
            ZStack {
                // Hintergrundkarte in Metabolic-Farbe
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.metabolicDomain.opacity(0.06))

                // Rahmen in Metabolic-Farbe
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.metabolicDomain.opacity(0.7), lineWidth: 1)

                VStack(alignment: .leading, spacing: 16) {


                    // MARK: Glucose Target Range (TIR)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Glucose Target Range")
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)

                            Spacer()

                            Text("\(tirMinDisplay)–\(tirMaxDisplay) \(glucoseUnit.label)")
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)
                        }

                        RangeSlider(
                            lowerValue: Binding(
                                get: {
                                    glucoseUnit == .mgdL
                                    ? Double(glucoseMin)
                                    : mgToMmol(glucoseMin)
                                },
                                set: { newVal in
                                    if glucoseUnit == .mgdL {
                                        glucoseMin = min(Int(newVal.rounded()), glucoseMax)
                                    } else {
                                        let mg = mmolToMg(newVal)
                                        glucoseMin = min(mg, glucoseMax)
                                    }
                                }
                            ),
                            upperValue: Binding(
                                get: {
                                    glucoseUnit == .mgdL
                                    ? Double(glucoseMax)
                                    : mgToMmol(glucoseMax)
                                },
                                set: { newVal in
                                    if glucoseUnit == .mgdL {
                                        glucoseMax = max(Int(newVal.rounded()), glucoseMin)
                                    } else {
                                        let mg = mmolToMg(newVal)
                                        glucoseMax = max(mg, glucoseMin)
                                    }
                                }
                            ),
                            range: glucoseUnit == .mgdL
                            ? 50.0...300.0
                            : 2.775...16.65,
                            minGap: glucoseUnit == .mgdL
                            ? 25.0
                            : 1.5
                        )
                        .frame(height: 40)
                    }

                    // MARK: Very Low / Very High Thresholds

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Very Low / Very High Glucose Thresholds")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        LowerUpperRangeGlucoseSlider(
                            lowerValue: Binding(
                                get: {
                                    glucoseUnit == .mgdL
                                    ? Double(veryLowLimit)
                                    : mgToMmol(veryLowLimit)
                                },
                                set: { newVal in
                                    if glucoseUnit == .mgdL {
                                        veryLowLimit = min(Int(newVal.rounded()), veryHighLimit)
                                    } else {
                                        let mg = mmolToMg(newVal)
                                        veryLowLimit = min(mg, veryHighLimit)
                                    }
                                }
                            ),
                            upperValue: Binding(
                                get: {
                                    glucoseUnit == .mgdL
                                    ? Double(veryHighLimit)
                                    : mgToMmol(veryHighLimit)
                                },
                                set: { newVal in
                                    if glucoseUnit == .mgdL {
                                        veryHighLimit = max(Int(newVal.rounded()), veryLowLimit)
                                    } else {
                                        let mg = mmolToMg(newVal)
                                        veryHighLimit = max(mg, veryLowLimit)
                                    }
                                }
                            ),
                            range: glucoseUnit == .mgdL
                            ? 40.0...400.0
                            : 2.2...22.2,
                            minGap: glucoseUnit == .mgdL
                            ? 25.0
                            : 1.5
                        )
                        .frame(height: 40)

                        HStack {
                            Text("Very Low Glucose")
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)
                            Spacer()
                            Text(veryLowLineText)
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)
                        }

                        HStack {
                            Text("Very High Glucose")
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)
                            Spacer()
                            Text(veryHighLineText)
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)
                        }
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

#Preview("MetabolicSettingsSection") {
    NavigationStack {
        Form {
            MetabolicSettingsSection(
                glucoseUnit:   .constant(.mgdL),
                glucoseMin:    .constant(70),
                glucoseMax:    .constant(180),
                veryLowLimit:  .constant(55),
                veryHighLimit: .constant(250)
            )
        }
    }
}
