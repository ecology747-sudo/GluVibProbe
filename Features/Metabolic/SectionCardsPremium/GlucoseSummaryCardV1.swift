//
//  GlucoseSummaryCardV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Glucose Summary Card (REAL)
//  - Uses HealthStore Published KPIs (Last 24h + optional 90d mean for GMI)
//  - No extra ViewModel needed (SSoT = HealthStore)
//

import SwiftUI

struct GlucoseSummaryCardV1: View {

    // ============================================================
    // MARK: - SSoT
    // ============================================================

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState                     // !!! NEW (Tap → navigate to TIR)

    // ============================================================
    // MARK: - Layout Controls (as in your Design)
    // ============================================================

    private var tirThreshold: Double {                                     // !!! UPDATED
        Double(settings.tirTargetPercent) / 100.0
    }
    private let cardPadding: CGFloat = 16

    private let gapHeaderToGlucose: CGFloat = 10
    private let gapGlucoseValueToBar: CGFloat = 3

    private let gapGlucoseToBadges: CGFloat = 14
    private let gapBadgesToTir: CGFloat = 14

    private let gapTirValueToBar: CGFloat = 3

    // ============================================================
    // MARK: - Chart Scale (Settings-driven)  // !!! NEW (Step 2)
    // ============================================================

    private var chartMaxGlucoseMgdl: Double {                              // !!! NEW
        // mindestens 300; sonst veryHigh + Puffer
        let padded = Double(settings.veryHighLimit) + 20
        return max(300, padded)
    }

    // ============================================================
    // MARK: - Derived Values (Last 24h)
    // ============================================================

    private var avgCvPercentInt: Int {
        guard let cv = healthStore.last24hGlucoseCvPercent else { return 0 }
        return Int(cv.rounded())
    }

    /// Ø TIR% (Last 24h) — based on minutes buckets + coverage (no extrapolation)
    private var avgTirPercentInt: Int {
        let coverage = max(0, healthStore.last24hTIRCoverageMinutes)
        guard coverage > 0 else { return 0 }

        let inRange = max(0, healthStore.last24hTIRInRangeMinutes)
        let ratio = Double(inRange) / Double(coverage)
        return Int((ratio * 100.0).rounded())
    }

    /// GMI(90) — derived from mean90 mg/dL (if available)
    private var gmi90dPercent: Double? {
        guard let mean90 = healthStore.glucoseMean90dMgdl else { return nil }
        return computeGmiPercent(fromMeanMgdl: mean90)
    }

    // ============================================================
    // MARK: - Glucose Unit (CENTRAL via SettingsUnits.swift)
    // ============================================================

    private var avgGlucoseDisplayText: String {
        let mgdl = healthStore.last24hGlucoseMeanMgdl ?? 0
        let digits = (settings.glucoseUnit == .mgdL) ? 0 : 1
        return settings.glucoseUnit.formattedNumber(fromMgdl: mgdl, fractionDigits: digits)
    }

    private var avgGlucoseUnitText: String { settings.glucoseUnit.label }

    private var sdDisplayText: String {
        guard let sdMgdl = healthStore.last24hGlucoseSdMgdl, sdMgdl > 0 else { return "–" }

        let digits = (settings.glucoseUnit == .mgdL) ? 0 : 1
        return settings.glucoseUnit.formatted(fromMgdl: sdMgdl, fractionDigits: digits, includeUnit: true)
    }

    private var cvDisplayText: String {
        let v = avgCvPercentInt
        return v > 0 ? "\(v)%" : "–"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            header
            Gap(gapHeaderToGlucose)

            glucoseSection
            Gap(gapBadgesToTir)          // ✅ statt gapGlucoseToBadges (Badges sind ja nicht mehr dazwischen)

            tirSectionTappable           // !!! NEW (TIR tap → TimeInRangeViewV1)
            Gap(gapGlucoseToBadges)      // ✅ Abstand zwischen TIR-Chart und Tiles

            sdGmiCvSection               // ✅ jetzt ganz unten
        }
        .padding(cardPadding)
        .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
    }
}

// ============================================================
// MARK: - Sections (Top → Bottom)
// ============================================================

private extension GlucoseSummaryCardV1 {

    var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text("Ø")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.Glu.primaryBlue)

            Text("Glucose")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.90))

            Text("(24h)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))

            Spacer()

            // Messungen / Max (immer sichtbar, rechtsbündig)
            let coverage = max(0, healthStore.last24hTIRCoverageMinutes)          // Minuten mit Daten (0..1440)
            let samples = Int((Double(coverage) / 5.0).rounded())                 // 5-Minuten Raster -> 0..288
            let maxSamples = 288

            Text("CGM \(samples) / \(maxSamples)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.65))
        }
    }

    // ====================================================
    // Ø Glucose
    // ====================================================

    var glucoseSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            Gap(gapGlucoseValueToBar)

            GlucoseFiveZoneBar(
                valueMgdl: healthStore.last24hGlucoseMeanMgdl ?? 0,
                maxMgdl: chartMaxGlucoseMgdl,                                // !!! UPDATED (Step 2)
                avgText: avgGlucoseDisplayText,                              // !!! NEW
                unitText: avgGlucoseUnitText                                 // !!! NEW
            )
        }
    }

    // ====================================================
    // SD + GMI(90) + CV (uniform tiles)
    // ====================================================

    var sdGmiCvSection: some View {
        HStack(spacing: 12) {

            UniformMiniMetricTile(
                title: "SD",
                value: sdDisplayText
            )

            UniformMiniMetricTile(
                title: "GMI (90)",
                value: gmi90Text
            )

            UniformMiniMetricTile(
                title: "CV",
                value: cvDisplayText,
                secondaryValue: "(< 36%)"
            )
        }
    }

    private var gmi90Text: String {
        guard let gmi = gmi90dPercent else { return "–" }
        return String(format: "%.1f%%", gmi)
    }

    // ====================================================
    // Ø TIR (tappable)
    // ====================================================

    var tirSectionTappable: some View {                                     // !!! NEW
        Button {
            appState.currentStatsScreen = .timeInRange
        } label: {
            tirSection
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Time in Range")
    }

    var tirSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 1) Title line (wie Ø Glucose)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("TIR")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("(24h)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))

                Spacer()
            }

            Gap(gapTirValueToBar)

            // 2) TIR-Bar
            TIRBar(
                percent: Double(avgTirPercentInt) / 100.0,
                threshold: tirThreshold
            )
        }
    }
}

// ============================================================
// MARK: - Adjustable Gap Helper
// ============================================================

private struct Gap: View {
    let height: CGFloat
    init(_ height: CGFloat) { self.height = height }
    var body: some View { Color.clear.frame(height: height) }
}

// ============================================================
// MARK: - Uniform Mini Metric Tile
// ============================================================

private struct UniformMiniMetricTile: View {

    let title: String
    let value: String
    let secondaryValue: String?

    init(
        title: String,
        value: String,
        secondaryValue: String? = nil
    ) {
        self.title = title
        self.value = value
        self.secondaryValue = secondaryValue
    }

    private let titleFont: Font = .system(size: 13, weight: .bold)
    private let valueFont: Font = .system(size: 19, weight: .bold)
    private let fixedHeight: CGFloat = 54

    var body: some View {
        VStack(alignment: .center, spacing: 6) {

            Text(title)
                .font(titleFont)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))

            HStack(alignment: .lastTextBaseline, spacing: 4) {

                Spacer(minLength: 0)

                Text(value)
                    .font(valueFont)
                    .foregroundColor(Color.Glu.primaryBlue)

                if let secondaryValue {
                    Text(secondaryValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: fixedHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Glu.backgroundSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.Glu.metabolicDomain.opacity(0.65), lineWidth: 1.2)
        )
    }
}

// ============================================================
// MARK: - Glucose Five-Zone Bar (Settings-driven + Marker + Avg Text + 4 Labels)
// ============================================================

private struct GlucoseFiveZoneBar: View {

    @EnvironmentObject private var settings: SettingsModel

    let valueMgdl: Double
    let maxMgdl: Double

    // Avg text above marker
    let avgText: String
    let unitText: String

    // ============================================================
    // MARK: - STELLSCHRAUBEN (Layout-Tuning) ✅
    // ============================================================

    // Bar
    private let barH: CGFloat = 10
    private let r: CGFloat = 6

    // Marker
    private let markerW: CGFloat = 20
    private let markerH: CGFloat = 20
    private let markerGap: CGFloat = 2

    // Badge (Avg)
    private let badgeHPad: CGFloat = 10
    private let badgeVPad: CGFloat = 5
    private let badgeTextValueSize: CGFloat = 20
    private let badgeTextUnitSize: CGFloat = 13
    private let badgeCornerLineW: CGFloat = 1.6

    private let badgeOffsetY: CGFloat = -20     // ✅ negativer = Badge höher

    // Marker vertical alignment (triangle)
    private let triangleOffsetY: CGFloat = 17    // ✅ kleiner = Dreieck höher / größer = tiefer

    // Labels
    private let labelsGap: CGFloat = 4
    private let labelsH: CGFloat = 12

    // Inset (clamp)
    private let clampInset: CGFloat = 12

    // ============================================================
    // MARK: - Badge Width Measurement ✅ (NEU)
    // ============================================================

    @State private var measuredBadgeW: CGFloat = 0

    private struct BadgeWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    // ============================================================
    // MARK: - FIXED TOTAL HEIGHT ✅
    // ============================================================

    private var markerLaneH: CGFloat {
        (badgeVPad * 2) + CGFloat(badgeTextValueSize) + 6 + markerH + markerGap
    }

    private var totalFixedHeight: CGFloat {
        markerLaneH + barH + labelsGap + labelsH
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            // ============================================================
            // MARK: - Values (Settings)
            // ============================================================

            let veryLow  = Double(settings.veryLowLimit)
            let tMin     = Double(settings.glucoseMin)
            let tMax     = Double(settings.glucoseMax)
            let veryHigh = Double(settings.veryHighLimit)

            let domainMax = max(maxMgdl, veryHigh + 20, 1)

            // ============================================================
            // MARK: - X positions
            // ============================================================

            let xVL  = width * fraction(of: veryLow,  domainMax: domainMax)
            let xMin = width * fraction(of: tMin,     domainMax: domainMax)
            let xMax = width * fraction(of: tMax,     domainMax: domainMax)
            let xVH  = width * fraction(of: veryHigh, domainMax: domainMax)

            let p0: CGFloat = 0
            let p1 = clamp(xVL,  min: 0, max: width)
            let p2 = clamp(xMin, min: 0, max: width)
            let p3 = clamp(xMax, min: 0, max: width)
            let p4 = clamp(xVH,  min: 0, max: width)
            let pE: CGFloat = width

            let wRedL  = max(0, min(p1, p2) - p0)
            let wYelL  = max(0, min(p2, p3) - min(p1, p2))
            let wGreen = max(0, min(p3, p4) - min(p2, p3))
            let wYelR  = max(0, p4 - min(p3, p4))
            let wRedR  = max(0, pE - p4)

            // Marker X (clamped)
            let markerXRaw = width * fraction(of: valueMgdl, domainMax: domainMax)
            let markerX = clamp(markerXRaw, min: clampInset, max: width - clampInset)

            // ============================================================
            // MARK: - Badge X Clamp ✅ (NEU, echte Breite)
            // ============================================================

            let badgeHalf = max(0, measuredBadgeW / 2)
            let badgeMinCenterX = max(clampInset, badgeHalf + 2)
            let badgeMaxCenterX = min(width - clampInset, width - badgeHalf - 2)
            let badgeCenterX = clamp(markerX, min: badgeMinCenterX, max: badgeMaxCenterX)

            // ============================================================
            // MARK: - Colors (Zone-driven)
            // ============================================================

            let zoneColor: Color = {
                if valueMgdl <= veryLow { return Color.Glu.acidCGMRed }
                if valueMgdl <  tMin    { return Color.yellow.opacity(0.80) }
                if valueMgdl <= tMax    { return Color.Glu.metabolicDomain }
                if valueMgdl <  veryHigh { return Color.yellow.opacity(0.80) }
                return Color.Glu.acidCGMRed
            }()

            // Labels (display-only via SettingsUnits)
            let digits = (settings.glucoseUnit == .mgdL) ? 0 : 1
            let labelVL  = settings.glucoseUnit.formattedNumber(fromMgdl: veryLow,  fractionDigits: digits)
            let labelMin = settings.glucoseUnit.formattedNumber(fromMgdl: tMin,     fractionDigits: digits)
            let labelMax = settings.glucoseUnit.formattedNumber(fromMgdl: tMax,     fractionDigits: digits)
            let labelVH  = settings.glucoseUnit.formattedNumber(fromMgdl: veryHigh, fractionDigits: digits)

            VStack(alignment: .leading, spacing: 0) {

                // 1) Marker lane (Badge + Triangle) — feste Höhe
                ZStack(alignment: .leading) {

                    // Badge (avg) – folgt markerX, aber bleibt IM Card-Width
                    HStack(alignment: .lastTextBaseline, spacing: 5) {

                        Text(avgText)
                            .font(.system(size: badgeTextValueSize, weight: .bold))

                        Text(unitText)
                            .font(.system(size: badgeTextUnitSize, weight: .semibold))
                    }
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(.horizontal, badgeHPad)
                    .padding(.vertical, badgeVPad)
                    .background(
                        Capsule()
                            .fill(Color.Glu.backgroundSurface.opacity(0.92))
                    )
                    .overlay(
                        Capsule()
                            .stroke(zoneColor.opacity(0.95), lineWidth: badgeCornerLineW)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .background(
                        GeometryReader { bGeo in
                            Color.clear
                                .preference(key: BadgeWidthKey.self, value: bGeo.size.width)
                        }
                    )
                    .onPreferenceChange(BadgeWidthKey.self) { w in
                        measuredBadgeW = w
                    }
                    .offset(
                        x: badgeCenterX - badgeHalf,
                        y: badgeOffsetY
                    )

                    // Triangle marker
                    TriangleMarker()
                        .fill(zoneColor)
                        .overlay(
                            TriangleMarker()
                                .stroke(Color.Glu.primaryBlue, lineWidth: 0.5)
                        )
                        .frame(width: markerW, height: markerH)
                        .offset(x: markerX - (markerW / 2), y: triangleOffsetY)
                }
                .frame(height: markerLaneH)

                // 2) Bar
                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.Glu.primaryBlue.opacity(0.06))
                        .frame(height: barH)

                    HStack(spacing: 0) {
                        Rectangle().fill(Color.Glu.acidCGMRed)        .frame(width: wRedL)
                        Rectangle().fill(Color.yellow.opacity(0.80))  .frame(width: wYelL)
                        Rectangle().fill(Color.Glu.metabolicDomain)   .frame(width: wGreen)
                        Rectangle().fill(Color.yellow.opacity(0.80))  .frame(width: wYelR)
                        Rectangle().fill(Color.Glu.acidCGMRed)        .frame(width: wRedR)
                    }
                    .frame(height: barH)
                    .clipShape(RoundedRectangle(cornerRadius: r))

                    RoundedRectangle(cornerRadius: r)
                        .stroke(Color.Glu.primaryBlue.opacity(0.75), lineWidth: 0.7)
                        .frame(height: barH)
                }
                .frame(height: barH)

                // 3) Labels under bar (4 thresholds)
                ZStack(alignment: .topLeading) {

                    Text(labelVL)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.acidCGMRed)
                        .frame(width: max(0, xVL - 2), alignment: .trailing)

                    Text(labelMin)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.green)
                        .frame(width: width, alignment: .leading)
                        .offset(x: clampLabelX(xMin, width: width) + 2, y: 0)

                    Text(labelMax)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.green)
                        .position(x: clampLabelX(xMax, width: width), y: labelsH / 2)

                    Text(labelVH)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.acidCGMRed)
                        .position(x: clampLabelX(xVH, width: width), y: labelsH / 2)
                }
                .frame(height: labelsH)
                .padding(.top, labelsGap)
            }
        }
        .frame(height: totalFixedHeight)
    }

    // MARK: - Helpers

    private func fraction(of mgdl: Double, domainMax: Double) -> CGFloat {
        CGFloat(min(max(mgdl / domainMax, 0), 1))
    }

    private func clamp(_ x: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(x, min), max)
    }

    private func clampLabelX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let inset: CGFloat = 12
        return clamp(x, min: inset, max: width - inset)
    }
}

// ============================================================
// MARK: - TIR Bar (Five-Zone-Style + Badge + Marker + Threshold Label)
// ============================================================

private struct TIRBar: View {

    @EnvironmentObject private var settings: SettingsModel

    let percent: Double          // 0...1 (CURRENT)
    let threshold: Double        // 0...1 (TARGET)

    // Bar
    private let barH: CGFloat = 10
    private let r: CGFloat = 6

    // Marker
    private let markerW: CGFloat = 20
    private let markerH: CGFloat = 20
    private let markerGap: CGFloat = 2

    // Badge
    private let badgeHPad: CGFloat = 10
    private let badgeVPad: CGFloat = 5
    private let badgeTextValueSize: CGFloat = 20
    private let badgeTextUnitSize: CGFloat = 13
    private let badgeCornerLineW: CGFloat = 1.6
    private let badgeOffsetY: CGFloat = -20
    private let triangleOffsetY: CGFloat = 17

    // Label
    private let labelsGap: CGFloat = 4
    private let labelsH: CGFloat = 12
    private let clampInset: CGFloat = 12

    // Stroke style
    private let strokeColor: Color = Color.Glu.primaryBlue.opacity(0.75)
    private let strokeWidth: CGFloat = 0.7
    private let backgroundFill: Color = Color.Glu.primaryBlue.opacity(0.06)

    // Target Marker
    private let markerLineColor: Color = Color.Glu.acidCGMRed
    private let markerLineWidth: CGFloat = 3
    private let markerOverhang: CGFloat = 6

    private let badgeApproxW: CGFloat = 60

    private var markerLaneH: CGFloat {
        (badgeVPad * 2) + CGFloat(badgeTextValueSize) + 6 + markerH + markerGap
    }

    private var totalFixedHeight: CGFloat {
        markerLaneH + barH + labelsGap + labelsH
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            let p = clamp(percent, min: 0, max: 1)
            let t = clamp(threshold, min: 0, max: 1)

            let fillW = width * CGFloat(p)

            let currentXRaw = width * CGFloat(p)
            let currentX = clamp(CGFloat(currentXRaw), min: clampInset, max: width - clampInset)

            let targetXRaw = width * CGFloat(t)
            let targetX = clamp(CGFloat(targetXRaw), min: clampInset, max: width - clampInset)

            let warn = max(0, t - 0.10)

            let zoneColor: Color = {
                if p < warn { return Color.Glu.acidCGMRed }
                if p < t    { return Color.yellow.opacity(0.80) }
                return Color.Glu.metabolicDomain
            }()

            let percentInt = Int((p * 100.0).rounded())
            let targetInt  = Int((t * 100.0).rounded())

            let badgeXRaw = currentX - (badgeApproxW / 2)
            let badgeX = clamp(badgeXRaw, min: clampInset, max: width - clampInset - badgeApproxW)

            VStack(alignment: .leading, spacing: 0) {

                ZStack(alignment: .leading) {

                    HStack(alignment: .lastTextBaseline, spacing: 5) {

                        Text("\(percentInt)")
                            .font(.system(size: badgeTextValueSize, weight: .bold))

                        Text("%")
                            .font(.system(size: badgeTextUnitSize, weight: .semibold))
                    }
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(.horizontal, badgeHPad)
                    .padding(.vertical, badgeVPad)
                    .background(
                        Capsule()
                            .fill(Color.Glu.backgroundSurface.opacity(0.92))
                    )
                    .overlay(
                        Capsule()
                            .stroke(zoneColor.opacity(0.95), lineWidth: badgeCornerLineW)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .offset(x: badgeX, y: badgeOffsetY)

                    TriangleMarker()
                        .fill(zoneColor)
                        .overlay(
                            TriangleMarker()
                                .stroke(Color.Glu.primaryBlue, lineWidth: 0.5)
                        )
                        .frame(width: markerW, height: markerH)
                        .offset(x: currentX - (markerW / 2), y: triangleOffsetY)
                }
                .frame(height: markerLaneH)

                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: r)
                        .fill(backgroundFill)
                        .frame(height: barH)

                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: r,
                            bottomLeading: r,
                            bottomTrailing: 0,
                            topTrailing: 0
                        )
                    )
                    .fill(zoneColor)
                    .frame(width: fillW, height: barH)

                    RoundedRectangle(cornerRadius: r)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                        .frame(height: barH)

                    Rectangle()
                        .fill(markerLineColor)
                        .frame(width: markerLineWidth, height: barH + markerOverhang)
                        .offset(x: targetX - (markerLineWidth / 2),
                                y: -(markerOverhang / 2))
                        .zIndex(999)
                }
                .frame(height: barH)

                ZStack(alignment: .topLeading) {
                    Text("\(targetInt)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.green)
                        .position(x: targetX, y: labelsH / 2)
                }
                .frame(height: labelsH)
                .padding(.top, labelsGap)
            }
        }
        .frame(height: totalFixedHeight)
    }

    private func clamp<T: Comparable>(_ x: T, min: T, max: T) -> T {
        Swift.min(Swift.max(x, min), max)
    }
}

// ============================================================
// MARK: - Triangle Marker Shape
// ============================================================

private struct TriangleMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// ============================================================
// MARK: - GMI Helper (mg/dL → %)
// ============================================================

private extension GlucoseSummaryCardV1 {
    func computeGmiPercent(fromMeanMgdl mean: Double) -> Double {
        return 3.31 + 0.02392 * mean
    }
}

// ============================================================
// MARK: - Preview (minimal)
// ============================================================

#Preview("Glucose Summary Card V1") {
    let store = HealthStore.preview()
    store.last24hGlucoseMeanMgdl = 136
    store.last24hGlucoseSdMgdl = 42
    store.last24hGlucoseCvPercent = 31
    store.last24hTIRInRangeMinutes = 900
    store.last24hTIRCoverageMinutes = 1200
    store.glucoseMean90dMgdl = 145

    let state = AppState()                                                // !!! NEW

    return GlucoseSummaryCardV1()
        .environmentObject(store)
        .environmentObject(SettingsModel.shared)
        .environmentObject(state)                                         // !!! NEW
        .padding(16)
}
