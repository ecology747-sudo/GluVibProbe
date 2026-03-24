//
//  MetabolicSettingsSection.swift
//  GluVibProbe
//
//  Settings — Metabolic Section
//  Purpose:
//  - Renders metabolic targets, thresholds, priming controls, and HbA1c lab result management.
//
//  Data Flow (SSoT):
//  - SettingsDomainCardScreen local @State -> bindings -> MetabolicSettingsSection -> UI
//
//  Key Connections:
//  - GlucoseUnit
//  - HbA1cEntry
//  - WheelPickerSheet
//  - RangeSlider
//  - LowerUpperRangeGlucoseSlider
//

import SwiftUI

struct MetabolicSettingsSection: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    @Binding var isInsulinTreated: Bool
    @Binding var hasCGM: Bool

    @Binding var glucoseUnit: GlucoseUnit
    @Binding var glucoseMin: Int
    @Binding var glucoseMax: Int
    @Binding var veryLowLimit: Int
    @Binding var veryHighLimit: Int

    @Binding var hba1cEntries: [HbA1cEntry]

    @Binding var tirTargetPercent: Int
    @Binding var gmi90TargetPercent: Double
    @Binding var cvTargetPercent: Int

    @Binding var excludeBolusPriming: Bool
    @Binding var bolusPrimingThresholdU: Double
    @Binding var excludeBasalPriming: Bool
    @Binding var basalPrimingThresholdU: Double

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var showTirTargetSheet: Bool = false
    @State private var showGmiTargetSheet: Bool = false
    @State private var showCvTargetSheet: Bool = false

    @State private var showBolusPrimingThresholdSheet: Bool = false
    @State private var showBasalPrimingThresholdSheet: Bool = false

    @State private var isEditingHbA1c: Bool = false
    @State private var editingIndex: Int? = nil
    @State private var editDate: Date = Date()
    @State private var editValueString: String = ""

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let stepMgdl: Int = 5
    private let targetMinGapMgdl: Int = 25
    private let crossGapMgdl: Int = 5

    private let tirRangeMgdl: ClosedRange<Int> = 50...300
    private let extremeRangeMgdl: ClosedRange<Int> = 40...400
    private let fixedVeryLowLimitMgdl: Int = 55

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let metabolicTint: Color = Color.Glu.metabolicDomain
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.7)

    // ============================================================
    // MARK: - Unit Helpers
    // ============================================================

    private func mgToMmol(_ mg: Int) -> Double { Double(mg) / 18.0 }
    private func mmolToMg(_ mmol: Double) -> Int { Int((mmol * 18.0).rounded()) }

    private func snappedMgdl(_ mgdl: Int) -> Int {
        let s = stepMgdl
        guard s > 1 else { return mgdl }
        return Int((Double(mgdl) / Double(s)).rounded()) * s
    }

    private func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int {
        min(max(v, r.lowerBound), r.upperBound)
    }

    // ============================================================
    // MARK: - Normalization
    // ============================================================

    private enum EditedBoundary {
        case veryLow
        case tirMin
        case tirMax
        case veryHigh
    }

    private func normalize(after edited: EditedBoundary) {
        veryLowLimit = fixedVeryLowLimitMgdl
        veryHighLimit = clamp(snappedMgdl(veryHighLimit), extremeRangeMgdl)

        glucoseMin = clamp(snappedMgdl(glucoseMin), tirRangeMgdl)
        glucoseMax = clamp(snappedMgdl(glucoseMax), tirRangeMgdl)

        switch edited {

        case .veryLow:
            if glucoseMin < fixedVeryLowLimitMgdl + crossGapMgdl {
                glucoseMin = fixedVeryLowLimitMgdl + crossGapMgdl
            }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMax = glucoseMin + targetMinGapMgdl }
            if glucoseMax > veryHighLimit - crossGapMgdl { veryHighLimit = glucoseMax + crossGapMgdl }

        case .tirMin:
            if glucoseMin < fixedVeryLowLimitMgdl + crossGapMgdl {
                glucoseMin = fixedVeryLowLimitMgdl + crossGapMgdl
            }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMax = glucoseMin + targetMinGapMgdl }
            if glucoseMax > veryHighLimit - crossGapMgdl { veryHighLimit = glucoseMax + crossGapMgdl }

        case .tirMax:
            if glucoseMax > veryHighLimit - crossGapMgdl { veryHighLimit = glucoseMax + crossGapMgdl }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMin = glucoseMax - targetMinGapMgdl }
            if glucoseMin < fixedVeryLowLimitMgdl + crossGapMgdl {
                glucoseMin = fixedVeryLowLimitMgdl + crossGapMgdl
            }

        case .veryHigh:
            if veryHighLimit < glucoseMax + crossGapMgdl { glucoseMax = veryHighLimit - crossGapMgdl }
            if glucoseMin > glucoseMax - targetMinGapMgdl { glucoseMin = glucoseMax - targetMinGapMgdl }
            if glucoseMin < fixedVeryLowLimitMgdl + crossGapMgdl {
                glucoseMin = fixedVeryLowLimitMgdl + crossGapMgdl
            }
        }

        veryLowLimit = fixedVeryLowLimitMgdl
        veryHighLimit = clamp(snappedMgdl(veryHighLimit), extremeRangeMgdl)

        glucoseMin = clamp(snappedMgdl(glucoseMin), tirRangeMgdl)
        glucoseMax = clamp(snappedMgdl(glucoseMax), tirRangeMgdl)

        if glucoseMin < fixedVeryLowLimitMgdl + crossGapMgdl {
            glucoseMin = clamp(fixedVeryLowLimitMgdl + crossGapMgdl, tirRangeMgdl)
        }
        if glucoseMin > glucoseMax - targetMinGapMgdl {
            glucoseMin = clamp(glucoseMax - targetMinGapMgdl, tirRangeMgdl)
        }
        if glucoseMax > veryHighLimit - crossGapMgdl {
            veryHighLimit = clamp(glucoseMax + crossGapMgdl, extremeRangeMgdl)
        }
    }

    // ============================================================
    // MARK: - Display Mapping
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
        if glucoseUnit == .mgdL { return "< \(fixedVeryLowLimitMgdl) \(glucoseUnit.label)" }
        return String(format: "< %.1f %@", mgToMmol(fixedVeryLowLimitMgdl), glucoseUnit.label)
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

    private var bolusPrimingThresholdOptions: [Double] {
        Array(stride(from: 0.1, through: 3.0, by: 0.1))
            .map { (Double($0) * 10.0).rounded() / 10.0 }
    }

    private var basalPrimingThresholdOptions: [Double] {
        Array(stride(from: 0.5, through: 6.0, by: 0.5))
    }

    private func primingThresholdText(_ v: Double) -> String {
        String(format: "%.1f U", v)
    }

    private func primingLeqHintText(_ threshold: Double) -> String {
        L10n.Avatar.MetabolicSettings.appliesToDosesAtMost(primingThresholdText(threshold)) // 🟨 UPDATED
    }

    private var metabolicSettingsDisclaimerText: String {
        L10n.Avatar.MetabolicSettings.disclaimer // 🟨 UPDATED
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            disclaimerBlock

            glucoseTargetRangeBlock
            veryLowHighThresholdBlock

            Divider().padding(.vertical, 4)

            tirTargetBlock
            gmiTargetBlock
            cvTargetBlock

            Divider().padding(.vertical, 4)

            primingBlock

            Divider().padding(.vertical, 4)

            hba1cBlock
        }
        .padding(.vertical, 6)
        .onAppear {
            if veryLowLimit != fixedVeryLowLimitMgdl {
                veryLowLimit = fixedVeryLowLimitMgdl
            }
            normalize(after: .tirMin)
        }
        .sheet(isPresented: $isEditingHbA1c) { editHbA1cSheet }
        .sheet(isPresented: $showTirTargetSheet) { tirTargetSheet }
        .sheet(isPresented: $showGmiTargetSheet) { gmiTargetSheet }
        .sheet(isPresented: $showCvTargetSheet) { cvTargetSheet }
        .sheet(isPresented: $showBolusPrimingThresholdSheet) { bolusPrimingThresholdSheet }
        .sheet(isPresented: $showBasalPrimingThresholdSheet) { basalPrimingThresholdSheet }
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    private var disclaimerBlock: some View {
        Text(metabolicSettingsDisclaimerText)
            .font(.caption)
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.80))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.Glu.backgroundSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.Glu.primaryBlue.opacity(0.18), lineWidth: 0.9)
                    )
            )
    }

    private var glucoseTargetRangeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(
                    String(
                        localized: "Glucose Target Range",
                        defaultValue: "Glucose Target Range",
                        comment: "Section title for glucose target range in metabolic settings"
                    )
                ) // 🟨 UPDATED
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

    private var veryLowHighThresholdBlock: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(
                String(
                    localized: "Very Low / Very High Glucose Thresholds",
                    defaultValue: "Very Low / Very High Glucose Thresholds",
                    comment: "Section title for very low and very high glucose thresholds in metabolic settings"
                )
            ) // 🟨 UPDATED
            .font(sectionTitleFont)
            .foregroundColor(titleColor)

            LowerUpperRangeGlucoseSlider(
                lowerValue: Binding(
                    get: { glucoseUnit == .mgdL ? Double(fixedVeryLowLimitMgdl) : mgToMmol(fixedVeryLowLimitMgdl) },
                    set: { _ in }
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
                Text(
                    String(
                        localized: "Very Low Glucose",
                        defaultValue: "Very Low Glucose",
                        comment: "Label for very low glucose threshold in metabolic settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(veryLowLineText)
                    .font(segmentFont)
                    .foregroundColor(titleColor)
            }

            HStack {
                Text(
                    String(
                        localized: "Very High Glucose",
                        defaultValue: "Very High Glucose",
                        comment: "Label for very high glucose threshold in metabolic settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(veryHighLineText)
                    .font(segmentFont)
                    .foregroundColor(titleColor)
            }
        }
    }

    private var tirTargetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showTirTargetSheet = true
            } label: {
                HStack {
                    Text(
                        String(
                            localized: "Target Time in Range (TIR)",
                            defaultValue: "Target Time in Range (TIR)",
                            comment: "Target title for TIR in metabolic settings"
                        )
                    ) // 🟨 UPDATED
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

            Text(
                String(
                    localized: "Used for TIR bar target marker and status colors.",
                    defaultValue: "Used for TIR bar target marker and status colors.",
                    comment: "Footnote for TIR target in metabolic settings"
                )
            ) // 🟨 UPDATED
            .font(.caption)
            .foregroundColor(captionColor)
        }
    }

    private var tirTargetSheet: some View {
        let values = Array(stride(from: 40, through: 95, by: 1))
        return WheelPickerSheet<Int>(
            title: String(
                localized: "Target Time in Range (TIR)",
                defaultValue: "Target Time in Range (TIR)",
                comment: "Wheel picker title for TIR target in metabolic settings"
            ),
            selection: $tirTargetPercent,
            values: values,
            valueLabel: { "\($0) %" },
            detent: .fraction(0.72)
        )
    }

    private var gmiTargetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showGmiTargetSheet = true
            } label: {
                HStack {
                    Text(
                        String(
                            localized: "Target GMI (90d)",
                            defaultValue: "Target GMI (90d)",
                            comment: "Target title for GMI in metabolic settings"
                        )
                    ) // 🟨 UPDATED
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

            Text(
                String(
                    localized: "Used for GMI(90d) KPI status colors.",
                    defaultValue: "Used for GMI(90d) KPI status colors.",
                    comment: "Footnote for GMI target in metabolic settings"
                )
            ) // 🟨 UPDATED
            .font(.caption)
            .foregroundColor(captionColor)
        }
    }

    private var gmiTargetSheet: some View {
        let values = Array(stride(from: 5.0, through: 10.0, by: 0.1)).map { (Double($0) * 10.0).rounded() / 10.0 }
        return WheelPickerSheet<Double>(
            title: String(
                localized: "Target GMI (90d)",
                defaultValue: "Target GMI (90d)",
                comment: "Wheel picker title for GMI target in metabolic settings"
            ),
            selection: $gmi90TargetPercent,
            values: values,
            valueLabel: { String(format: "%.1f%%", $0) },
            detent: .fraction(0.72)
        )
    }

    private var cvTargetBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button {
                showCvTargetSheet = true
            } label: {
                HStack {
                    Text(
                        String(
                            localized: "Target CV (24h)",
                            defaultValue: "Target CV (24h)",
                            comment: "Target title for CV in metabolic settings"
                        )
                    ) // 🟨 UPDATED
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

            Text(
                String(
                    localized: "Used for CV(24h) KPI status colors.",
                    defaultValue: "Used for CV(24h) KPI status colors.",
                    comment: "Footnote for CV target in metabolic settings"
                )
            ) // 🟨 UPDATED
            .font(.caption)
            .foregroundColor(captionColor)
        }
    }

    private var cvTargetSheet: some View {
        let values = Array(stride(from: 20, through: 60, by: 1))
        return WheelPickerSheet<Int>(
            title: String(
                localized: "Target CV (24h)",
                defaultValue: "Target CV (24h)",
                comment: "Wheel picker title for CV target in metabolic settings"
            ),
            selection: $cvTargetPercent,
            values: values,
            valueLabel: { "\($0) %" },
            detent: .fraction(0.72)
        )
    }

    private var primingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text(
                String(
                    localized: "Priming (Pen Air Shot)",
                    defaultValue: "Priming (Pen Air Shot)",
                    comment: "Section title for priming settings in metabolic settings"
                )
            ) // 🟨 UPDATED
            .font(sectionTitleFont)
            .foregroundColor(titleColor)

            HStack(alignment: .center, spacing: 12) {
                Toggle(
                    String(
                        localized: "Exclude Bolus Priming",
                        defaultValue: "Exclude Bolus Priming",
                        comment: "Toggle title for excluding bolus priming in metabolic settings"
                    ),
                    isOn: $excludeBolusPriming
                ) // 🟨 UPDATED
                .font(segmentFont)
                .foregroundColor(titleColor)
                .tint(metabolicTint)

                Spacer()

                Button {
                    showBolusPrimingThresholdSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text(primingThresholdText(bolusPrimingThresholdU))
                            .font(segmentFont)
                            .foregroundColor(titleColor)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(segmentFont)
                            .foregroundColor(titleColor.opacity(0.7))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!excludeBolusPriming)
                .opacity(excludeBolusPriming ? 1.0 : 0.45)
            }

            HStack(alignment: .center, spacing: 12) {
                Toggle(
                    String(
                        localized: "Exclude Basal Priming",
                        defaultValue: "Exclude Basal Priming",
                        comment: "Toggle title for excluding basal priming in metabolic settings"
                    ),
                    isOn: $excludeBasalPriming
                ) // 🟨 UPDATED
                .font(segmentFont)
                .foregroundColor(titleColor)
                .tint(metabolicTint)

                Spacer()

                Button {
                    showBasalPrimingThresholdSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text(primingThresholdText(basalPrimingThresholdU))
                            .font(segmentFont)
                            .foregroundColor(titleColor)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(segmentFont)
                            .foregroundColor(titleColor.opacity(0.7))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!excludeBasalPriming)
                .opacity(excludeBasalPriming ? 1.0 : 0.45)
            }

            Text(
                String(
                    localized: "When enabled, GluVib removes small priming doses (≤ threshold) only if they occur within 2 minutes of a larger dose of the same type.",
                    defaultValue: "When enabled, GluVib removes small priming doses (≤ threshold) only if they occur within 2 minutes of a larger dose of the same type.",
                    comment: "Explanation text for priming settings in metabolic settings"
                )
            ) // 🟨 UPDATED
            .font(.caption)
            .foregroundColor(captionColor)
        }
    }

    private var bolusPrimingThresholdSheet: some View {
        WheelPickerSheet<Double>(
            title: L10n.Avatar.MetabolicSettings.bolusPrimingThreshold, // 🟨 UPDATED
            selection: $bolusPrimingThresholdU,
            values: bolusPrimingThresholdOptions,
            valueLabel: { primingThresholdText($0) },
            detent: .fraction(0.72),
            hintText: primingLeqHintText(bolusPrimingThresholdU)
        )
    }

    private var basalPrimingThresholdSheet: some View {
        WheelPickerSheet<Double>(
            title: L10n.Avatar.MetabolicSettings.basalPrimingThreshold, // 🟨 UPDATED
            selection: $basalPrimingThresholdU,
            values: basalPrimingThresholdOptions,
            valueLabel: { primingThresholdText($0) },
            detent: .fraction(0.72),
            hintText: primingLeqHintText(basalPrimingThresholdU)
        )
    }

    private var hba1cBlock: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text(
                    String(
                        localized: "HbA1c Lab Results",
                        defaultValue: "HbA1c Lab Results",
                        comment: "Section title for HbA1c lab results in metabolic settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Button {
                    startCreatingHbA1cEntry()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(segmentFont)
                        Text(
                            String(
                                localized: "Add",
                                defaultValue: "Add",
                                comment: "Add button title for HbA1c lab results in metabolic settings"
                            )
                        ) // 🟨 UPDATED
                        .font(segmentFont)
                    }
                    .foregroundColor(titleColor)
                }
                .buttonStyle(.plain)
            }

            if hba1cEntries.isEmpty {
                Text(
                    String(
                        localized: "No HbA1c lab values recorded yet.",
                        defaultValue: "No HbA1c lab values recorded yet.",
                        comment: "Empty state text for HbA1c lab results in metabolic settings"
                    )
                ) // 🟨 UPDATED
                .font(.caption)
                .foregroundColor(captionColor)
            } else {
                VStack(spacing: 6) {

                    HStack {
                        Text(
                            String(
                                localized: "Date",
                                defaultValue: "Date",
                                comment: "Column title for date in HbA1c table"
                            )
                        ) // 🟨 UPDATED
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(titleColor.opacity(0.8))

                        Spacer()

                        Text(
                            String(
                                localized: "HbA1c",
                                defaultValue: "HbA1c",
                                comment: "Column title for HbA1c value in HbA1c table"
                            )
                        ) // 🟨 UPDATED
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

    private var editHbA1cSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        String(
                            localized: "Date",
                            defaultValue: "Date",
                            comment: "Date field title in HbA1c edit sheet"
                        ),
                        selection: $editDate,
                        displayedComponents: .date
                    ) // 🟨 UPDATED

                    HStack {
                        Text(
                            String(
                                localized: "HbA1c",
                                defaultValue: "HbA1c",
                                comment: "Value label for HbA1c in edit sheet"
                            )
                        ) // 🟨 UPDATED
                        Spacer()
                        TextField(
                            String(
                                localized: "Value",
                                defaultValue: "Value",
                                comment: "Placeholder title for HbA1c value input"
                            ),
                            text: $editValueString
                        ) // 🟨 UPDATED
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("%")
                    }
                }
            }
            .navigationTitle(
                editingIndex == nil
                    ? String(
                        localized: "New HbA1c",
                        defaultValue: "New HbA1c",
                        comment: "Navigation title for creating a new HbA1c value"
                    )
                    : String(
                        localized: "Edit HbA1c",
                        defaultValue: "Edit HbA1c",
                        comment: "Navigation title for editing an HbA1c value"
                    )
            ) // 🟨 UPDATED
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String(
                            localized: "Cancel",
                            defaultValue: "Cancel",
                            comment: "Cancel button title in HbA1c edit sheet"
                        )
                    ) { isEditingHbA1c = false } // 🟨 UPDATED
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        String(
                            localized: "Save",
                            defaultValue: "Save",
                            comment: "Save button title in HbA1c edit sheet"
                        )
                    ) { saveEditedHbA1c() } // 🟨 UPDATED
                    .font(.headline)
                }
            }
        }
    }

    // ============================================================
    // MARK: - Actions
    // ============================================================

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
}

// ============================================================
// MARK: - Preview
// ============================================================

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
                cvTargetPercent: .constant(36),
                excludeBolusPriming: .constant(false),
                bolusPrimingThresholdU: .constant(1.0),
                excludeBasalPriming: .constant(false),
                basalPrimingThresholdU: .constant(1.0)
            )
            .padding(.horizontal, 16)
        }
        .tint(Color.Glu.systemForeground)
    }
}
