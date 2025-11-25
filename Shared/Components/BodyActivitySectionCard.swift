//
//  ActivityStepsSectionCard.swift
//  GluVibProbe
//

import SwiftUI

struct ActivityStepsSectionCard: View {

    // MARK: - Eingabewerte

    let title: String
    let kpiTitle: String
    let kpiValue: String
    let dailyStepsGoal: String
    let stepsToGoValue: String
    let last90DaysData: [DailyStepsEntry]
    let monthlyData: [MonthlyMetricEntry]
    let sectionTitle: String
    let onMetricSelected: (String) -> Void

    // Chip-Namen
    private let metricNames: [String] = ["Weight", "Steps", "Sleep", "Activity Energy"]

    // MARK: - Initializer

    init(
        sectionTitle: String = "Körper & Aktivität",
        title: String,
        kpiTitle: String,
        kpiValue: String,
        dailyStepsGoal: String,
        stepsToGoValue: String,
        last90DaysData: [DailyStepsEntry],
        monthlyData: [MonthlyMetricEntry],
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.sectionTitle = sectionTitle
            self.title = title
            self.kpiTitle = kpiTitle
            self.kpiValue = kpiValue
            self.dailyStepsGoal = dailyStepsGoal
            self.stepsToGoValue = stepsToGoValue
            self.last90DaysData = last90DaysData
            self.monthlyData = monthlyData
            self.onMetricSelected = onMetricSelected
        }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Haupt-Header
            SectionHeader(
                title: sectionTitle,
                subtitle: nil
            )

            // Chips (Weight / Steps / Sleep / Activity Energy)
            metricChips

            // KPI-Bereich
            kpiHeader

            // 90-Tage-Chart
            Last90DaysBarChart(entries: last90DaysData)
                .frame(height: 260)

            // Monats-Chart
            MonthlyBarChart(data: monthlyData)
                .frame(height: 260)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.Glu.backgroundSurface)
                .shadow(
                    color: .black.opacity(0.10),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
    }
}

// MARK: - Subviews

private extension ActivityStepsSectionCard {

    // MARK: Metric Chips
    var metricChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(metricNames.enumerated()), id: \.offset) { _, metric in
                    let active = (metric == title)

                    Text(metric)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)        // 🔥 SE-sicher (kleiner als vorher)
                        .padding(.vertical, 5)           // 🔥 minimal kompakter
                        .padding(.horizontal, 9)         // 🔥 schmaler als vorher
                        .background(
                            Capsule().fill(
                                active
                                    ? Color.Glu.activityOrange
                                    : Color.Glu.backgroundSurface
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                active
                                    ? Color.clear
                                    : Color.Glu.activityOrange.opacity(0.8),
                                lineWidth: active ? 0 : 1
                            )
                        )
                        .foregroundStyle(
                            active
                                ? Color.Glu.primaryBlue
                                : Color.Glu.primaryBlue.opacity(0.85)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
                        .onTapGesture {
                            onMetricSelected(metric)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)   // 🔥 Chips mittig zentrieren
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    // MARK: KPI-Header
    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

           

            // 1️⃣ Goal
            KPICard(
                title: "Goal",
                stepsToday: dailyStepsGoal,
                unit: nil
            )

            // 2️⃣ Today
            KPICard(
                title: "Today",
                stepsToday: kpiValue,
                unit: nil
            )

            // 3️⃣ to go
            KPICard(
                title: "to go",
                stepsToday: stepsToGoValue,
                unit: nil
            )
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let demoLast90: [DailyStepsEntry] = (0..<90).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        return DailyStepsEntry(date: date, steps: Int.random(in: 2_000...12_000))
    }.sorted { $0.date < $1.date }

    let demoMonthly: [MonthlyMetricEntry] = [
        MonthlyMetricEntry(monthShort: "Feb", value: 140_000),
        MonthlyMetricEntry(monthShort: "Mar", value: 155_000),
        MonthlyMetricEntry(monthShort: "Apr", value: 168_000),
        MonthlyMetricEntry(monthShort: "May", value: 160_000),
        MonthlyMetricEntry(monthShort: "Jun", value: 172_000)
    ]

    return ActivityStepsSectionCard(
        title: "Steps",
        kpiTitle: "Steps Today",
        kpiValue: "8 532",
        dailyStepsGoal: "10 000", 
        stepsToGoValue: "1 468",
        last90DaysData: demoLast90,
        monthlyData: demoMonthly
    )
    .padding()
    .background(Color.Glu.backgroundNavy)
}
