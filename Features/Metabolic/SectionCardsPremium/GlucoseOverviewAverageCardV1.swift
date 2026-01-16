//
//  GlucoseOverviewAverageCardV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Overview Card (Avg Glucose)
//  - Top: Ø Glucose (24h) (IDENTICAL Five-Zone Bar UI)
//  - Bottom: 7-day mini trend chart (Steps mini-chart style)
//  - SSoT: HealthStore + SettingsModel
//
//  NOTE (24h):
//  - CGM “Last 24 Hours (24h)” metrics are based on the latest fully available CGM readings from Apple Health.
//    Newer readings may appear with a short delay.
//

import SwiftUI
import Charts
import TipKit

struct GlucoseOverviewAverageCardV1: View {
    
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState
    
    private let cardPadding: CGFloat = 16
    private let gapHeaderToGlucose: CGFloat = 10
    private let gapGlucoseValueToBar: CGFloat = 3
    private let gapToMiniChart: CGFloat = 12
    
    // Chart Scale (Settings-driven)
    private var chartMaxGlucoseMgdl: Double {
        let padded = Double(settings.veryHighLimit) + 20
        return max(300, padded)
    }
    
    // Glucose Unit (display-only)
    private var avgGlucoseDisplayText: String {
        let mgdl = healthStore.last24hGlucoseMeanMgdl ?? 0
        let digits = (settings.glucoseUnit == .mgdL) ? 0 : 1
        return settings.glucoseUnit.formattedNumber(fromMgdl: mgdl, fractionDigits: digits)
    }
    
    private var avgGlucoseUnitText: String { settings.glucoseUnit.label }
    
    // 7-day data (Overview-series; UI-only mapping)
    private var last7DaysMeanEntries: [GlucoseMiniTrendEntry] {
        buildLast7DaysMeanEntries()
    }
    
    var body: some View {
        
        Button {
            // Navigate to IG metric
            appState.currentStatsScreen = .ig          // !!! NEW
            appState.requestedTab = .home              // !!! NEW (sicherstellen, dass du im Home/Metabolic Kontext bist)
        } label: {
            
            VStack(alignment: .leading, spacing: 0) {
                
                header
                Gap(gapHeaderToGlucose)
                
                VStack(alignment: .leading, spacing: 0) {
                    Gap(gapGlucoseValueToBar)
                    
                    GlucoseFiveZoneBar(
                        valueMgdl: healthStore.last24hGlucoseMeanMgdl ?? 0,
                        maxMgdl: chartMaxGlucoseMgdl,
                        avgText: avgGlucoseDisplayText,
                        unitText: avgGlucoseUnitText
                    )
                }
                
                Gap(gapToMiniChart)
                
                GlucoseMiniTrendChart(
                    data: last7DaysMeanEntries,
                    domainColor: Color.Glu.metabolicDomain
                )
                .frame(height: 60)
            }
            .padding(cardPadding)
            .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
        }
        .buttonStyle(.plain) // !!! NEW (keine Button-Optik)
    }
}
// MARK: - Header

private extension GlucoseOverviewAverageCardV1 {

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

            TipInlineButton(
                tip: Last24HoursCGMTip(),
                learnMoreTitle: "Learn more in Settings",
                frameColor: Color.Glu.primaryBlue,
                onLearnMore: {
                    appState.currentStatsScreen = .none
                    appState.settingsStartDomain = .metabolic
                    appState.currentStatsScreen = .none
                    
                }
            )

            Spacer()

            let coverage = max(0, healthStore.last24hTIRCoverageMinutes)
            let samples = Int((Double(coverage) / 5.0).rounded())
            let maxSamples = 288

            Text("CGM \(samples) / \(maxSamples)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.65))
        }
    }
}

// MARK: - Tip (local to this Card; no global coupling)

private struct Last24HoursCGMTip: Tip {

    var title: Text { Text("Last 24 Hours (24h)") }

    var message: Text? {
        Text("For accuracy, CGM metrics labeled (24h) are based on the latest fully available CGM readings from Apple Health. Newer readings may appear with a short delay.")
    }

    var image: Image? { Image(systemName: "info.circle") }
}

// MARK: - 7-day builder (yesterday + 6 before)

private extension GlucoseOverviewAverageCardV1 {

    private func buildLast7DaysMeanEntries() -> [GlucoseMiniTrendEntry] {

        let cal = Calendar.current

        // !!! UPDATED: Overview must use the dedicated 7-full-days series (yesterday…-6), NOT dailyGlucoseStats90
        let src = healthStore.overviewGlucoseDaily7FullDays

        return src
            .map { e in
                GlucoseMiniTrendEntry(
                    date: cal.startOfDay(for: e.date),
                    value: max(0, e.meanMgdl)
                )
            }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Mini Trend Types

private struct GlucoseMiniTrendEntry: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Mini Trend Chart (Steps style)

private struct GlucoseMiniTrendChart: View {

    @EnvironmentObject private var settings: SettingsModel

    let data: [GlucoseMiniTrendEntry]
    let domainColor: Color

    private var digits: Int {
        (settings.glucoseUnit == .mgdL) ? 0 : 1
    }

    var body: some View {
        Chart(data) { entry in

            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Value", entry.value)
            )
            .cornerRadius(4)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        domainColor.opacity(0.25),
                        domainColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .annotation(position: .top, alignment: .center) {
                if entry.value > 0 {
                    Text(
                        settings.glucoseUnit.formattedNumber(
                            fromMgdl: entry.value,
                            fractionDigits: digits
                        )
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(.bottom, 2)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(range: .plotDimension(padding: 0))
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }
}

// MARK: - Adjustable Gap Helper

private struct Gap: View {
    let height: CGFloat
    init(_ height: CGFloat) { self.height = height }
    var body: some View { Color.clear.frame(height: height) }
}

// MARK: - Glucose Five-Zone Bar (IDENTICAL to current design)

private struct GlucoseFiveZoneBar: View {

    @EnvironmentObject private var settings: SettingsModel

    let valueMgdl: Double
    let maxMgdl: Double

    let avgText: String
    let unitText: String

    private let barH: CGFloat = 10
    private let r: CGFloat = 6

    private let markerW: CGFloat = 20
    private let markerH: CGFloat = 20
    private let markerGap: CGFloat = 2

    private let badgeHPad: CGFloat = 10
    private let badgeVPad: CGFloat = 5
    private let badgeTextValueSize: CGFloat = 20
    private let badgeTextUnitSize: CGFloat = 13
    private let badgeCornerLineW: CGFloat = 1.6

    private let badgeOffsetY: CGFloat = -20
    private let triangleOffsetY: CGFloat = 17

    private let labelsGap: CGFloat = 4
    private let labelsH: CGFloat = 12

    private let clampInset: CGFloat = 12

    @State private var measuredBadgeW: CGFloat = 0

    private struct BadgeWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private var markerLaneH: CGFloat {
        (badgeVPad * 2) + CGFloat(badgeTextValueSize) + 6 + markerH + markerGap
    }

    private var totalFixedHeight: CGFloat {
        markerLaneH + barH + labelsGap + labelsH
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            let veryLow  = Double(settings.veryLowLimit)
            let tMin     = Double(settings.glucoseMin)
            let tMax     = Double(settings.glucoseMax)
            let veryHigh = Double(settings.veryHighLimit)

            let domainMax = max(maxMgdl, veryHigh + 20, 1)

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

            let markerXRaw = width * fraction(of: valueMgdl, domainMax: domainMax)
            let markerX = clamp(markerXRaw, min: clampInset, max: width - clampInset)

            let badgeHalf = max(0, measuredBadgeW / 2)
            let badgeMinCenterX = max(clampInset, badgeHalf + 2)
            let badgeMaxCenterX = min(width - clampInset, width - badgeHalf - 2)
            let badgeCenterX = clamp(markerX, min: badgeMinCenterX, max: badgeMaxCenterX)

            let zoneColor: Color = {
                if valueMgdl <= veryLow { return Color.Glu.acidCGMRed }
                if valueMgdl <  tMin    { return Color.yellow.opacity(0.80) }
                if valueMgdl <= tMax    { return Color.Glu.metabolicDomain }
                if valueMgdl <  veryHigh { return Color.yellow.opacity(0.80) }
                return Color.Glu.acidCGMRed
            }()

            let digits = (settings.glucoseUnit == .mgdL) ? 0 : 1
            let labelVL  = settings.glucoseUnit.formattedNumber(fromMgdl: veryLow,  fractionDigits: digits)
            let labelMin = settings.glucoseUnit.formattedNumber(fromMgdl: tMin,     fractionDigits: digits)
            let labelMax = settings.glucoseUnit.formattedNumber(fromMgdl: tMax,     fractionDigits: digits)
            let labelVH  = settings.glucoseUnit.formattedNumber(fromMgdl: veryHigh, fractionDigits: digits)

            VStack(alignment: .leading, spacing: 0) {

                ZStack(alignment: .leading) {

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

                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.Glu.primaryBlue.opacity(0.06))
                        .frame(height: barH)

                    HStack(spacing: 0) {
                        Rectangle().fill(Color.Glu.acidCGMRed)         .frame(width: wRedL)
                        Rectangle().fill(Color.yellow.opacity(0.80))   .frame(width: wYelL)
                        Rectangle().fill(Color.Glu.metabolicDomain)    .frame(width: wGreen)
                        Rectangle().fill(Color.yellow.opacity(0.80))   .frame(width: wYelR)
                        Rectangle().fill(Color.Glu.acidCGMRed)         .frame(width: wRedR)
                    }
                    .frame(height: barH)
                    .clipShape(RoundedRectangle(cornerRadius: r))

                    RoundedRectangle(cornerRadius: r)
                        .stroke(Color.Glu.primaryBlue.opacity(0.75), lineWidth: 0.7)
                        .frame(height: barH)
                }
                .frame(height: barH)

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
// MARK: - Preview

#Preview("GlucoseOverviewAverageCardV1") {

    // ✅ FIX: keine Statements im Preview-Builder,
    // sondern eine Expression, die einen konfigurierten Store zurückgibt.
    let store: HealthStore = {
        let s = HealthStore.preview()
        s.last24hGlucoseMeanMgdl = 136
        s.last24hTIRCoverageMinutes = 1440
        return s
    }()

    let state = AppState()

    return GlucoseOverviewAverageCardV1()
        .environmentObject(store)
        .environmentObject(SettingsModel.shared)
        .environmentObject(state)
        .padding(16)
}
