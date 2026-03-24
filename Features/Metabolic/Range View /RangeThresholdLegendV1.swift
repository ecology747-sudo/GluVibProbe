//
//  RangeThresholdLegendV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Range Threshold Legend
//  - Visual legend for glucose zones
//  - Uses SettingsModel thresholds (Very Low / TIR / Very High)
//  - Entire card is tappable → opens Metabolic Settings
//  - Card style matches GluVibCardFrame (central modifier)
//

import SwiftUI

struct RangeThresholdLegendV1: View {

    @EnvironmentObject private var settings: SettingsModel

    let onOpenSettings: () -> Void

    private let accent = Color.Glu.metabolicDomain

    var body: some View {

        Button {
            onOpenSettings()
        } label: {

            VStack(alignment: .leading, spacing: 10) {

                VStack(alignment: .leading, spacing: 8) {

                    legendRow(
                        color: colorVeryLow,
                        title: L10n.Range.thresholdVeryLow,
                        valueText: "< \(format(settings.veryLowLimit))"
                    )

                    legendRow(
                        color: colorLow,
                        title: L10n.Range.thresholdLow,
                        valueText: "\(format(settings.veryLowLimit)) – \(format(settings.glucoseMin))"
                    )

                    legendRow(
                        color: colorInRange,
                        title: L10n.Range.thresholdInRange,
                        valueText: "\(format(settings.glucoseMin)) – \(format(settings.glucoseMax))"
                    )

                    legendRow(
                        color: colorHigh,
                        title: L10n.Range.thresholdHigh,
                        valueText: "\(format(settings.glucoseMax)) – \(format(settings.veryHighLimit))"
                    )

                    legendRow(
                        color: colorVeryHigh,
                        title: L10n.Range.thresholdVeryHigh,
                        valueText: "> \(format(settings.veryHighLimit))"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading) // UPDATED

                Text(L10n.Range.thresholdsHint)
                    .font(.caption2)
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.65))
                    .multilineTextAlignment(.center) // UPDATED
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading) // UPDATED
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .gluVibCardFrame(domainColor: accent)
        }
        .frame(maxWidth: .infinity) // UPDATED
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Range.openSettingsAccessibility)
    }

    // ------------------------------------------------------------
    // MARK: - Row
    // ------------------------------------------------------------

    private func legendRow(
        color: Color,
        title: String,
        valueText: String
    ) -> some View {

        HStack(spacing: 10) {

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))

            Spacer()

            Text("\(valueText) \(settings.glucoseUnit.label)")
                .font(.caption2)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading) // UPDATED
    }

    // ------------------------------------------------------------
    // MARK: - Formatting
    // ------------------------------------------------------------

    private func format(_ mgdl: Int) -> String {
        if settings.glucoseUnit == .mgdL {
            return "\(mgdl)"
        } else {
            let mmol = Double(mgdl) / 18.0
            return String(format: "%.1f", mmol)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Colors (5-Zone)
    // ------------------------------------------------------------

    private var colorVeryLow: Color { Color.Glu.acidCGMRed }
    private var colorLow: Color { Color.yellow.opacity(0.80) }
    private var colorInRange: Color { Color.Glu.metabolicDomain }
    private var colorHigh: Color { Color.yellow.opacity(0.80) }
    private var colorVeryHigh: Color { Color.Glu.acidCGMRed }
}

// MARK: - Preview

#Preview("RangeThresholdLegendV1") {
    RangeThresholdLegendV1(onOpenSettings: {})
        .environmentObject(SettingsModel.shared)
        .padding()
        .background(Color.white)
}
