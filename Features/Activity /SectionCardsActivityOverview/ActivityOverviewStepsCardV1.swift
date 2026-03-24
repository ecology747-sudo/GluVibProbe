//
//  ActivityOverviewStepsCardV1.swift
//  GluVibProbe
//

import SwiftUI
import Charts

struct ActivityOverviewStepsCardV1: View {

    let todaySteps: Int
    let stepsGoal: Int
    let stepsAverage7d: Int

    let distanceTodayKm: Double
    let distanceAverage7dKm: Double

    // ✅ SSoT: VM liefert exakt die 7 Tage, die angezeigt werden sollen (oldest → newest)
    let last7DaysSteps: [DailyStepsEntry]

    let distanceUnit: DistanceUnit
    let onTap: () -> Void

    private var hasReachedGoal: Bool {
        stepsGoal > 0 && todaySteps >= stepsGoal
    }

    private var stepsAccentColor: Color {
        hasReachedGoal ? Color.Glu.successGreen : Color.Glu.activityDomain
    }

    var body: some View {
        VStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 8) {
                headerRow
                stepsBlock

                ActivityOverviewStepsMiniTrendChartV1(
                    data: last7DaysSteps,
                    stepsGoal: stepsGoal
                )
                .frame(height: 60)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

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
                Text(L10n.ActivityOverview.stepsTitle) // UPDATED
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
                    .foregroundColor(hasReachedGoal ? Color.Glu.successGreen : Color.Glu.primaryBlue)

                Spacer()

                HStack(spacing: 4) {
                    Text(L10n.ActivityOverview.stepsRemaining)
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
                Text(L10n.ActivityOverview.stepsTarget)
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

                Text(L10n.ActivityOverview.distanceTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
            }

            HStack(alignment: .firstTextBaseline) {

                Text(formattedDistance(distanceTodayKm))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                HStack(spacing: 6) {
                    Text(L10n.ActivityOverview.average7d)
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

    private func formattedSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedDistance(_ km: Double) -> String {
        distanceUnit.formatted(fromKm: km, fractionDigits: 1)
    }

    private func trendArrowSymbol() -> String {
        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        guard sorted.count >= 4 else { return "arrow.right" }

        let lastIndex = sorted.count - 1
        let lastDaySteps = sorted[lastIndex].steps

        let startIndex = max(0, lastIndex - 3)
        let previousSlice = sorted[startIndex..<lastIndex]
        guard !previousSlice.isEmpty else { return "arrow.right" }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)
        let diff = Double(lastDaySteps) - avgPrev
        let threshold: Double = 1_000

        if diff > threshold { return "arrow.up.right" }
        if diff < -threshold { return "arrow.down.right" }
        return "arrow.right"
    }

    private func trendArrowColor() -> Color {
        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        guard sorted.count >= 4 else { return Color.Glu.primaryBlue }

        let lastIndex = sorted.count - 1
        let lastDaySteps = sorted[lastIndex].steps

        let startIndex = max(0, lastIndex - 3)
        let previousSlice = sorted[startIndex..<lastIndex]
        guard !previousSlice.isEmpty else { return Color.Glu.primaryBlue }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)
        let diff = Double(lastDaySteps) - avgPrev

        if diff > 0 { return Color.Glu.successGreen }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }
}

// MARK: - Mini Steps Trend Chart (Extracted)

private struct ActivityOverviewStepsMiniTrendChartV1: View {

    let data: [DailyStepsEntry]
    let stepsGoal: Int

    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Steps", entry.steps)
            )
            .cornerRadius(4)
            .foregroundStyle(barGradient(for: entry.steps))
            .annotation(position: entry.steps == 0 ? .bottom : .top, alignment: .center) {
                Text(formattedStepsK(entry.steps))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(entry.steps == 0 ? .top : .bottom, 2)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
                AxisValueLabel(centered: true) { // UPDATED
                    if let date = value.as(Date.self) {
                        Text(weekday2(date))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }

    private func barGradient(for steps: Int) -> LinearGradient {
        let hitGoal = stepsGoal > 0 && steps >= stepsGoal
        let c = hitGoal ? Color.Glu.successGreen : Color.Glu.activityDomain

        return LinearGradient(
            colors: [
                c.opacity(0.25),
                c
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func formattedStepsK(_ steps: Int) -> String {
        guard steps > 0 else { return "0" }
        if steps < 1_000 { return "\(steps)" }

        let value = Double(steps) / 1_000.0
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f%@", rounded, L10n.Common.thousandSuffix) // UPDATED
    }

    private func weekday2(_ date: Date) -> String { // UPDATED
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EE"
        return f.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}

#Preview("Activity Steps Card V1") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let data: [DailyStepsEntry] = (0..<7).map { i in
        let date = calendar.date(byAdding: .day, value: -(6 - i), to: today) ?? today
        let steps = [5200, 4200, 8559, 10320, 7600, 12050, 9800][i]
        return DailyStepsEntry(date: date, steps: steps)
    }

    ActivityOverviewStepsCardV1(
        todaySteps: 1005,
        stepsGoal: 10_000,
        stepsAverage7d: 9_120,
        distanceTodayKm: 0.8,
        distanceAverage7dKm: 5.1,
        last7DaysSteps: data,
        distanceUnit: .kilometers,
        onTap: {}
    )
}
