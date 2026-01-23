//
//  ReportThresholdsSectionView.swift
//  GluVibProbe
//
//  GluVib Report (V1) — Thresholds Section (Global)
//
//  UPDATED:
//  - Adaptive legend (PDF = single line, iPhone = two lines)
//  - Uses identical font & size as explanation text above
//  - Centers "Your Current Thresholds:" horizontally
//

import SwiftUI

struct ReportThresholdsSectionView: View {

    @EnvironmentObject private var settings: SettingsModel

    let onOpenMetabolicSettings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("All report calculations and visualizations are based on the thresholds configured in Metabolic Settings.")
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            thresholdsLegendAdaptive
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenMetabolicSettings?()
        }
    }

    // ============================================================
    // MARK: - Adaptive Legend (Wide vs. Compact)
    // ============================================================

    private var thresholdsLegendAdaptive: some View {
        ViewThatFits(in: .horizontal) {
            thresholdsLegendSingleLineWide
            thresholdsLegendTwoLineCompact
        }
    }

    // ============================================================
    // MARK: - Wide (PDF / iPad): Single Line
    // ============================================================

    private var thresholdsLegendSingleLineWide: some View {
        HStack(spacing: 10) {

            Text("Your Current Thresholds:")
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                .lineLimit(1)

            thresholdsLegendCore
        }
        .font(ReportStyle.FontToken.caption)
        .foregroundStyle(ReportStyle.textColor.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.top, 2)
    }

    // ============================================================
    // MARK: - Compact (iPhone): Two Lines
    // ============================================================

    private var thresholdsLegendTwoLineCompact: some View {
        VStack(spacing: 4) {

            Text("Your Current Thresholds:")
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            thresholdsLegendCore
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
    }

    // ============================================================
    // MARK: - Core Legend Row (Dots + Ranges)
    // ============================================================

    private var thresholdsLegendCore: some View {
        HStack(spacing: 8) {

            zoneDot(colorVeryLow)
            Text("< \(format(settings.veryLowLimit))")

            zoneDot(colorLow)
            Text("\(format(settings.veryLowLimit))–\(format(settings.glucoseMin))")

            zoneDot(colorInRange)
            Text("\(format(settings.glucoseMin))–\(format(settings.glucoseMax))")

            zoneDot(colorHigh)
            Text("\(format(settings.glucoseMax))–\(format(settings.veryHighLimit))")

            zoneDot(colorVeryHigh)
            Text("> \(format(settings.veryHighLimit))")
        }
        .monospacedDigit()
    }

    private func zoneDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }

    // ============================================================
    // MARK: - Formatting
    // ============================================================

    private func format(_ mgdl: Int) -> String {
        if settings.glucoseUnit == .mgdL {
            return "\(mgdl)"
        } else {
            let mmol = Double(mgdl) / 18.0
            return String(format: "%.1f", mmol)
        }
    }

    // ============================================================
    // MARK: - Colors
    // ============================================================

    private var colorVeryLow: Color { Color.Glu.acidCGMRed }
    private var colorLow: Color { Color.yellow.opacity(0.80) }
    private var colorInRange: Color { Color.Glu.metabolicDomain }
    private var colorHigh: Color { Color.yellow.opacity(0.80) }
    private var colorVeryHigh: Color { Color.Glu.acidCGMRed }
}

// MARK: - Preview
#Preview("ReportThresholdsSectionView") {
    VStack(alignment: .leading, spacing: 12) {
        ReportThresholdsSectionView(onOpenMetabolicSettings: nil)
            .environmentObject(SettingsModel.shared)
    }
    .padding(16)
    .background(Color.white)
}
