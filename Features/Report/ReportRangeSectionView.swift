//
//  ReportRangeSectionView.swift
//  GluVibProbe
//
//  GluVib Report (V1) — Range Section (Report Layout)
//
//  FINAL (SSoT-compliant):
//  - Presentation-only: NO period/window computations, NO metric recompute
//  - KPI grid order: Mean (top-left), GMI (top-right), CV (bottom-left), SD (bottom-right)
//  - GMI is passed in (1:1 from GMIViewModelV1 upstream)
//  - Range distribution is based ONLY on summaryWindow (already period-consistent upstream)
//  - Removes all unused / duplicate VM state (no local GMIViewModelV1, no gmiValueForWindow)
//
//  UPDATED (PDF alignment):
//  - Prevent LEFT block from stretching to full width (causes left-hugging in A4/PDF).
//  - Give the percent column a fixed width and center the whole section within the available report width.
//  - Keeps iPhone preview visually consistent, improves PDF balance.
//

import SwiftUI

struct ReportRangeSectionView: View {

    // ============================================================
    // MARK: - Inputs (presentation only)
    // ============================================================

    let windowDays: Int
    let summaryWindow: RangePeriodSummaryEntry?

    let meanText: String
    let gmiText: String

    let cvText: String
    let sdText: String

    let onTap: (() -> Void)?

    // ============================================================
    // MARK: - Layout constants
    // ============================================================

    private let barWidth: CGFloat = 28
    private let barHeight: CGFloat = 150
    private let dotSize: CGFloat = 6
    private let valueFont: Font = .caption.weight(.semibold)

    private let kpiGridSpacing: CGFloat = 10
    private let kpiTileCornerRadius: CGFloat = 10

    // UPDATED: Give KPI grid more room so "Ø Glukose" isn't truncated
    private let kpiGridWidth: CGFloat = 210

    // Dot/% vertical distribution
    private let rowsTopBottomPadding: CGFloat = 14
    private let rowsOuterSpacing: CGFloat = 10
    private let rowsInnerSpacing: CGFloat = 6

    // UPDATED: fixed width for left % column (prevents PDF left-block stretching)
    private let percentColumnWidth: CGFloat = 92

    // UPDATED: keep report sections optically centered on A4
    private let reportMaxContentWidth: CGFloat = 520

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // LEFT: Range Distribution (bar + dots/%)
            HStack(alignment: .top, spacing: 12) {

                rangeStackBar
                    .frame(width: barWidth, height: barHeight)

                percentDotsColumn
                    .frame(width: percentColumnWidth, alignment: .leading) // UPDATED
                    .frame(height: barHeight)
            }

            // RIGHT: KPI 2x2 Grid
            kpiGrid
                .frame(width: kpiGridWidth, alignment: .top)
        }
        // UPDATED: Center the whole section within a controlled report width (balances PDF layout)
        .frame(maxWidth: reportMaxContentWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    // ============================================================
    // MARK: - LEFT: Chart
    // ============================================================

    private var rangeStackBar: some View {
        GeometryReader { geo in
            let h = geo.size.height

            let cov = max(0, summaryWindow?.coverageMinutes ?? 0)
            let total = max(1, cov)

            let vl = max(0, summaryWindow?.veryLowMinutes ?? 0)
            let lo = max(0, summaryWindow?.lowMinutes ?? 0)
            let ir = max(0, summaryWindow?.inRangeMinutes ?? 0)
            let hi = max(0, summaryWindow?.highMinutes ?? 0)
            let vh = max(0, summaryWindow?.veryHighMinutes ?? 0)

            let vlH = h * CGFloat(Double(vl) / Double(total))
            let loH = h * CGFloat(Double(lo) / Double(total))
            let irH = h * CGFloat(Double(ir) / Double(total))
            let hiH = h * CGFloat(Double(hi) / Double(total))
            let vhH = h * CGFloat(Double(vh) / Double(total))

            ZStack(alignment: .bottom) {

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.25))

                VStack(spacing: 0) {
                    Rectangle().fill(colorVeryHigh).frame(height: vhH)
                    Rectangle().fill(colorHigh).frame(height: hiH)
                    Rectangle().fill(colorInRange).frame(height: irH)
                    Rectangle().fill(colorLow).frame(height: loH)
                    Rectangle().fill(colorVeryLow).frame(height: vlH)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))

                RoundedRectangle(cornerRadius: 2)
                    .stroke(ReportStyle.dividerColor.opacity(0.9), lineWidth: 1)
            }
        }
        .accessibilityLabel(Text("Time in Range distribution"))
    }

    private var colorVeryLow: Color { Color.Glu.acidCGMRed }
    private var colorLow: Color { Color.yellow.opacity(0.80) }
    private var colorInRange: Color { Color.Glu.metabolicDomain }
    private var colorHigh: Color { Color.yellow.opacity(0.80) }
    private var colorVeryHigh: Color { Color.Glu.acidCGMRed }

    // ============================================================
    // MARK: - LEFT: Dots + % Column
    // ============================================================

    private var percentDotsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer(minLength: rowsTopBottomPadding)

            percentDotRow(color: colorVeryHigh, text: veryHighPctText, valueColor: ReportStyle.textColor.opacity(0.92))
            Spacer(minLength: rowsOuterSpacing)

            percentDotRow(color: colorHigh, text: highPctText, valueColor: ReportStyle.textColor.opacity(0.92))
            Spacer(minLength: rowsInnerSpacing)

            percentDotRow(color: colorInRange, text: inRangePctText, valueColor: Color.green)
            Spacer(minLength: rowsInnerSpacing)

            percentDotRow(color: colorLow, text: lowPctText, valueColor: ReportStyle.textColor.opacity(0.92))
            Spacer(minLength: rowsOuterSpacing)

            percentDotRow(color: colorVeryLow, text: veryLowPctText, valueColor: ReportStyle.textColor.opacity(0.92))

            Spacer(minLength: rowsTopBottomPadding)
        }
        .font(valueFont)
        .frame(maxHeight: .infinity)
    }

    private func percentDotRow(color: Color, text: String, valueColor: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)

            Text(text)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // ============================================================
    // MARK: - Percent Helpers (coverage-based; uses summaryWindow only)
    // ============================================================

    private var coverageMinutesSafe: Int { max(0, summaryWindow?.coverageMinutes ?? 0) }

    private func pctText(minutes: Int) -> String {
        let m = max(0, minutes)
        let cov = max(0, coverageMinutesSafe)
        guard cov > 0 else { return "–" }
        guard m > 0 else { return "0%" }

        let pct = (Double(m) / Double(cov)) * 100.0
        if pct > 0 && pct < 1.0 { return "< 1%" }

        let rounded = Int(pct.rounded())
        return "\(max(0, min(100, rounded)))%"
    }

    private var veryHighPctText: String { pctText(minutes: summaryWindow?.veryHighMinutes ?? 0) }
    private var highPctText: String { pctText(minutes: summaryWindow?.highMinutes ?? 0) }
    private var inRangePctText: String { pctText(minutes: summaryWindow?.inRangeMinutes ?? 0) }
    private var lowPctText: String { pctText(minutes: summaryWindow?.lowMinutes ?? 0) }
    private var veryLowPctText: String { pctText(minutes: summaryWindow?.veryLowMinutes ?? 0) }

    // ============================================================
    // MARK: - RIGHT: KPI Grid (2x2)
    // ============================================================

    private var kpiGrid: some View {
        VStack(alignment: .leading, spacing: kpiGridSpacing) {

            HStack(spacing: kpiGridSpacing) {
                kpiTile(title: "Ø Glucose", value: meanText, unit: "")
                kpiTile(title: "GMI", value: gmiText, unit: "%")
            }

            HStack(spacing: kpiGridSpacing) {
                kpiTile(title: "CV", value: cvText, unit: "%")
                kpiTile(title: "SD", value: sdText, unit: "")
            }
        }
    }

    private func kpiTile(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ReportStyle.textColor.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.90)

            HStack(alignment: .firstTextBaseline, spacing: 4) {

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReportStyle.textColor.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !unit.isEmpty, value != "–" {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(ReportStyle.textColor.opacity(0.60))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .background(Color.white.opacity(0.30))
        .overlay(
            RoundedRectangle(cornerRadius: kpiTileCornerRadius)
                .stroke(ReportStyle.dividerColor.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: kpiTileCornerRadius))
    }
}

// MARK: - Preview
#Preview("ReportRangeSectionView — Range + KPI Grid") {

    let sample30 = RangePeriodSummaryEntry(
        id: UUID(),
        days: 30,
        veryLowMinutes: 5,
        lowMinutes: 10,
        inRangeMinutes: 410,
        highMinutes: 70,
        veryHighMinutes: 10,
        coverageMinutes: 495,
        expectedMinutes: 500,
        coverageRatio: 0.99,
        isPartial: false
    )

    return VStack(alignment: .leading, spacing: 12) {
        ReportRangeSectionView(
            windowDays: 30,
            summaryWindow: sample30,
            meanText: "142",
            gmiText: "6.7",
            cvText: "34.2",
            sdText: "48",
            onTap: nil
        )
    }
    .padding(16)
    .background(Color.white)
}
