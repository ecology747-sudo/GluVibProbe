//
//  MetabolicSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: METABOLIC – Glucose-Ziele & Schwellen + HbA1c-Laborwerte
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

    // 🔹 HbA1c-Liste
    @Binding var hba1cEntries: [HbA1cEntry]

    // MARK: - Lokale Edit-States für HbA1c

    @State private var isEditingHbA1c: Bool = false
    @State private var editingIndex: Int? = nil   // nil = Neuer Eintrag
    @State private var editDate: Date = Date()
    @State private var editValueString: String = ""

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

    // MARK: - DateFormatter für HbA1c-Zeilen

    private static let hba1cDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

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

                    glucoseTargetRangeBlock

                    // MARK: Very Low / Very High Thresholds

                    veryLowHighThresholdBlock

                    // MARK: HbA1c-Laborwerte (neu)

                    Divider()
                        .padding(.vertical, 4)

                    hba1cBlock
                }
                .padding(16)
            }
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
        // 🔹 Edit-/Create-Sheet für HbA1c
        .sheet(isPresented: $isEditingHbA1c) {
            editHbA1cSheet
        }
    }

    // MARK: - Teilblöcke

    /// Block für Glucose Target Range (TIR)
    private var glucoseTargetRangeBlock: some View {
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
    }

    /// Block für Very Low / High Thresholds
    private var veryLowHighThresholdBlock: some View {
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

    /// Block für HbA1c-Laborwerte
    private var hba1cBlock: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("HbA1c Lab Results")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Button {
                    startCreatingHbA1cEntry()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                        Text("Add")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(Color.Glu.primaryBlue)
                }
                .buttonStyle(.plain)
            }

            if hba1cEntries.isEmpty {
                Text("No HbA1c lab values recorded yet.")
                    .font(.caption)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            } else {
                VStack(spacing: 6) {

                    // Kopfzeile
                    HStack {
                        Text("Date")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))

                        Spacer()

                        Text("HbA1c")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))
                            .frame(width: 60, alignment: .trailing)

                        Text("%")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))
                            .frame(width: 20, alignment: .leading)

                        Spacer(minLength: 16)

                        Text(" ")
                            .frame(width: 52) // Platz für Edit + Trash
                    }

                    // Anzeige-Zeilen mit Edit- und Trash-Button
                    ForEach(Array(hba1cEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 8) {
                            Text(
                                MetabolicSettingsSection
                                    .hba1cDateFormatter
                                    .string(from: entry.date)
                            )
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                            Spacer()

                            Text(String(format: "%.1f", entry.valuePercent))
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color.Glu.primaryBlue)
                                .frame(width: 60, alignment: .trailing)

                            Text("%")
                                .font(.subheadline)
                                .foregroundColor(Color.Glu.primaryBlue)
                                .frame(width: 20, alignment: .leading)

                            Spacer(minLength: 16)

                            HStack(spacing: 12) {
                                Button {
                                    startEditingHbA1c(at: index)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(Color.Glu.primaryBlue)

                                Button(role: .destructive) {
                                    removeHbA1cEntry(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - HbA1c Helper

    /// Neuer Eintrag -> öffnet direkt die Maske
    private func startCreatingHbA1cEntry() {
        editingIndex = nil
        editDate = Date()
        editValueString = ""        // leer, User trägt Wert ein
        isEditingHbA1c = true
    }

    private func removeHbA1cEntry(at index: Int) {
        guard hba1cEntries.indices.contains(index) else { return }
        hba1cEntries.remove(at: index)
    }

    private func startEditingHbA1c(at index: Int) {
        guard hba1cEntries.indices.contains(index) else { return }
        let entry = hba1cEntries[index]
        editingIndex = index
        editDate = entry.date
        editValueString = String(format: "%.1f", entry.valuePercent)
        isEditingHbA1c = true
    }

    private func saveEditedHbA1c() {
        // Komma in Punkt umwandeln, damit 6,5 auch akzeptiert wird
        let cleaned = editValueString.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned) else {
            isEditingHbA1c = false
            return
        }

        if let index = editingIndex, hba1cEntries.indices.contains(index) {
            // Bestehenden Eintrag updaten
            var entry = hba1cEntries[index]
            entry.date = editDate
            entry.valuePercent = value
            hba1cEntries[index] = entry
        } else {
            // Neuen Eintrag anlegen
            let newEntry = HbA1cEntry(date: editDate, valuePercent: value)
            hba1cEntries.append(newEntry)
        }

        isEditingHbA1c = false
    }

    // MARK: - Edit-/Create-Sheet

    private var editHbA1cSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Date",
                        selection: $editDate,
                        displayedComponents: .date
                    )

                    HStack {
                        Text("HbA1c")
                        Spacer()
                        TextField("Value", text: $editValueString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                    }
                }
            }
            .navigationTitle(editingIndex == nil ? "New HbA1c" : "Edit HbA1c")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isEditingHbA1c = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditedHbA1c()
                    }
                    .font(.headline)
                }
            }
        }
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
                veryHighLimit: .constant(250),
                hba1cEntries:  .constant([
                    HbA1cEntry(date: Date(), valuePercent: 6.4),
                    HbA1cEntry(
                        date: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                        valuePercent: 6.8
                    )
                ])
            )
        }
    }
}
