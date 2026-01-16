//
//  GlucoseSummaryKPIsSectionV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Glucose Summary KPIs (Section)
//  - Extracted from GlucoseSummaryCardV1 (SD / GMI(90) / CV)
//  - SSoT only: HealthStore + SettingsModel
//  - DESIGN RULE: Tile styling must use ONLY .gluVibCardFrame(domainColor: .metabolicDomain)
//    -> No custom RoundedRectangle backgrounds/strokes inside this file.
//

import SwiftUI
import TipKit

struct GlucoseSummaryKPIsSectionV1: View {

    // ============================================================
    // MARK: - SSoT
    // ============================================================

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState

    // ============================================================
    // MARK: - Derived Values (SSoT)
    // ============================================================

    private var sdDisplayText: String {
        guard let sdMgdl = healthStore.last24hGlucoseSdMgdl, sdMgdl > 0 else { return "–" }
        let digits = (settings.glucoseUnit == .mgdL) ? 0 : 1
        return settings.glucoseUnit.formatted(fromMgdl: sdMgdl, fractionDigits: digits, includeUnit: true)
    }

    private var cvValue: Double? {
        guard let cv = healthStore.last24hGlucoseCvPercent, cv > 0 else { return nil }
        return cv
    }

    private var cvDisplayText: String {
        guard let cv = cvValue else { return "–" }
        return "\(Int(cv.rounded()))%"
    }

    // !!! UPDATED: GMI(90) uses ONE canonical SSoT property: glucoseMean90dMgdl
    private var gmi90Value: Double? {
        guard let mean90 = healthStore.glucoseMean90dMgdl, mean90 > 0 else { return nil }
        return computeGmiPercent(fromMeanMgdl: mean90)
    }

    private var gmi90Text: String {
        guard let gmi = gmi90Value else { return "–" }
        return "\(formatNumber1(gmi))%"
    }

    // ============================================================
    // MARK: - KPI Colors (Targets in Settings)
    // ============================================================

    private var cvValueColor: Color? {
        guard let cv = cvValue else { return nil }
        return statusColorHigherIsWorse(
            value: cv,
            target: Double(settings.cvTargetPercent),
            warnBuffer: 4.0
        )
    }

    private var gmi90ValueColor: Color? {
        guard let gmi = gmi90Value else { return nil }
        return statusColorHigherIsWorse(
            value: gmi,
            target: settings.gmi90TargetPercent,
            warnBuffer: 0.3
        )
    }

    private func statusColorHigherIsWorse(value: Double, target: Double, warnBuffer: Double) -> Color {
        if value <= target { return Color.green }
        if value <= (target + warnBuffer) { return Color.yellow.opacity(0.85) }
        return Color.Glu.acidCGMRed
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        HStack(spacing: 12) {

            tile(
                titleLeft: "SD",
                titleRight: "(24h)",
                valueText: sdDisplayText,
                valueColor: nil,
                unit: nil,
                onTap: { appState.currentStatsScreen = .SD }
            )

            tile(
                titleLeft: "GMI",
                titleRight: "(90d)",
                valueText: gmi90Text,
                valueColor: gmi90ValueColor,
                unit: nil,
                onTap: { appState.currentStatsScreen = .gmi }
            )

            tile(
                titleLeft: "CV",
                titleRight: "(24h)",
                valueText: cvDisplayText,
                valueColor: cvValueColor,
                unit: "",
                onTap: { appState.currentStatsScreen = .CV }
            )
        }
    }

    // ============================================================
    // MARK: - Tile Builder
    // ============================================================

    private func tile(
        titleLeft: String,
        titleRight: String,
        valueText: String,
        valueColor: Color?,
        unit: String?,
        onTap: @escaping () -> Void
    ) -> some View {

        Button { onTap() } label: {

            VStack(alignment: .center, spacing: 4) {

                HStack(spacing: 4) {

                    Text(titleLeft)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(titleRight)
                        .font(.caption.weight(.regular))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.65))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                valueRow(
                    valueText: valueText,
                    unit: unit,
                    valueColor: valueColor
                )
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
        }
        .buttonStyle(.plain)
    }

    private func valueRow(valueText: String, unit: String?, valueColor: Color?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {

            Text(valueText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(valueColor ?? Color.Glu.primaryBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let unit {
                Text(unit)
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // ============================================================
    // MARK: - GMI Helper (mg/dL → %)
    // ============================================================

    private func computeGmiPercent(fromMeanMgdl mean: Double) -> Double {
        3.31 + 0.02392 * mean
    }

    // ============================================================
    // MARK: - Formatting (1 decimal, locale-aware)
    // ============================================================

    private func formatNumber1(_ value: Double) -> String {
        numberFormatter1.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private let numberFormatter1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()
}

// MARK: - Preview

#Preview("GlucoseSummaryKPIsSectionV1 – Metabolic") {
    let store = HealthStore.preview()
    store.last24hGlucoseSdMgdl = 42
    store.last24hGlucoseCvPercent = 31

    // !!! UPDATED: Preview uses the canonical SSoT value
    store.glucoseMean90dMgdl = 152

    let state = AppState()

   return GlucoseSummaryKPIsSectionV1()
        .environmentObject(store)
        .environmentObject(SettingsModel.shared)
        .environmentObject(state)
        .padding()
        .background(Color.white)
}
