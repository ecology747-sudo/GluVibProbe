//
//  ReportLast9DaysMainChartAppendixV1.swift
//  GluVibProbe
//
//  Report V1 — Appendix: Last 9 Full Days (Mini MainCharts)
//  - Uses MainChartCacheV1 day profiles (-1 ... -9)
//  - Read-only, no interactions, no chips
//  - Overlays always ON (if arrays empty -> nothing drawn)
//

import SwiftUI
import Charts

struct ReportLast9DaysMainChartAppendixPageV1: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    /// Exactly 3 offsets per page (e.g. [-1,-2,-3])
    let dayOffsets: [Int]

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - Layout (fixed)
    // ============================================================

    private let chartHeight: CGFloat = 160
    private let panelCorner: CGFloat = 14
    private let fixedYDomain: ClosedRange<Double> = 0 ... 300

    private var isTherapyEnabled: Bool {
        settings.hasCGM && settings.isInsulinTreated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text("Last 9 full days — MainChart snapshots")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(dayOffsets, id: \.self) { offset in
                    dayPanel(offset: offset)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    // ============================================================
    // MARK: - Day Panel
    // ============================================================

    @ViewBuilder
    private func dayPanel(offset: Int) -> some View {

        let dayStart = healthStore.mainChartDayStartV1(dayOffset: offset)
        let profile = healthStore.cachedMainChartProfileV1(dayOffset: offset)

        VStack(alignment: .leading, spacing: 8) {

            Text(dayTitle(dayStart, offset: offset))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.90))

            Group {
                if let p = profile {
                    miniMainChart(profile: p)
                        .frame(height: chartHeight)
                } else {
                    VStack(spacing: 6) {
                        Text("No cached profile")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
                        Text("Cache will populate via ensureMainChartCachedV1().")
                            .font(.caption)
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.60))
                    }
                    .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: panelCorner))
        .overlay(
            RoundedRectangle(cornerRadius: panelCorner)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }

    private func dayTitle(_ dayStart: Date, offset: Int) -> String {
        if offset == -1 { return "Yesterday" }

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: dayStart)
    }

    // ============================================================
    // MARK: - Mini MainChart (always-on overlays)
    // ============================================================

    private struct TimeWindow {
        let start: Date
        let end: Date
    }

    private func xDomainWindow(for profile: MainChartDayProfileV1) -> TimeWindow {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: profile.day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        // Appendix uses full days only; profiles should be full-day profiles.
        return TimeWindow(start: dayStart, end: dayEnd)
    }

    @ViewBuilder
    private func miniMainChart(profile: MainChartDayProfileV1) -> some View {

        let window = xDomainWindow(for: profile)

        let baseY: Double = 0
        let activityBarHeight: Double = 8

        let insulinMaxUnits = maxVisibleInsulinUnits(profile: profile, window: window)

        let targetMin = max(fixedYDomain.lowerBound, min(Double(settings.glucoseMin), fixedYDomain.upperBound))
        let targetMax = max(fixedYDomain.lowerBound, min(Double(settings.glucoseMax), fixedYDomain.upperBound))
        let bandLower = min(targetMin, targetMax)
        let bandUpper = max(targetMin, targetMax)

        let yDomain: ClosedRange<Double> = 0 ... 300

        Chart {

            targetRangeBand(window: window, bandLower: bandLower, bandUpper: bandUpper)

            // Always ON overlays (if arrays empty -> nothing drawn)
            cgmLineMarks(profile: profile, window: window)

            activityBars(profile: profile, window: window, baseY: baseY, height: activityBarHeight)

            nutritionStems(profile: profile, window: window, kind: .carbs, baseY: baseY)
            nutritionStems(profile: profile, window: window, kind: .protein, baseY: baseY)

            if isTherapyEnabled {
                bolusStems(profile: profile, window: window, baseY: baseY, insulinMaxUnits: insulinMaxUnits)
                basalStems(profile: profile, window: window, baseY: baseY, insulinMaxUnits: insulinMaxUnits)
            }
        }
        .chartXScale(domain: window.start ... window.end)
        .chartYScale(domain: yDomain)

        // Mini-axis styling: very light, minimal labels
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.14))
                AxisTick().foregroundStyle(Color.gray.opacity(0.22))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.70))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValuesMini()) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.14))
                AxisTick().foregroundStyle(Color.gray.opacity(0.22))
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(yAxisLabelText(forTickPositionMgdl: v))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.70))
                    }
                }
            }
        }
    }

    private func yAxisValuesMini() -> [Double] {
        // A compact set that still works for mmol/mg/dL conversion
        let upperMgdl: Double = 300

        switch settings.glucoseUnit {
        case .mgdL:
            return [0, 100, 200, 300]
        case .mmolL:
            // keep ticks in mg/dL space, but label in mmol
            // 0 / 100 / 200 / 300 mg/dL ~= 0 / 5.6 / 11.1 / 16.7 mmol/L
            return [0, 100, 200, 300]
        }
    }

    private func yAxisLabelText(forTickPositionMgdl tickMgdl: Double) -> String {
        switch settings.glucoseUnit {
        case .mgdL:
            return "\(Int(tickMgdl.rounded()))"
        case .mmolL:
            let mmol = settings.glucoseUnit.convertedValue(fromMgdl: tickMgdl)
            return String(format: "%.0f", mmol.rounded())
        }
    }

    // ============================================================
    // MARK: - Chart Content Builders (copied from MainChartViewV1)
    // ============================================================

    @ChartContentBuilder
    private func targetRangeBand(window: TimeWindow, bandLower: Double, bandUpper: Double) -> some ChartContent {
        RectangleMark(
            xStart: .value("Band Start", window.start),
            xEnd:   .value("Band End", window.end),
            yStart: .value("Target Min", bandLower),
            yEnd:   .value("Target Max", bandUpper)
        )
        .foregroundStyle(Color.Glu.successGreen)
        .opacity(1.0)
    }

    @ChartContentBuilder
    private func cgmLineMarks(profile: MainChartDayProfileV1, window: TimeWindow) -> some ChartContent {
        let stroke = StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
        let cgm = Color.Glu.acidCGMRed

        ForEach(filteredCGMPoints(profile: profile, window: window)) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Glucose", point.glucoseMgdl)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(stroke)
            .foregroundStyle(cgm)
            .shadow(color: cgm.opacity(0.16), radius: 1.2, x: 0, y: 1)
        }
    }

    @ChartContentBuilder
    private func activityBars(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        baseY: Double,
        height: Double
    ) -> some ChartContent {
        let fill = Color.Glu.activityDomain.opacity(0.55)

        ForEach(filteredActivityEvents(profile: profile, window: window)) { act in
            RectangleMark(
                xStart: .value("Activity Start", act.start),
                xEnd:   .value("Activity End", act.end),
                yStart: .value("Activity Base", baseY),
                yEnd:   .value("Activity Top", baseY + height)
            )
            .foregroundStyle(fill)
            .shadow(color: Color.black.opacity(0.14), radius: 1.6, x: 0, y: 1.2)
        }
    }

    @ChartContentBuilder
    private func nutritionStems(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        kind: NutritionEventKind,
        baseY: Double
    ) -> some ChartContent {

        let isCarbs = (kind == .carbs)

        let carbsColor: Color = Color.Glu.nutritionDomain.opacity(0.85)
        let proteinColor: Color = Color.Glu.bodyDomain.opacity(0.95)

        let lineWidth: CGFloat = isCarbs ? 6.0 : 3.0

        let markColor: Color = isCarbs ? carbsColor : proteinColor
        let textColor: Color = isCarbs ? carbsColor : Color.Glu.bodyDomain

        ForEach(filteredNutrition(profile: profile, window: window, kind: kind)) { e in
            let topY = nutritionBarTopYMgdl(grams: e.grams)

            RuleMark(
                x: .value(isCarbs ? "Carbs Time" : "Protein Time", e.timestamp),
                yStart: .value("Nutrition Base", baseY),
                yEnd:   .value("Nutrition Top", topY)
            )
            .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .miter))
            .foregroundStyle(markColor)
            .shadow(color: Color.black.opacity(0.12), radius: 1.2, x: 0, y: 1.0)
            .annotation(position: .top, alignment: .center) {
                if e.grams >= 5 {
                    Text("\(Int(e.grams.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(textColor)
                }
            }
        }
    }

    @ChartContentBuilder
    private func bolusStems(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        baseY: Double,
        insulinMaxUnits: Double
    ) -> some ChartContent {

        let bolusGreen = Color("acidBolusDarkGreen")

        ForEach(filteredBolusEvents(profile: profile, window: window)) { event in
            let topY = insulinBarTopYMgdl(units: event.units, maxUnits: insulinMaxUnits)

            RuleMark(
                x: .value("Bolus Time", event.timestamp),
                yStart: .value("Bolus Base", baseY),
                yEnd:   .value("Bolus Top", topY)
            )
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .miter))
            .foregroundStyle(bolusGreen.opacity(0.92))
            .shadow(color: Color.black.opacity(0.14), radius: 1.4, x: 0, y: 1.1)
            .annotation(position: .top, alignment: .center) {
                if event.units > 0 {
                    Text("\(Int(event.units.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(bolusGreen.opacity(0.95))
                }
            }
        }
    }

    @ChartContentBuilder
    private func basalStems(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        baseY: Double,
        insulinMaxUnits: Double
    ) -> some ChartContent {

        let basalColor: Color = Color("GluBasalMagenta").opacity(0.7)

        ForEach(filteredBasalEvents(profile: profile, window: window)) { event in
            let topY = insulinBarTopYMgdl(units: event.units, maxUnits: insulinMaxUnits)

            RuleMark(
                x: .value("Basal Time", event.timestamp),
                yStart: .value("Basal Base", baseY),
                yEnd:   .value("Basal Top", topY)
            )
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt, lineJoin: .miter))
            .foregroundStyle(basalColor)
            .shadow(color: Color.black.opacity(0.16), radius: 1.6, x: 0, y: 1.2)
            .annotation(position: .top, alignment: .center) {
                if event.units > 0 {
                    Text("\(Int(event.units.rounded()))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(basalColor)
                }
            }
        }
    }

    // ============================================================
    // MARK: - Filters & Mapping (copied from MainChartViewV1)
    // ============================================================

    private func filteredCGMPoints(profile: MainChartDayProfileV1, window: TimeWindow) -> [CGMSamplePoint] {
        profile.cgm
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func filteredBolusEvents(profile: MainChartDayProfileV1, window: TimeWindow) -> [InsulinBolusEvent] {
        profile.bolus
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func filteredBasalEvents(profile: MainChartDayProfileV1, window: TimeWindow) -> [InsulinBasalEvent] {
        profile.basal
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func filteredActivityEvents(profile: MainChartDayProfileV1, window: TimeWindow) -> [ActivityOverlayEvent] {
        profile.activity
            .filter { $0.end > window.start && $0.start < window.end }
            .sorted { $0.start < $1.start }
    }

    private func filteredNutrition(
        profile: MainChartDayProfileV1,
        window: TimeWindow,
        kind: NutritionEventKind
    ) -> [NutritionEvent] {
        let list: [NutritionEvent] = (kind == .carbs) ? profile.carbs : profile.protein
        return list
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func nutritionBarTopYMgdl(grams: Double) -> Double {
        let g = max(0, grams)

        let anchorGrams: Double = 34
        let anchorMgdl: Double = 100

        let y = (g / max(1, anchorGrams)) * anchorMgdl
        return min(fixedYDomain.upperBound, max(0, y))
    }

    private func maxVisibleInsulinUnits(profile: MainChartDayProfileV1, window: TimeWindow) -> Double {
        let bolus = profile.bolus
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .map { max(0, $0.units) }

        let basal = profile.basal
            .filter { $0.timestamp >= window.start && $0.timestamp <= window.end }
            .map { max(0, $0.units) }

        return max(0.0, (bolus + basal).max() ?? 0.0)
    }

    private func insulinBarTopYMgdl(units: Double, maxUnits: Double) -> Double {
        let u = max(0, units)
        let targetPeakMgdl: Double = 150
        guard maxUnits > 0 else { return 0 }

        let y = (u / maxUnits) * targetPeakMgdl
        return min(fixedYDomain.upperBound, max(0, y))
    }
}

// MARK: - Preview

#Preview {
    ReportLast9DaysMainChartAppendixPageV1(dayOffsets: [-1, -2, -3])
        .environmentObject(HealthStore.preview())
        .environmentObject(SettingsModel.shared)
}
