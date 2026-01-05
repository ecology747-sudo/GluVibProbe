//
//  MetabolicSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

struct MetabolicSettingsSection: View {

    @Binding var isInsulinTreated: Bool
    @Binding var hasCGM: Bool

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var glucoseMin: Int
    @Binding var glucoseMax: Int
    @Binding var veryLowLimit: Int
    @Binding var veryHighLimit: Int

    @Binding var hba1cEntries: [HbA1cEntry]

    // ============================================================
    // MARK: - TIR Target (UI only)  // !!! NEW
    // ============================================================

    @Binding var tirTargetPercent: Int                                // !!! NEW
    @State private var showTirTargetSheet: Bool = false               // !!! NEW

    @State private var isEditingHbA1c: Bool = false
    @State private var editingIndex: Int? = nil
    @State private var editDate: Date = Date()
    @State private var editValueString: String = ""

    // ============================================================
    // MARK: - Constants (mg/dL base)
    // ============================================================

    private let stepMgdl: Int = 5
    private let targetMinGapMgdl: Int = 25
    private let crossGapMgdl: Int = 5

    private let tirRangeMgdl: ClosedRange<Int> = 50...300
    private let extremeRangeMgdl: ClosedRange<Int> = 40...400

    // ============================================================
    // MARK: - Unit helpers (display only)
    // ============================================================

    private func mgToMmol(_ mg: Int) -> Double { Double(mg) / 18.0 }
    private func mmolToMg(_ mmol: Double) -> Int { Int((mmol * 18.0).rounded()) }

    // ============================================================
    // MARK: - 5 mg/dL snapping
    // ============================================================

    private func snappedMgdl(_ mgdl: Int) -> Int {
        let s = stepMgdl
        guard s > 1 else { return mgdl }
        return Int((Double(mgdl) / Double(s)).rounded()) * s
    }

    private func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int {
        min(max(v, r.lowerBound), r.upperBound)
    }

    // ============================================================
    // MARK: - Cross-Slider Normalization
    // ============================================================

    private enum EditedBoundary {
        case veryLow, tirMin, tirMax, veryHigh
    }

    private func normalize(after edited: EditedBoundary) {
        veryLowLimit  = clamp(snappedMgdl(veryLowLimit),  extremeRangeMgdl)
        veryHighLimit = clamp(snappedMgdl(veryHighLimit), extremeRangeMgdl)

        glucoseMin    = clamp(snappedMgdl(glucoseMin),     tirRangeMgdl)
        glucoseMax    = clamp(snappedMgdl(glucoseMax),     tirRangeMgdl)

        switch edited {

        case .veryLow:
            if veryLowLimit > glucoseMin - crossGapMgdl {
                glucoseMin = veryLowLimit + crossGapMgdl
            }
            if glucoseMin > glucoseMax - targetMinGapMgdl {
                glucoseMax = glucoseMin + targetMinGapMgdl
            }
            if glucoseMax > veryHighLimit - crossGapMgdl {
                veryHighLimit = glucoseMax + crossGapMgdl
            }

        case .tirMin:
            if glucoseMin < veryLowLimit + crossGapMgdl {
                veryLowLimit = glucoseMin - crossGapMgdl
            }
            if glucoseMin > glucoseMax - targetMinGapMgdl {
                glucoseMax = glucoseMin + targetMinGapMgdl
            }
            if glucoseMax > veryHighLimit - crossGapMgdl {
                veryHighLimit = glucoseMax + crossGapMgdl
            }

        case .tirMax:
            if glucoseMax > veryHighLimit - crossGapMgdl {
                veryHighLimit = glucoseMax + crossGapMgdl
            }
            if glucoseMin > glucoseMax - targetMinGapMgdl {
                glucoseMin = glucoseMax - targetMinGapMgdl
            }
            if veryLowLimit > glucoseMin - crossGapMgdl {
                veryLowLimit = glucoseMin - crossGapMgdl
            }

        case .veryHigh:
            if veryHighLimit < glucoseMax + crossGapMgdl {
                glucoseMax = veryHighLimit - crossGapMgdl
            }
            if glucoseMin > glucoseMax - targetMinGapMgdl {
                glucoseMin = glucoseMax - targetMinGapMgdl
            }
            if veryLowLimit > glucoseMin - crossGapMgdl {
                veryLowLimit = glucoseMin - crossGapMgdl
            }
        }

        veryLowLimit  = clamp(snappedMgdl(veryLowLimit),  extremeRangeMgdl)
        veryHighLimit = clamp(snappedMgdl(veryHighLimit), extremeRangeMgdl)

        glucoseMin    = clamp(snappedMgdl(glucoseMin),     tirRangeMgdl)
        glucoseMax    = clamp(snappedMgdl(glucoseMax),     tirRangeMgdl)

        if veryLowLimit > glucoseMin - crossGapMgdl {
            veryLowLimit = clamp(glucoseMin - crossGapMgdl, extremeRangeMgdl)
        }
        if glucoseMin > glucoseMax - targetMinGapMgdl {
            glucoseMin = clamp(glucoseMax - targetMinGapMgdl, tirRangeMgdl)
        }
        if glucoseMax > veryHighLimit - crossGapMgdl {
            veryHighLimit = clamp(glucoseMax + crossGapMgdl, extremeRangeMgdl)
        }
    }

    // ============================================================
    // MARK: - Display Strings
    // ============================================================

    private var tirMinDisplay: String {
        if glucoseUnit == .mgdL { return "\(glucoseMin)" }
        return String(format: "%.1f", mgToMmol(glucoseMin))
    }

    private var tirMaxDisplay: String {
        if glucoseUnit == .mgdL { return "\(glucoseMax)" }
        return String(format: "%.1f", mgToMmol(glucoseMax))
    }

    private var veryLowLineText: String {
        if glucoseUnit == .mgdL { return "< \(veryLowLimit) \(glucoseUnit.label)" }
        return String(format: "< %.1f %@", mgToMmol(veryLowLimit), glucoseUnit.label)
    }

    private var veryHighLineText: String {
        if glucoseUnit == .mgdL { return "> \(veryHighLimit) \(glucoseUnit.label)" }
        return String(format: "> %.1f %@", mgToMmol(veryHighLimit), glucoseUnit.label)
    }

    private static let hba1cDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

    private var hba1cEntriesSortedForDisplay: [(index: Int, entry: HbA1cEntry)] {
        hba1cEntries
            .enumerated()
            .map { (index: $0.offset, entry: $0.element) }
            .sorted { $0.entry.date > $1.entry.date }
    }

    // ============================================================
    // MARK: - Done Button (same pattern as Activity)  // !!! NEW
    // ============================================================

    private func doneButton(_ title: String, action: @escaping () -> Void) -> some View { // !!! NEW
        let color = Color.Glu.primaryBlue
        return Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 22)
                .background(Capsule().fill(color.opacity(0.15)))
                .overlay(
                    Capsule().stroke(color, lineWidth: 1)
                )
                .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {

                metabolicFeatureFlagsBlock

                Divider()
                    .padding(.vertical, 4)

                glucoseTargetRangeBlock
                veryLowHighThresholdBlock

                // ====================================================
                // MARK: - TIR Target Row  // !!! NEW
                // ====================================================

                Divider()
                    .padding(.vertical, 4)

                tirTargetBlock                                              // !!! NEW

                Divider()
                    .padding(.vertical, 4)

                hba1cBlock
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous)
                    .fill(Color.Glu.metabolicDomain.opacity(0.06))
            )
            .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
        .sheet(isPresented: $isEditingHbA1c) {
            editHbA1cSheet
        }
        .sheet(isPresented: $showTirTargetSheet) {                     // !!! NEW
            tirTargetSheet
        }
    }

    private var metabolicFeatureFlagsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insulin therapy")
                        .font(.subheadline)
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text("Enable if you regularly use insulin (bolus and/or basal).")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }

                Spacer()

                Toggle("", isOn: $isInsulinTreated)
                    .labelsHidden()
                    .tint(Color.Glu.metabolicDomain)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CGM sensor available")
                        .font(.subheadline)
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text("Enable if your glucose is tracked continuously via a sensor.")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }

                Spacer()

                Toggle("", isOn: $hasCGM)
                    .labelsHidden()
                    .tint(Color.Glu.metabolicDomain)
            }
        }
    }

    // ============================================================
    // MARK: - Slider 1: Target Range
    // ============================================================

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
                    get: { glucoseUnit == .mgdL ? Double(glucoseMin) : mgToMmol(glucoseMin) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL)
                        ? Int(newVal.rounded())
                        : mmolToMg(newVal)

                        glucoseMin = snappedMgdl(mg)
                        normalize(after: .tirMin)
                    }
                ),
                upperValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(glucoseMax) : mgToMmol(glucoseMax) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL)
                        ? Int(newVal.rounded())
                        : mmolToMg(newVal)

                        glucoseMax = snappedMgdl(mg)
                        normalize(after: .tirMax)
                    }
                ),
                range: glucoseUnit == .mgdL ? 50.0...300.0 : 2.775...16.65,
                minGap: glucoseUnit == .mgdL ? Double(targetMinGapMgdl) : 1.5
            )
            .frame(height: 40)
        }
    }

    // ============================================================
    // MARK: - Slider 2: Very Low / Very High
    // ============================================================

    private var veryLowHighThresholdBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Very Low / Very High Glucose Thresholds")
                .font(.subheadline)
                .foregroundColor(Color.Glu.primaryBlue)

            LowerUpperRangeGlucoseSlider(
                lowerValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(veryLowLimit) : mgToMmol(veryLowLimit) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL)
                        ? Int(newVal.rounded())
                        : mmolToMg(newVal)

                        veryLowLimit = snappedMgdl(mg)
                        normalize(after: .veryLow)
                    }
                ),
                upperValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(veryHighLimit) : mgToMmol(veryHighLimit) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL)
                        ? Int(newVal.rounded())
                        : mmolToMg(newVal)

                        veryHighLimit = snappedMgdl(mg)
                        normalize(after: .veryHigh)
                    }
                ),
                range: glucoseUnit == .mgdL ? 40.0...400.0 : 2.2...22.2,
                minGap: glucoseUnit == .mgdL ? 25.0 : 1.5
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

    // ============================================================
    // MARK: - TIR Target Block  // !!! NEW
    // ============================================================

    private var tirTargetBlock: some View {                            // !!! NEW
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showTirTargetSheet = true
            } label: {
                HStack {
                    Text("Target Time in Range (TIR)")
                        .font(.subheadline)
                        .foregroundColor(Color.Glu.primaryBlue)

                    Spacer()

                    Text("\(tirTargetPercent)%")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Text("Used for TIR bar target marker and status colors.")
                .font(.caption)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
        }
    }

    private var tirTargetSheet: some View {                             // !!! NEW
        VStack(spacing: 12) {
            Text("Target Time in Range (TIR)")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)
                .padding(.top, 10)

            Picker("", selection: $tirTargetPercent) {
                ForEach(Array(stride(from: 40, through: 95, by: 1)), id: \.self) { v in
                    Text("\(v)%")
                        .font(.title3)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 220)

            doneButton("Done") {
                showTirTargetSheet = false
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
    }

    // ============================================================
    // MARK: - HbA1c Block (unchanged)
    // ============================================================

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
                            .frame(width: 52)
                    }

                    ForEach(hba1cEntriesSortedForDisplay, id: \.entry.id) { item in
                        let index = item.index
                        let entry = item.entry

                        HStack(spacing: 8) {
                            Text(MetabolicSettingsSection.hba1cDateFormatter.string(from: entry.date))
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

    private func startCreatingHbA1cEntry() {
        editingIndex = nil
        editDate = Date()
        editValueString = ""
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
        let cleaned = editValueString.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned) else {
            isEditingHbA1c = false
            return
        }

        if let index = editingIndex, hba1cEntries.indices.contains(index) {
            var entry = hba1cEntries[index]
            entry.date = editDate
            entry.valuePercent = value
            hba1cEntries[index] = entry
        } else {
            let newEntry = HbA1cEntry(date: editDate, valuePercent: value)
            hba1cEntries.append(newEntry)
        }

        isEditingHbA1c = false
    }

    private var editHbA1cSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $editDate, displayedComponents: .date)

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
                    Button("Cancel") { isEditingHbA1c = false }
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

#Preview("MetabolicSettingsSection") {
    NavigationStack {
        Form {
            MetabolicSettingsSection(
                isInsulinTreated: .constant(false),
                hasCGM: .constant(false),
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
                ]),
                tirTargetPercent: .constant(70) // !!! NEW
            )
        }
    }
}
