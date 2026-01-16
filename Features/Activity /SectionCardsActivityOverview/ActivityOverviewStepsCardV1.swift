//
//  ActivityOverviewStepsCardV1.swift
//  GluVibProbe
//
//  Activity Overview — Steps Card (Extracted)
//
//  Zweck:
//  - Ausgelagerte Card für ActivityOverviewViewV1
//  - Read-only: bekommt alle Daten via Parameter
//

import SwiftUI
import Charts

struct ActivityOverviewStepsCardV1: View {

    let todaySteps: Int
    let stepsGoal: Int
    let stepsAverage7d: Int

    let distanceTodayKm: Double
    let distanceAverage7dKm: Double
    let last7DaysSteps: [DailyStepsEntry]

    let distanceUnit: DistanceUnit
    let onTap: () -> Void

    private var hasReachedGoal: Bool {
        stepsGoal > 0 && todaySteps >= stepsGoal
    }

    private var stepsAccentColor: Color {
        hasReachedGoal ? .green : Color.Glu.activityDomain
    }

    var body: some View {
        VStack(spacing: 12) {

            // ✅ Card 1: Steps + Progress + 7d Mini Trend
            VStack(alignment: .leading, spacing: 8) {
                headerRow
                stepsBlock

                let chartData = last7DaysSteps.isEmpty ? placeholderLastSevenDays() : last7DaysSteps
                ActivityOverviewStepsMiniTrendChartV1(data: chartData)
                    .frame(height: 60)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            // ✅ Card 2: Distance + Progress (separate card) — NOT tappable
            VStack(alignment: .leading, spacing: 8) {
                distanceBlock
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        }
        .frame(maxWidth: .infinity)
    }

    private var headerRow: some View {
        HStack {
            Label {
                Text("Steps")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
            } icon: {
                Image(systemName: "figure.walk")
                    .foregroundColor(stepsAccentColor)
            }

            Spacer()

            Image(systemName: trendArrowSymbol())
                .font(.title2.weight(.bold))
                .foregroundColor(trendArrowColor())
                .padding(.trailing, 2)
        }
    }

    private var stepsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(alignment: .firstTextBaseline) {

                Text(formattedSteps(todaySteps))
                    .font(.largeTitle.bold())
                    .foregroundColor(hasReachedGoal ? .green : Color.Glu.primaryBlue)

                Spacer()

                HStack(spacing: 4) {
                    Text("Remaining")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(formattedSteps(max(stepsGoal - todaySteps, 0)))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                }
            }

            GeometryReader { geo in
                let width = geo.size.width
                let goal = max(Double(stepsGoal), 1.0)
                let clampedSteps = max(0.0, min(Double(todaySteps), goal))
                let fraction = clampedSteps / goal

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.Glu.primaryBlue.opacity(0.06))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(stepsAccentColor)
                        .frame(width: width * fraction)

                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.7)
                }
            }
            .frame(height: 10)

            HStack(spacing: 4) {
                Spacer()
                Text("Target")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(formattedSteps(stepsGoal))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
            }
        }
    }

    private var distanceBlock: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(spacing: 6) {
                Image(systemName: distanceUnit == .miles ? "road.lanes" : "ruler")
                    .foregroundColor(Color.Glu.activityDomain)

                Text("Distance")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
            }

            HStack(alignment: .firstTextBaseline) {

                Text(formattedDistance(distanceTodayKm))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                HStack(spacing: 6) {
                    Text("7-day avg")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(formattedDistance(distanceAverage7dKm))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                }
            }

            GeometryReader { geo in
                let width = geo.size.width
                let avg = max(distanceAverage7dKm, 0.1)
                let fraction = min(max(distanceTodayKm / avg, 0), 1)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.Glu.primaryBlue.opacity(0.06))

                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.Glu.activityDomain)
                        .frame(width: width * fraction)

                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.8)
                }
            }
            .frame(height: 8)
        }
    }

    private func placeholderLastSevenDays() -> [DailyStepsEntry] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: Date())

        var result: [DailyStepsEntry] = []
        result.reserveCapacity(7)

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else { continue }
            let day = calendar.startOfDay(for: date)
            result.append(DailyStepsEntry(date: day, steps: 0))
        }
        return result
    }

    private func formattedSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedDistance(_ km: Double) -> String {
        distanceUnit.formatted(fromKm: km, fractionDigits: 1)
    }

    private func trendArrowSymbol() -> String {
        guard last7DaysSteps.count >= 2 else { return "arrow.right" }

        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        let count = sorted.count
        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else { return "arrow.right" }

        let yesterdaySteps = sorted[yesterdayIndex].steps
        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else { return "arrow.right" }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)
        let diff = Double(yesterdaySteps) - avgPrev
        let threshold: Double = 1_000

        if diff > threshold { return "arrow.up.right" }
        if diff < -threshold { return "arrow.down.right" }
        return "arrow.right"
    }

    private func trendArrowColor() -> Color {
        guard last7DaysSteps.count >= 2 else { return Color.Glu.primaryBlue }

        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        let count = sorted.count
        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else { return Color.Glu.primaryBlue }

        let yesterdaySteps = sorted[yesterdayIndex].steps
        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else { return Color.Glu.primaryBlue }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)
        let diff = Double(yesterdaySteps) - avgPrev

        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }
}

// MARK: - Mini Steps Trend Chart (Extracted)

private struct ActivityOverviewStepsMiniTrendChartV1: View {

    let data: [DailyStepsEntry]

    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Steps", entry.steps)
            )
            .cornerRadius(4)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.Glu.activityDomain.opacity(0.25),
                        Color.Glu.activityDomain
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .annotation(position: .top, alignment: .center) {
                Text(formattedStepsK(entry.steps))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(.bottom, 2)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }

    private func formattedStepsK(_ steps: Int) -> String {
        guard steps > 0 else { return "0" }
        if steps < 1_000 { return "\(steps)" }

        let value = Double(steps) / 1_000.0
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1fT", rounded)
    }
}

// MARK: - Preview (minimal, ohne zusätzliche Layout-Mods)

#Preview("Activity Steps Card V1") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let data: [DailyStepsEntry] = (0..<7).map { i in
        let date = calendar.date(byAdding: .day, value: -(6 - i), to: today) ?? today
        let steps = [4200, 8559, 10320, 7600, 12050, 9800, 6400][i]
        return DailyStepsEntry(date: date, steps: steps)
    }

    ActivityOverviewStepsCardV1(
        todaySteps: 900,
        stepsGoal: 10_000,
        stepsAverage7d: 9_120,
        distanceTodayKm: 6.8,
        distanceAverage7dKm: 7.4,
        last7DaysSteps: data,
        distanceUnit: .kilometers,
        onTap: {}
    )
}
