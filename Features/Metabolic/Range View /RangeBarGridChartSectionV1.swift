//
//  RangeBarGridSectionV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Range Grid (7/14/30/90)
//

import SwiftUI

struct RangeBarGridSectionV1: View {

    // ============================================================
    // MARK: - Tile Input
    // ============================================================

    struct TileInput: Identifiable {
        let id = UUID()
        let title: String
        let summary: RangePeriodSummaryEntry?
        let periodText: String?
    }

    let tiles: [TileInput]

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let borderColor = Color.Glu.metabolicDomain

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(tiles) { tile in
                RangeBarTileV1(
                    title: tile.title,
                    summary: tile.summary,
                    periodText: tile.periodText,
                    borderColor: borderColor
                )
            }
        }
        .padding(.vertical, 6)
    }
}

// ============================================================
// MARK: - Tile
// ============================================================

private struct RangeBarTileV1: View {

    @EnvironmentObject private var settings: SettingsModel

    let title: String
    let summary: RangePeriodSummaryEntry?
    let periodText: String?
    let borderColor: Color

    private let barHeight: CGFloat = 170
    private let barWidth: CGFloat = 64

    // Threshold rules (local to this file, except TIR which is Settings-driven)
    private let targetVeryHighMaxPct: Double = 5.0
    private let targetVeryLowMaxPct: Double = 1.0
    private let targetHighPlusVeryHighMaxPct: Double = 25.0
    private let targetLowPlusVeryLowMaxPct: Double = 4.0

    // TIR warn buffer (optional UI nuance; target itself comes from Settings)
    private let tirWarnBufferPct: Double = 10.0

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))

            HStack(alignment: .center, spacing: 18) {

                rangeStackBar
                    .frame(width: barWidth, height: barHeight)

                labelsColumn
                    .frame(height: barHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 2) {
                periodRow
                bottomRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .gluVibCardFrame(domainColor: borderColor)
    }

    // ============================================================
    // MARK: - Grenzwertlogik (wie vereinbart)
    // ============================================================
    //
    // 1) Very High: Zielwert < 5%
    //    - Wenn Very High > 5% => Very High Wert rot
    //
    // 2) High + Very High kombiniert:
    //    - Wenn (High + Very High) > 25% => beide Werte (High UND Very High) rot
    //    - Edge Case: Very High = 0% und High > 25% => beide rot (trotz 0%)
    //    - Ausnahme: Wenn Combo NICHT > 25% und die Überschreitung kommt NUR durch Very High > 5%,
    //      dann NUR Very High rot, High bleibt normal.
    //
    // 3) TIR (inRange) Zielwert > 70% (bereits berücksichtigt in Metabolic Settings):
    //    - Wenn TIR >= Target => TIR Wert grün
    //    - Wenn TIR knapp unter Target (Target-10 .. <Target) => gelb (Warn)
    //    - Wenn TIR deutlich < Target-10 => rot
    //
    // 4) Very Low: Zielwert < 1%
    //    - Wenn Very Low > 1% => Very Low Wert rot
    //
    // 5) Low + Very Low kombiniert:
    //    - Wenn (Low + Very Low) > 4% => beide Werte (Low UND Very Low) rot
    //    - Edge Case: Very Low = 0% und Low > 4% => beide rot (trotz 0%)
    //    - Ausnahme analog: Wenn Combo NICHT > 4% und die Überschreitung kommt NUR durch Very Low > 1%,
    //      dann NUR Very Low rot, Low bleibt normal.
    //
    // Hinweis: Nur die Zahlen-Labels werden nach Status eingefärbt.
    //          Farben im Balken bleiben unverändert (Designfarben).
    //

    // ------------------------------------------------------------
    // MARK: - Derived % (from coverage)
    // ------------------------------------------------------------

    private var coverageMinutesSafe: Int {
        max(0, summary?.coverageMinutes ?? 0)
    }

    private func pct(_ minutes: Int) -> Double {
        let cov = max(0, coverageMinutesSafe)
        guard cov > 0 else { return 0 }
        return (Double(max(0, minutes)) / Double(cov)) * 100.0
    }

    private var veryHighPct: Double { pct(summary?.veryHighMinutes ?? 0) }
    private var highPct: Double { pct(summary?.highMinutes ?? 0) }
    private var inRangePct: Double { pct(summary?.inRangeMinutes ?? 0) }
    private var lowPct: Double { pct(summary?.lowMinutes ?? 0) }
    private var veryLowPct: Double { pct(summary?.veryLowMinutes ?? 0) }

    private var highComboPct: Double { highPct + veryHighPct }
    private var lowComboPct: Double { lowPct + veryLowPct }

    // ------------------------------------------------------------
    // MARK: - Label Status Colors (ONLY for numbers)
    // ------------------------------------------------------------

    private var isHighComboBad: Bool { highComboPct > targetHighPlusVeryHighMaxPct }
    private var isLowComboBad: Bool { lowComboPct > targetLowPlusVeryLowMaxPct }

    private var isVeryHighBadSolo: Bool { veryHighPct > targetVeryHighMaxPct }
    private var isVeryLowBadSolo: Bool { veryLowPct > targetVeryLowMaxPct }

    private var inRangeTextStatusColor: Color {
        let target = Double(settings.tirTargetPercent)
        if inRangePct >= target { return Color.green }
        if inRangePct >= max(0, target - tirWarnBufferPct) { return Color.yellow.opacity(0.85) }
        return Color.Glu.acidCGMRed
    }

    private var veryHighTextStatusColor: Color {
        if isHighComboBad { return Color.Glu.acidCGMRed }
        if isVeryHighBadSolo { return Color.Glu.acidCGMRed }
        return Color.Glu.primaryBlue.opacity(0.92)
    }

    private var highTextStatusColor: Color {
        if isHighComboBad { return Color.Glu.acidCGMRed }
        return Color.Glu.primaryBlue.opacity(0.92)
    }

    private var veryLowTextStatusColor: Color {
        if isLowComboBad { return Color.Glu.acidCGMRed }
        if isVeryLowBadSolo { return Color.Glu.acidCGMRed }
        return Color.Glu.primaryBlue.opacity(0.92)
    }

    private var lowTextStatusColor: Color {
        if isLowComboBad { return Color.Glu.acidCGMRed }
        return Color.Glu.primaryBlue.opacity(0.92)
    }

    // ------------------------------------------------------------
    // MARK: - Bar (UNCHANGED colors)
    // ------------------------------------------------------------

    private var rangeStackBar: some View {
        GeometryReader { geo in
            let h = geo.size.height

            let cov = max(0, summary?.coverageMinutes ?? 0)

            let vl = max(0, summary?.veryLowMinutes ?? 0)
            let lo = max(0, summary?.lowMinutes ?? 0)
            let ir = max(0, summary?.inRangeMinutes ?? 0)
            let hi = max(0, summary?.highMinutes ?? 0)
            let vh = max(0, summary?.veryHighMinutes ?? 0)

            let total = max(1, cov)

            let vlH = h * CGFloat(Double(vl) / Double(total))
            let loH = h * CGFloat(Double(lo) / Double(total))
            let irH = h * CGFloat(Double(ir) / Double(total))
            let hiH = h * CGFloat(Double(hi) / Double(total))
            let vhH = h * CGFloat(Double(vh) / Double(total))

            ZStack(alignment: .bottom) {

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.35))

                VStack(spacing: 0) {
                    Rectangle().fill(colorVeryHigh).frame(height: vhH)
                    Rectangle().fill(colorHigh).frame(height: hiH)
                    Rectangle().fill(colorInRange).frame(height: irH)
                    Rectangle().fill(colorLow).frame(height: loH)
                    Rectangle().fill(colorVeryLow).frame(height: vlH)
                }

                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 1)
            }
        }
    }

    // ------------------------------------------------------------
    // MARK: - Colors (Bar)
    // ------------------------------------------------------------

    private var colorVeryLow: Color { Color.Glu.acidCGMRed }
    private var colorLow: Color { Color.yellow.opacity(0.80) }
    private var colorInRange: Color { Color.Glu.metabolicDomain }
    private var colorHigh: Color { Color.yellow.opacity(0.80) }
    private var colorVeryHigh: Color { Color.Glu.acidCGMRed }

    // ------------------------------------------------------------
    // MARK: - Labels (Dots stay category colors; ONLY numbers get status colors)
    // ------------------------------------------------------------

    private var labelsColumn: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width

            let cov = max(0, summary?.coverageMinutes ?? 0)

            let veryHighTxt = pctText(minutes: summary?.veryHighMinutes ?? 0, coverage: cov)
            let highTxt     = pctText(minutes: summary?.highMinutes ?? 0, coverage: cov)
            let inRangeTxt  = pctText(minutes: summary?.inRangeMinutes ?? 0, coverage: cov)
            let lowTxt      = pctText(minutes: summary?.lowMinutes ?? 0, coverage: cov)
            let veryLowTxt  = pctText(minutes: summary?.veryLowMinutes ?? 0, coverage: cov)

            let topMargin: CGFloat = 12
            let bottomMargin: CGFloat = 12

            let yVeryHigh = clampY(h * 0.14, h: h, top: topMargin, bottom: bottomMargin)
            let yHigh     = clampY(h * 0.30, h: h, top: topMargin, bottom: bottomMargin)
            let yInRange  = clampY(h * 0.54, h: h, top: topMargin, bottom: bottomMargin)
            let yLow      = clampY(h * 0.76, h: h, top: topMargin, bottom: bottomMargin)
            let yVeryLow  = clampY(h * 0.92, h: h, top: topMargin, bottom: bottomMargin)

            ZStack(alignment: .topLeading) {

                pctRow(
                    text: veryHighTxt,
                    dotColor: colorVeryHigh,
                    valueTextColor: veryHighTextStatusColor
                )
                .frame(width: w, alignment: .leading)
                .position(x: w / 2, y: yVeryHigh)

                pctRow(
                    text: highTxt,
                    dotColor: colorHigh,
                    valueTextColor: highTextStatusColor
                )
                .frame(width: w, alignment: .leading)
                .position(x: w / 2, y: yHigh)

                pctRow(
                    text: inRangeTxt,
                    dotColor: colorInRange,
                    valueTextColor: inRangeTextStatusColor
                )
                .frame(width: w, alignment: .leading)
                .position(x: w / 2, y: yInRange)

                pctRow(
                    text: lowTxt,
                    dotColor: colorLow,
                    valueTextColor: lowTextStatusColor
                )
                .frame(width: w, alignment: .leading)
                .position(x: w / 2, y: yLow)

                pctRow(
                    text: veryLowTxt,
                    dotColor: colorVeryLow,
                    valueTextColor: veryLowTextStatusColor
                )
                .frame(width: w, alignment: .leading)
                .position(x: w / 2, y: yVeryLow)
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private func clampY(_ y: CGFloat, h: CGFloat, top: CGFloat, bottom: CGFloat) -> CGFloat {
        min(max(y, top), h - bottom)
    }

    private func pctRow(text: String, dotColor: Color, valueTextColor: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)

            percentValueView(text)
                .foregroundStyle(valueTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    // ------------------------------------------------------------
    // MARK: - Period Row (CV)
    // ------------------------------------------------------------

    private var periodRow: some View {
        let valueText = periodText ?? "–"
        let valueColor = cvStatusColor(from: valueText)

        return HStack {
            HStack(spacing: 4) {
                Text("CV")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))

                Text("(<\(settings.cvTargetPercent)%)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.55))
            }

            Spacer()

            percentValueView(valueText)
                .font(.caption.weight(.semibold))
                .foregroundColor(valueColor ?? Color.Glu.primaryBlue.opacity(0.95))
        }
        .padding(.top, 2)
    }

    // ------------------------------------------------------------
    // MARK: - Bottom
    // ------------------------------------------------------------

    private var bottomRow: some View {
        let cov = max(0, summary?.coverageMinutes ?? 0)
        let exp = max(0, summary?.expectedMinutes ?? 0)

        let coveragePct: String = {
            guard exp > 0 else { return "–" }
            let pct = Int((Double(cov) / Double(exp) * 100.0).rounded())
            return "\(max(0, min(100, pct)))%"
        }()

        return HStack {
            Text("Coverage")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))

            Spacer()

            Text(coveragePct)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
        }
        .padding(.top, 2)
    }

    // ------------------------------------------------------------
    // MARK: - Helpers
    // ------------------------------------------------------------

    private func pctText(minutes: Int, coverage: Int) -> String {
        let m = max(0, minutes)
        let cov = max(0, coverage)
        guard cov > 0 else { return "–" }
        guard m > 0 else { return "0%" }

        let pct = (Double(m) / Double(cov)) * 100.0

        if pct > 0 && pct < 1.0 {
            return "<1%"
        }

        let rounded = Int(pct.rounded())
        return "\(max(0, min(100, rounded)))%"
    }

    private func percentValueView(_ text: String) -> some View {
        guard text.hasPrefix("<") else { return AnyView(Text(text)) }

        let rest = String(text.dropFirst())

        return AnyView(
            HStack(alignment: .center, spacing: 3) {
                Text("<")
                    .font(.caption2.weight(.semibold))
                Text(rest)
                    .font(.caption.weight(.semibold))
            }
        )
    }

    // ------------------------------------------------------------
    // MARK: - CV Status Colors
    // ------------------------------------------------------------

    private func cvStatusColor(from text: String) -> Color? {
        guard let value = cvValueForColor(from: text), value > 0 else { return nil }
        return statusColorHigherIsWorse(
            value: value,
            target: Double(settings.cvTargetPercent),
            warnBuffer: 4.0
        )
    }

    private func cvValueForColor(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "–" else { return nil }

        let isLessThan = trimmed.hasPrefix("<")
        let cleaned = trimmed
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty, let v = Double(cleaned) else { return nil }
        return isLessThan ? max(0.0, v - 0.5) : v
    }

    private func statusColorHigherIsWorse(value: Double, target: Double, warnBuffer: Double) -> Color {
        if value <= target { return Color.green }
        if value <= (target + warnBuffer) { return Color.yellow.opacity(0.85) }
        return Color.Glu.acidCGMRed
    }
}

// MARK: - Preview

#Preview("RangeBarGridSectionV1 – 2x2 Tiles") {

    // Szenario 11 (TIR deutlich < Target => TIR-Label rot)
    // Summe = 100% (kein weißer Balken): VL 1% + Low 3% + IR 55% + High 24% + VH 17% = 100%

    let sample7 = RangePeriodSummaryEntry(
        id: UUID(),
        days: 7,
        veryLowMinutes: 10,      // 1%
        lowMinutes: 30,          // 3%
        inRangeMinutes: 550,     // 55%  -> TIR deutlich < 70% => rot
        highMinutes: 240,        // 24%
        veryHighMinutes: 170,    // 17%  -> High+VH = 41% (rot-Combo ist hier ok, weil wir Szenario 11 primär TIR rot sehen wollen)
        coverageMinutes: 1000,
        expectedMinutes: 1000,
        coverageRatio: 1.0,
        isPartial: false
    )
    let sample14 = RangePeriodSummaryEntry(
        id: UUID(),
        days: 14,
        veryLowMinutes: 0,
        lowMinutes: 50,
        inRangeMinutes: 900,
        highMinutes: 50,
        veryHighMinutes: 0,
        coverageMinutes: 1000,
        expectedMinutes: 1000,
        coverageRatio: 1.0,
        isPartial: false
    )

    let sample30 = RangePeriodSummaryEntry(
        id: UUID(),
        days: 30,
        veryLowMinutes: 20,
        lowMinutes: 30,
        inRangeMinutes: 900,
        highMinutes: 50,
        veryHighMinutes: 0,
        coverageMinutes: 1000,
        expectedMinutes: 1000,
        coverageRatio: 1.0,
        isPartial: false
    )

    let sample90 = RangePeriodSummaryEntry(
        id: UUID(),
        days: 90,
        veryLowMinutes: 5,
        lowMinutes: 20,
        inRangeMinutes: 900,
        highMinutes: 105,
        veryHighMinutes: 60,
        coverageMinutes: 1000,
        expectedMinutes: 1000,
        coverageRatio: 1.0,
        isPartial: false
    )

    let tiles: [RangeBarGridSectionV1.TileInput] = [
        .init(title: "7 Days",  summary: sample7,  periodText: "45%"),
        .init(title: "14 Days", summary: sample14, periodText: "32%"),
        .init(title: "30 Days", summary: sample30, periodText: "<1%"),
        .init(title: "90 Days", summary: sample90, periodText: "41%")
    ]

    return RangeBarGridSectionV1(tiles: tiles)
        .environmentObject(SettingsModel.shared)
        .padding()
        .background(Color.white)
}
