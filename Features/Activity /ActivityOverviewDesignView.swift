//
//  ActivityOverviewDesignView.swift
//  GluVibProbe
//
//  Design-only test for the Activity Overview Page
//  - No HealthStore, no AppState, no MVVM
//  - Pure layout with dummy data
//

import SwiftUI
import Charts

// MARK: - Dummy model for design

private struct ActivityOverviewDesignModel {

    // Steps
    var todaySteps: Int
    var stepsGoal: Int
    var last7DaysSteps: [DailyActivityPointDesign]

    // Distance (walking / running)
    var todayDistanceKm: Double
    var avgDistanceKm7d: Double

    // Exercise minutes
    var todayExerciseMinutes: Int
    var avgExerciseMinutes7d: Int

    // Active energy
    var todayActiveEnergyKcal: Int
    var avgActiveEnergy7d: Int

    // Movement split (heutiger Tag)
    var activeMinutes: Int
    var sedentaryMinutes: Int
    var sleepMinutes: Int

    // Activity Score (0–100)
    var activityScore: Int

    // Last exercise session
    var lastExerciseType: String
    var lastExerciseMinutes: Int

    static var mock: ActivityOverviewDesignModel {
        let today = Date()
        let stepsSeries = [7200, 8300, 9100, 6000, 10500, 9800, 8500]

        let last7Days: [DailyActivityPointDesign] = (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -6 + offset, to: today) ?? today
            let steps = stepsSeries[offset]
            return DailyActivityPointDesign(date: date, steps: steps)
        }

        return ActivityOverviewDesignModel(
            todaySteps: 8_540,
            stepsGoal: 10_000,
            last7DaysSteps: last7Days,
            todayDistanceKm: 6.8,
            avgDistanceKm7d: 6.2,
            todayExerciseMinutes: 42,
            avgExerciseMinutes7d: 38,
            todayActiveEnergyKcal: 620,
            avgActiveEnergy7d: 560,
            activeMinutes: 65,
            sedentaryMinutes: 640,
            sleepMinutes: 435,
            activityScore: 78,
            lastExerciseType: "Outdoor walk",
            lastExerciseMinutes: 32
        )
    }
}

// MARK: - Trend struct (design-only)

private struct DailyActivityPointDesign: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
}

// MARK: - Main design view

struct ActivityOverviewDesignView: View {

    @State private var model = ActivityOverviewDesignModel.mock

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Header (wie bei Body, aber Activity-Domain)
                OverviewHeader(
                    title: "Activity Overview",
                    subtitle: formattedToday(),
                    tintColor: Color.Glu.activityDomain,
                    hasScrolled: false
                )

                // Kleine Zeile für den Activity-Score über der Steps-Kachel
                HStack {
                    Spacer()
                    ActivityScoreBadge(score: model.activityScore)
                }
                .padding(.horizontal, 16)

                // Main Activity Card (Steps + Trendpfeil + Distanz + Mini-Trend)
                ActivityMainCardDesign(model: model)

                // Zeile 1: Exercise + Active Energy
                HStack(spacing: 12) {
                    ExerciseSmallCardDesign(model: model)
                    ActiveEnergySmallCardDesign(model: model)
                }

                // Movement Split (Active / Sedentary / Sleep)
                MovementSplitCardDesign(model: model)

                // Last Exercise
                LastExerciseCardDesign(model: model)

                // Insight
                ActivityInsightCardDesign(model: model)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.activityDomain
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Today, \(formatter.string(from: Date()))"
    }
}

// MARK: - Main full-width Activity card (Steps)

private struct ActivityMainCardDesign: View {

    let model: ActivityOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Title row with trend arrow on the right
            HStack {
                Label("Steps today", systemImage: "figure.walk.circle.fill")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Image(systemName: trendArrowSymbol())
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(trendArrowColor())
            }

            // Big KPI for Steps (mit Ziel & Delta)
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedSteps(model.todaySteps))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                HStack(spacing: 8) {
                    Text("Target: \(formattedSteps(model.stepsGoal))")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text("·")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text(stepsDeltaText)
                        .foregroundColor(stepsDeltaColor)
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            // Distanz-Zeile (heute + 7-Tage-Schnitt)
            HStack(spacing: 8) {
                Text("Distance today: \(formattedKm(model.todayDistanceKm))")
                Text("·")
                Text("7-day avg: \(formattedKm(model.avgDistanceKm7d))")
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            // Mini 7-Day Steps Trend (Balken in Activity-Farbe)
            if !model.last7DaysSteps.isEmpty {
                StepsMiniTrendChartDesign(data: model.last7DaysSteps)
                    .frame(height: 60)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)   // pure white card
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.40), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func formattedSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private func formattedKm(_ value: Double) -> String {
        String(format: "%.1f km", value)
    }

    private var stepsDeltaText: String {
        let diff = model.todaySteps - model.stepsGoal
        if diff > 0 {
            return "+\(formattedSteps(diff)) over"
        } else if diff < 0 {
            return "\(formattedSteps(abs(diff))) remaining"
        } else {
            return "On target"
        }
    }

    private var stepsDeltaColor: Color {
        let diff = model.todaySteps - model.stepsGoal
        if diff > 0 {
            return .green
        } else if diff < 0 {
            return Color.Glu.primaryBlue
        } else {
            return Color.Glu.primaryBlue
        }
    }

    private func trendArrowSymbol() -> String {
        guard let first = model.last7DaysSteps.first?.steps,
              let last = model.last7DaysSteps.last?.steps else {
            return "arrow.right"
        }
        let diff = last - first
        if diff > 1000 {
            return "arrow.up.right"
        } else if diff < -1000 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }

    private func trendArrowColor() -> Color {
        guard let first = model.last7DaysSteps.first?.steps,
              let last = model.last7DaysSteps.last?.steps else {
            return Color.Glu.primaryBlue
        }
        let diff = last - first
        if diff > 0 {
            return .green
        } else if diff < 0 {
            return .red
        } else {
            return Color.Glu.primaryBlue
        }
    }
}

// MARK: - Score Badge (bleibt wie gehabt)

private struct ActivityScoreBadge: View {

    let score: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("Activity score")
                .font(.caption2.weight(.semibold))
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

            Text("\(score)")
                .font(.caption.weight(.bold))
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.Glu.activityDomain.opacity(0.9),
                                    Color.Glu.activityDomain.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .foregroundColor(.white)
        }
    }
}

// MARK: - Small card: Exercise minutes

private struct ExerciseSmallCardDesign: View {

    let model: ActivityOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("Exercise", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(model.todayExerciseMinutes) min")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Today")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Last 7 days avg: \(model.avgExerciseMinutes7d) min")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

                let diff = model.todayExerciseMinutes - model.avgExerciseMinutes7d
                if diff != 0 {
                    Text(diffText(diff))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(diffColor(diff))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func diffText(_ diff: Int) -> String {
        if diff > 0 {
            return "+\(diff) min vs. 7-day avg"
        } else {
            return "\(abs(diff)) min below 7-day avg"
        }
    }

    private func diffColor(_ diff: Int) -> Color {
        diff > 0 ? .green : Color.Glu.primaryBlue.opacity(0.85)
    }
}

// MARK: - Small card: Active energy

private struct ActiveEnergySmallCardDesign: View {

    let model: ActivityOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("Active energy", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(model.todayActiveEnergyKcal) kcal")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Today")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Last 7 days avg: \(model.avgActiveEnergy7d) kcal")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

                let diff = model.todayActiveEnergyKcal - model.avgActiveEnergy7d
                if diff != 0 {
                    Text(diffText(diff))
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(diffColor(diff))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func diffText(_ diff: Int) -> String {
        if diff > 0 {
            return "+\(diff) kcal vs. 7-day avg"
        } else {
            return "\(abs(diff)) kcal below 7-day avg"
        }
    }

    private func diffColor(_ diff: Int) -> Color {
        diff > 0 ? .green : Color.Glu.primaryBlue.opacity(0.85)
    }
}

// MARK: - Movement Split Card (Active / Sedentary / Sleep)

private struct MovementSplitCardDesign: View {

    let model: ActivityOverviewDesignModel

    private var totalMinutes: Int {
        model.activeMinutes + model.sedentaryMinutes + model.sleepMinutes
    }

    private var activeShare: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(model.activeMinutes) / Double(totalMinutes)
    }

    private var sedentaryShare: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(model.sedentaryMinutes) / Double(totalMinutes)
    }

    private var sleepShare: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(model.sleepMinutes) / Double(totalMinutes)
    }

    var body: some View {
        HStack(spacing: 16) {

            // PIE / Donut Chart mit Tagesanteilen
            if #available(iOS 17.0, *) {
                Chart {
                    if activeShare > 0 {
                        SectorMark(
                            angle: .value("Active", activeShare),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.activityDomain)
                    }

                    if sedentaryShare > 0 {
                        SectorMark(
                            angle: .value("Sedentary", sedentaryShare),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.bodyDomain.opacity(0.8))
                    }

                    if sleepShare > 0 {
                        SectorMark(
                            angle: .value("Sleep", sleepShare),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.metabolicDomain)
                    }
                }
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                    Text("iOS 17 Pie only")
                        .font(.caption2)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.6))
                }
                .frame(width: 130, height: 130)
            }

            // LEGEND
            VStack(alignment: .leading, spacing: 8) {

                movementLegendRow(
                    color: Color.Glu.activityDomain,
                    label: "Active",
                    minutes: model.activeMinutes,
                    share: activeShare
                )

                movementLegendRow(
                    color: Color.Glu.bodyDomain.opacity(0.8),
                    label: "Sedentary (awake)",
                    minutes: model.sedentaryMinutes,
                    share: sedentaryShare
                )

                movementLegendRow(
                    color: Color.Glu.metabolicDomain,
                    label: "Sleep",
                    minutes: model.sleepMinutes,
                    share: sleepShare
                )

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func movementLegendRow(
        color: Color,
        label: String,
        minutes: Int,
        share: Double
    ) -> some View {
        let percent = Int((share * 100).rounded())

        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Spacer()

            Text("\(minutes) min  (\(percent)%)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
        }
    }
}

// MARK: - Last Exercise Card

private struct LastExerciseCardDesign: View {

    let model: ActivityOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("Last exercise", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            HStack(spacing: 8) {
                Text(model.lastExerciseType)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("·")

                Text("\(model.lastExerciseMinutes) min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

// MARK: - Insight card

private struct ActivityInsightCardDesign: View {

    let model: ActivityOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity insight")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            Text(insightText())
                .font(.subheadline)
                .foregroundColor(Color.Glu.primaryBlue)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func insightText() -> String {

        // sehr einfache Dummy-Logik:
        let stepsDiff   = model.todaySteps - model.stepsGoal
        let exDiff      = model.todayExerciseMinutes - model.avgExerciseMinutes7d
        let energyDiff  = model.todayActiveEnergyKcal - model.avgActiveEnergy7d

        if stepsDiff >= 0 && exDiff >= 0 && energyDiff >= 0 {
            return "You are above your usual activity level today. This level of movement can support more stable glucose values across the day."
        }

        if stepsDiff < 0 && exDiff < 0 && energyDiff < 0 {
            return "Today is still below your usual activity baseline. Even a short walk or light exercise session can improve insulin sensitivity."
        }

        if stepsDiff >= 0 && exDiff < 0 {
            return "You reached your step goal, but structured exercise minutes are a bit lower than usual. A short, focused workout could be a good addition."
        }

        if stepsDiff < 0 && exDiff >= 0 {
            return "Exercise minutes look solid, even if the total steps are not yet at your target. Some extra light movement during the day can close the gap."
        }

        return "Your activity today is close to your usual range. Small, consistent movements across the day are especially helpful for glucose control."
    }
}

// MARK: - Mini chart for steps (bar chart, smaller – Balken in Activity-Farbe)

private struct StepsMiniTrendChartDesign: View {

    let data: [DailyActivityPointDesign]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Steps", point.steps)
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartForegroundStyleScale([
            "Steps": Color.Glu.activityDomain
        ])
        .foregroundStyle(Color.Glu.activityDomain)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
    }
}

// MARK: - Preview

#Preview("Activity Overview – Design Test") {
    ActivityOverviewDesignView()
}
