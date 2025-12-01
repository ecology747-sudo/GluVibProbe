//
//  BodySettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: BODY – Personal & Körperdaten
///
/// - Nutzt die Domain-Farbe: Color.Glu.bodyAccent (Orange)
/// - Gleiche Karten-Optik wie ActivitySettingsSection
/// - Zeigt nur Body-Werte (Gender, Birth Date, Height, Weight, Target Weight)
/// - Units (kg/lbs, cm/ft+in) werden nur zur Anzeige verwendet
struct BodySettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var gender: String
    @Binding var birthDate: Date

    /// Körpergröße in cm (Basis)
    @Binding var heightCm: Int

    /// Aktuelles Körpergewicht in kg (Basis)
    @Binding var weightKg: Int

    /// Zielgewicht in kg (Basis)
    @Binding var targetWeightKg: Int

    /// Nur zur Anzeige / Umrechnung, Units werden außerhalb geändert
    let heightUnit: HeightUnit
    let weightUnit: WeightUnit

    // MARK: - Date Range (1920...heute)

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 1920
        components.month = 1
        components.day = 1
        let start = calendar.date(from: components) ?? Date.distantPast
        return start...Date()
    }

    // MARK: - Helpers Height

    /// Anzeige-Text für eine gegebene Körpergröße in cm
    private func heightLabel(for cm: Int) -> String {
        switch heightUnit {
        case .cm:
            return "\(cm) cm"
        case .feetInches:
            let totalInches = Int((Double(cm) / 2.54).rounded())
            let feet = totalInches / 12
            let inches = totalInches % 12
            return "\(feet) ft \(inches) in"
        }
    }

    // MARK: - Helpers Weight

    /// Anzeige-Text für ein Gewicht in kg
    private func weightLabel(for kg: Int) -> String {
        switch weightUnit {
        case .kg:
            return "\(kg) kg"
        case .lbs:
            let lbs = Int((Double(kg) * 2.20462).rounded())
            return "\(lbs) lbs"
        }
    }

    // MARK: - Body

    var body: some View {
        Section {
            ZStack {
                // Hintergrund-Karte (leicht getönt)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.bodyAccent.opacity(0.20))

                // Rahmen der Body-Karte
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.bodyAccent.opacity(0.7), lineWidth: 1)

                VStack(alignment: .leading, spacing: 16) {

                    

                    // GENDER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()
                            Picker("", selection: $gender) {
                                Text("Male").tag("Male")
                                Text("Female").tag("Female")
                                Text("Other").tag("Other")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 220)
                        }
                    }

                    // BIRTH DATE
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birth Date")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()
                            DatePicker(
                                "",
                                selection: $birthDate,
                                in: birthDateRange,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .frame(width: 160, height: 40)
                            .clipped()
                        }
                    }

                    // BODY HEIGHT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body Height")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()
                            Picker("", selection: $heightCm) {
                                ForEach(130...220, id: \.self) { cm in
                                    Text(heightLabel(for: cm))
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(cm)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }

                    // BODY WEIGHT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body Weight")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()
                            Picker("", selection: $weightKg) {
                                ForEach(40...300, id: \.self) { kg in
                                    Text(weightLabel(for: kg))
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }

                    // TARGET WEIGHT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Weight")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()
                            Picker("", selection: $targetWeightKg) {
                                ForEach(40...250, id: \.self) { kg in
                                    Text(weightLabel(for: kg))
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)   // kein weißer Block hinter der Karte
        .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
    }
}

// MARK: - Preview

#Preview("BodySettingsSection") {
    Form {
        BodySettingsSection(
            gender: .constant("Male"),
            birthDate: .constant(Date()),
            heightCm: .constant(175),
            weightKg: .constant(80),
            targetWeightKg: .constant(75),
            heightUnit: .cm,
            weightUnit: .kg
        )
    }
}
