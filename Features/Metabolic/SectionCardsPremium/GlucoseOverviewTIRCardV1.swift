//
//  GlucoseOverviewTIRCardV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Overview Card (TIR)
//  - Top: TIR (24h) bar (IDENTICAL UI)
//  - Bottom: 7-day mini trend chart (Steps mini-chart style)
//  - Tappable: navigates to Time in Range
//  - SSoT: HealthStore + SettingsModel
//

import SwiftUI
import Charts
import TipKit

struct GlucoseOverviewTIRCardV1: View {

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState

    private let cardPadding: CGFloat = 16
    private let gapTirValueToBar: CGFloat = 3
    private let gapToMiniChart: CGFloat = 12

    private var tirThreshold: Double {
        Double(settings.tirTargetPercent) / 100.0
    }

    private var avgTirPercentInt: Int {
        let coverage = max(0, healthStore.last24hTIRCoverageMinutes)
        guard coverage > 0 else { return 0 }
        let inRange = max(0, healthStore.last24hTIRInRangeMinutes)
        let ratio = Double(inRange) / Double(coverage)
        return Int((ratio * 100.0).rounded())
    }

    private var last7DaysTirEntries: [TIRMiniTrendEntry] {
        buildLast7DaysTirEntries()
    }

    var body: some View {
        Button {
            appState.currentStatsScreen = .timeInRange
        } label: {
            VStack(alignment: .leading, spacing: 0) {

                header
                Gap(gapTirValueToBar)

                TIRBar(
                    percent: Double(avgTirPercentInt) / 100.0,
                    threshold: tirThreshold
                )

                Gap(gapToMiniChart)

                TIRMiniTrendChart(
                    data: last7DaysTirEntries,
                    domainColor: Color.Glu.metabolicDomain
                )
                .frame(height: 60)
            }
            .padding(cardPadding)
            .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Time in Range")
    }
}

// MARK: - Header

private extension GlucoseOverviewTIRCardV1 {

    var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {

            Text("TIR")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.Glu.primaryBlue)

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
                    appState.requestedTab = .home
                }
            )
            Spacer()
        }
    }
}

// MARK: - Tip (local to this Card; no global coupling)

private struct Last24HoursCGMTip: Tip {

    var title: Text {
        Text("Last 24 Hours (24h)")
    }

    var message: Text? {
        Text("For accuracy, CGM metrics labeled (24h) are based on the latest fully available readings from Apple Health. Newer readings may appear with a short delay.")
    }

    var image: Image? {
        Image(systemName: "info.circle")
    }
}

// MARK: - 7-day builder (yesterday + 6 before)

private extension GlucoseOverviewTIRCardV1 {

    private func buildLast7DaysTirEntries() -> [TIRMiniTrendEntry] {

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        guard
            let endDate = cal.date(byAdding: .day, value: -1, to: todayStart),
            let startDate = cal.date(byAdding: .day, value: -6, to: endDate)
        else { return [] }

        // !!! UPDATED: Use Overview-lightweight 7-day series (NOT dailyTIR90) to avoid missing data in Overview
        let source = healthStore.overviewTIRDaily7FullDays.isEmpty
            ? healthStore.dailyTIR90
            : healthStore.overviewTIRDaily7FullDays

        let stats = source
            .map { e in
                DailyTIREntry(
                    id: e.id,
                    date: cal.startOfDay(for: e.date),
                    veryLowMinutes: e.veryLowMinutes,
                    lowMinutes: e.lowMinutes,
                    inRangeMinutes: e.inRangeMinutes,
                    highMinutes: e.highMinutes,
                    veryHighMinutes: e.veryHighMinutes,
                    coverageMinutes: e.coverageMinutes,
                    expectedMinutes: e.expectedMinutes,
                    coverageRatio: e.coverageRatio,
                    isPartial: e.isPartial
                )
            }
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }

        var map: [Date: Double] = [:]
        for e in stats {
            let day = cal.startOfDay(for: e.date)
            guard e.coverageMinutes > 0 else {
                map[day] = 0
                continue
            }
            let fraction = Double(e.inRangeMinutes) / Double(e.coverageMinutes)
            map[day] = max(0, min(fraction, 1))
        }

        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: startDate) else { return nil }
            let day = cal.startOfDay(for: d)

            return TIRMiniTrendEntry(
                date: day,
                fraction: map[day] ?? 0
            )
        }
    }
}

// MARK: - Mini Trend Types

private struct TIRMiniTrendEntry: Identifiable {
    let id = UUID()
    let date: Date
    let fraction: Double   // 0...1
}

// MARK: - Mini Trend Chart (Steps style)

private struct TIRMiniTrendChart: View {

    let data: [TIRMiniTrendEntry]
    let domainColor: Color

    var body: some View {

        Chart(data) { entry in

            let percentInt = Int((entry.fraction * 100.0).rounded())

            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("TIR", percentInt)
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
                if percentInt > 0 {
                    Text("\(percentInt)")
                        .font(.system(size: 13, weight: .bold))
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

// MARK: - TIR Bar (IDENTICAL to current design)

private struct TIRBar: View {

    @EnvironmentObject private var settings: SettingsModel

    let percent: Double
    let threshold: Double

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

    private let strokeColor: Color = Color.Glu.primaryBlue.opacity(0.75)
    private let strokeWidth: CGFloat = 0.7
    private let backgroundFill: Color = Color.Glu.primaryBlue.opacity(0.06)

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

#Preview("GlucoseOverviewTIRCardV1") {
    let store = HealthStore.preview()
    store.last24hTIRInRangeMinutes = 900
    store.last24hTIRCoverageMinutes = 1200

    // Optional: if you want to see bars in preview, fill overview series:
    // store.overviewTIRDaily7FullDays = [...]

    let state = AppState()

    return GlucoseOverviewTIRCardV1()
        .environmentObject(store)
        .environmentObject(SettingsModel.shared)
        .environmentObject(state)
        .padding(16)
}
