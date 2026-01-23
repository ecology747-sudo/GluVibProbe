//
//  MetabolicSettingsSection.swift
//  GluVibProbe
//
//  UPDATED: Metabolic Settings unified to Units/Body/Nutrition/Activity Settings style
//  - Keeps sliders for Target Range + Very Low/Very High thresholds
//  - Replaces ALL wheel sheets (TIR / GMI / CV) with shared WheelPickerSheet (single top Done)
//  - Unifies typography to Units-style tokens (sectionTitleFont + segmentFont)
//
//  UPDATED: Removed CGM/Insulin feature flags block (moved to Manage App Status)
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

    // MARK: - Targets (UI only)
    @Binding var tirTargetPercent: Int
    @State private var showTirTargetSheet: Bool = false

    @Binding var gmi90TargetPercent: Double
    @State private var showGmiTargetSheet: Bool = false

    @Binding var cvTargetPercent: Int
    @State private var showCvTargetSheet: Bool = false

    @State private var isEditingHbA1c: Bool = false
    @State private var editingIndex: Int? = nil
    @State private var editDate: Date = Date()
    @State private var editValueString: String = ""

    // MARK: - Constants (mg/dL base)
    private let stepMgdl: Int = 5
    private let targetMinGapMgdl: Int = 25
    private let crossGapMgdl: Int = 5

    private let tirRangeMgdl: ClosedRange<Int> = 50...300
    private let extremeRangeMgdl: ClosedRange<Int> = 40...400

    // MARK: - Style (MATCH UnitsSettingsSection)
    private let titleColor: Color = Color.Glu.primaryBlue
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let captionColor: Color = Color.Glu.primaryBlue.opacity(0.7)

    // MARK: - Unit helpers (display only)
    private func mgToMmol(_ mg: Int) -> Double { Double(mg) / 18.0 }
    private func mmolToMg(_ mmol: Double) -> Int { Int((mmol * 18.0).rounded()) }

    // MARK: - 5 mg/dL snapping
    private func snappedMgdl(_ mgdl: Int) -> Int {
        let s = stepMgdl
        guard s > 1 else { return mgdl }
        return Int((Double(mgdl) / Double(s)).rounded()) * s
    }

    private func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int {
        min(max(v, r.lowerBound), r.upperBound)
    }

    // MARK: - Cross-Slider Normalization
    private enum EditedBoundary { case veryLow, tirMin, tirMax, veryHigh }

    private func normalize(after edited: EditedBoundary) {
        veryLowLimit  = clamp(snappedMgdl(veryLowLimit),  extremeRangeMgdl)
        veryHighLimit = clamp(snappedMgdl(veryHighLimit), extremeRangeMgdl)

        glucoseMin    = clamp(snappedMgdl(glucoseMin),     tirRangeMgdl)
        glucoseMax    = clamp(snappedMgdl(glucoseMax),     tirRangeMgdl)

        switch edited {

        case .veryLow:
            if veryLowLimit > glucoseMin - crossGapMgdl { glucoseMin = veryLowLimit + crossGapMgdl }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMax = glucoseMin + targetMinGapMgdl }
            if glucoseMax > veryHighLimit - crossGapMgdl { veryHighLimit = glucoseMax + crossGapMgdl }

        case .tirMin:
            if glucoseMin < veryLowLimit + crossGapMgdl { veryLowLimit = glucoseMin - crossGapMgdl }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMax = glucoseMin + targetMinGapMgdl }
            if glucoseMax > veryHighLimit - crossGapMgdl { veryHighLimit = glucoseMax + crossGapMgdl }

        case .tirMax:
            if glucoseMax > veryHighLimit - crossGapMgdl { veryHighLimit = glucoseMax + crossGapMgdl }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMin = glucoseMax - targetMinGapMgdl }
            if veryLowLimit > glucoseMin - crossGapMgdl { veryLowLimit = glucoseMin - crossGapMgdl }

        case .veryHigh:
            if veryHighLimit < glucoseMax + crossGapMgdl { glucoseMax = veryHighLimit - crossGapMgdl }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMin = glucoseMax - targetMinGapMgdl }
            if veryLowLimit > glucoseMin - crossGapMgdl { veryLowLimit = glucoseMin - crossGapMgdl }
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

    // MARK: - Display Strings

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

    private var gmi90Display: String {
        String(format: "%.1f%%", gmi90TargetPercent)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            glucoseTargetRangeBlock
            veryLowHighThresholdBlock

            Divider().padding(.vertical, 4)

            tirTargetBlock
            gmiTargetBlock
            cvTargetBlock

            Divider().padding(.vertical, 4)

            hba1cBlock
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $isEditingHbA1c) { editHbA1cSheet }
        .sheet(isPresented: $showTirTargetSheet) { tirTargetSheet }
        .sheet(isPresented: $showGmiTargetSheet) { gmiTargetSheet }
        .sheet(isPresented: $showCvTargetSheet) { cvTargetSheet }
    }

    // MARK: - Slider 1: Target Range (KEEP sliders, but typography unified)

    private var glucoseTargetRangeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Glucose Target Range")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Spacer()

                Text("\(tirMinDisplay)–\(tirMaxDisplay) \(glucoseUnit.label)")
                    .font(segmentFont)
                    .foregroundColor(titleColor)
            }

            RangeSlider(
                lowerValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(glucoseMin) : mgToMmol(glucoseMin) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL) ? Int(newVal.rounded()) : mmolToMg(newVal)
                        glucoseMin = snappedMgdl(mg)
                        normalize(after: .tirMin)
                    }
                ),
                upperValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(glucoseMax) : mgToMmol(glucoseMax) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL) ? Int(newVal.rounded()) : mmolToMg(newVal)
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

    // MARK: - Slider 2: Very Low / Very High (KEEP sliders, typography unified)

    private var veryLowHighThresholdBlock: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Very Low / Very High Glucose Thresholds")
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

            LowerUpperRangeGlucoseSlider(
                lowerValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(veryLowLimit) : mgToMmol(veryLowLimit) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL) ? Int(newVal.rounded()) : mmolToMg(newVal)
                        veryLowLimit = snappedMgdl(mg)
                        normalize(after: .veryLow)
                    }
                ),
                upperValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(veryHighLimit) : mgToMmol(veryHighLimit) },
                    set: { newVal in
                        let mg = (glucoseUnit == .mgdL) ? Int(newVal.rounded()) : mmolToMg(newVal)
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
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)
                Spacer()
                Text(veryLowLineText)
                    .font(segmentFont)
                    .foregroundColor(titleColor)
            }

            HStack {
                Text("Very High Glucose")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)
                Spacer()
                Text(veryHighLineText)
                    .font(segmentFont)
                    .foregroundColor(titleColor)
            }
        }
    }

    // MARK: - TIR Target (WheelPickerSheet)

    private var tirTargetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showTirTargetSheet = true
            } label: {
                HStack {
                    Text("Target Time in Range (TIR)")
                        .font(sectionTitleFont)
                        .foregroundColor(titleColor)

                    Spacer()

                    Text("\(tirTargetPercent)%")
                        .font(segmentFont)
                        .foregroundColor(titleColor)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(segmentFont)
                        .foregroundColor(titleColor.opacity(0.7))
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Used for TIR bar target marker and status colors.")
                .font(.caption)
                .foregroundColor(captionColor)
        }
    }

    private var tirTargetSheet: some View {
        let values = Array(stride(from: 40, through: 95, by: 1))
        return WheelPickerSheet<Int>(
            title: "Target Time in Range (TIR)",
            selection: $tirTargetPercent,
            values: values,
            valueLabel: { "\($0) %" },
            detent: .fraction(0.72)
        )
    }

    // MARK: - GMI Target (WheelPickerSheet)

    private var gmiTargetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showGmiTargetSheet = true
            } label: {
                HStack {
                    Text("Target GMI (90d)")
                        .font(sectionTitleFont)
                        .foregroundColor(titleColor)

                    Spacer()

                    Text(gmi90Display)
                        .font(segmentFont)
                        .foregroundColor(titleColor)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(segmentFont)
                        .foregroundColor(titleColor.opacity(0.7))
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Used for GMI(90d) KPI status colors.")
                .font(.caption)
                .foregroundColor(captionColor)
        }
    }

    private var gmiTargetSheet: some View {
        let values = Array(stride(from: 5.0, through: 10.0, by: 0.1)).map { (Double($0) * 10.0).rounded() / 10.0 }
        return WheelPickerSheet<Double>(
            title: "Target GMI (90d)",
            selection: $gmi90TargetPercent,
            values: values,
            valueLabel: { String(format: "%.1f%%", $0) },
            detent: .fraction(0.72)
        )
    }

    // MARK: - CV Target (WheelPickerSheet)

    private var cvTargetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showCvTargetSheet = true
            } label: {
                HStack {
                    Text("Target CV (24h)")
                        .font(sectionTitleFont)
                        .foregroundColor(titleColor)

                    Spacer()

                    Text("\(cvTargetPercent)%")
                        .font(segmentFont)
                        .foregroundColor(titleColor)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(segmentFont)
                        .foregroundColor(titleColor.opacity(0.7))
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Used for CV(24h) KPI status colors.")
                .font(.caption)
                .foregroundColor(captionColor)
        }
    }

    private var cvTargetSheet: some View {
        let values = Array(stride(from: 20, through: 60, by: 1))
        return WheelPickerSheet<Int>(
            title: "Target CV (24h)",
            selection: $cvTargetPercent,
            values: values,
            valueLabel: { "\($0) %" },
            detent: .fraction(0.72)
        )
    }

    // MARK: - HbA1c Block (behavior unchanged, typography aligned)

    private var hba1cBlock: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("HbA1c Lab Results")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Spacer()

                Button {
                    startCreatingHbA1cEntry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(segmentFont)
                        Text("Add")
                            .font(segmentFont)
                    }
                    .foregroundColor(titleColor)
                }
                .buttonStyle(.plain)
            }

            if hba1cEntries.isEmpty {
                Text("No HbA1c lab values recorded yet.")
                    .font(.caption)
                    .foregroundColor(captionColor)
            } else {
                VStack(spacing: 6) {

                    HStack {
                        Text("Date")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(titleColor.opacity(0.8))

                        Spacer()

                        Text("HbA1c")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(titleColor.opacity(0.8))
                            .frame(width: 60, alignment: .trailing)

                        Text("%")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(titleColor.opacity(0.8))
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
                                .font(segmentFont)
                                .foregroundColor(titleColor)

                            Spacer()

                            Text(String(format: "%.1f", entry.valuePercent))
                                .font(segmentFont)
                                .foregroundColor(titleColor)
                                .frame(width: 60, alignment: .trailing)

                            Text("%")
                                .font(segmentFont)
                                .foregroundColor(titleColor)
                                .frame(width: 20, alignment: .leading)

                            Spacer(minLength: 16)

                            HStack(spacing: 12) {
                                Button {
                                    startEditingHbA1c(at: index)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(segmentFont)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(titleColor)

                                Button(role: .destructive) {
                                    removeHbA1cEntry(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(segmentFont)
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

    // MARK: - HbA1c actions (unchanged)

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
                    Button("Save") { saveEditedHbA1c() }
                        .font(.headline)
                }
            }
        }
    }
}

#Preview("MetabolicSettingsSection") {
    NavigationStack {
        ScrollView {
            MetabolicSettingsSection(
                isInsulinTreated: .constant(false),
                hasCGM: .constant(false),
                glucoseUnit: .constant(.mgdL),
                glucoseMin: .constant(70),
                glucoseMax: .constant(180),
                veryLowLimit: .constant(55),
                veryHighLimit: .constant(250),
                hba1cEntries: .constant([
                    HbA1cEntry(date: Date(), valuePercent: 6.4),
                    HbA1cEntry(
                        date: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
                        valuePercent: 6.8
                    )
                ]),
                tirTargetPercent: .constant(70),
                gmi90TargetPercent: .constant(7.0),
                cvTargetPercent: .constant(36)
            )
            .padding(.horizontal, 16)
        }
        .tint(Color.Glu.primaryBlue)
    }
}
