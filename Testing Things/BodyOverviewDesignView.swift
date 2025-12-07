//
//  BodyOverviewDesignView.swift
//  GluVibProbe
//
//  Design-only test for the Body Overview Page
//  - No HealthStore, no AppState, no MVVM
//  - Pure layout with dummy data
//

import SwiftUI
import Charts

// MARK: - Dummy model for design

private struct BodyOverviewDesignModel {

    // Weight
    var todayWeightKg: Double?
    var targetWeightKg: Double
    var weightDeltaKg: Double
    var weightTrend: [WeightTrendPointDesign]

    // Sleep
    var lastNightSleepMinutes: Int
    var sleepGoalMinutes: Int
    var sleepGoalCompletion: Double      // 0.0–1.5

    // Heart / HRV
    var restingHeartRateBpm: Int
    var hrvMs: Int

    // Body composition
    var bmi: Double
    var bodyFatPercent: Double

    // Dummy instance for preview & testing
    static var mock: BodyOverviewDesignModel {
        let today = Date()

        // Dummy weight trend (10 measurements, slightly decreasing)
        let weightTrend: [WeightTrendPointDesign] = (0..<10).map { offset in
            let date = Calendar.current.date(
                byAdding: .day,
                value: -9 + offset,
                to: today
            ) ?? today

            let weight = 96.0 - Double(offset) * 0.2
            return WeightTrendPointDesign(date: date, weightKg: weight)
        }

        return BodyOverviewDesignModel(
            todayWeightKg: 96.0,
            targetWeightKg: 92.0,
            weightDeltaKg: 4.0,
            weightTrend: weightTrend,
            lastNightSleepMinutes: 450,            // 7.5 hours
            sleepGoalMinutes: 480,                 // 8h target
            sleepGoalCompletion: 450.0 / 480.0,    // ~94%
            restingHeartRateBpm: 58,
            hrvMs: 72,
            bmi: 29.4,
            bodyFatPercent: 23.0
        )
    }
}

// MARK: - Trend struct (design-only)

private struct WeightTrendPointDesign: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

// MARK: - Main design view

struct BodyOverviewDesignView: View {

    @State private var model = BodyOverviewDesignModel.mock

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                WeightMainCardDesign(model: model)

                HStack(spacing: 12) {
                    SleepSmallCardDesign(model: model)
                    HeartSmallCardDesign(model: model)
                }

                HStack(spacing: 12) {
                    BMISmallCardDesign(model: model)
                    BodyFatSmallCardDesign(model: model)
                }

                BodyInsightCardDesign(model: model)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.bodyDomain
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Body Overview",
                subtitle: formattedToday()
            )
        }
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - Weight: main full-width card

private struct WeightMainCardDesign: View {

    let model: BodyOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Title row with big trend arrow on the right
            HStack {
                Label("Weight & trend", systemImage: "scalemass.fill")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Image(systemName: trendArrowSymbol())
                    .font(.largeTitle.weight(.bold))      // bigger & stronger
                    .foregroundColor(trendArrowColor())
            }

            // KPI
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedWeight(model.todayWeightKg))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                HStack(spacing: 8) {
                    Text("Target: \(formattedWeight(model.targetWeightKg))")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text("·")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text(formattedDeltaKg(model.weightDeltaKg))
                        .foregroundColor(deltaColor(for: model.weightDeltaKg))
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            // Compact bar chart (smaller, no extra description)
            if !model.weightTrend.isEmpty {
                WeightMiniTrendChartDesign(data: model.weightTrend)
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
                        .stroke(Color.Glu.bodyDomain.opacity(0.40), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func formattedWeight(_ value: Double?) -> String {
        guard let value = value else { return "–" }
        return String(format: "%.1f kg", value)
    }

    private func formattedWeight(_ value: Double) -> String {
        return String(format: "%.1f kg", value)
    }

    private func formattedDeltaKg(_ delta: Double) -> String {
        if delta > 0 {
            return String(format: "+%.1f kg", delta)
        } else if delta < 0 {
            return String(format: "%.1f kg", delta)
        } else {
            return "±0.0 kg"
        }
    }

    private func deltaColor(for delta: Double) -> Color {
        if delta > 0 {
            return .red
        } else if delta < 0 {
            return .green
        } else {
            return Color.Glu.primaryBlue
        }
    }

    private func trendArrowSymbol() -> String {
        guard let first = model.weightTrend.first?.weightKg,
              let last = model.weightTrend.last?.weightKg else {
            return "arrow.right"
        }
        let diff = last - first
        if diff > 0.5 {
            return "arrow.up.right"
        } else if diff < -0.5 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }

    private func trendArrowColor() -> Color {
        guard let first = model.weightTrend.first?.weightKg,
              let last = model.weightTrend.last?.weightKg else {
            return Color.Glu.primaryBlue
        }
        let diff = last - first
        return deltaColor(for: diff)
    }
}

// MARK: - Sleep: small tile

private struct SleepSmallCardDesign: View {

    let model: BodyOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("Sleep", systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedSleep(minutes: model.lastNightSleepMinutes))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Last night")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 4) {
                let ratio = min(model.sleepGoalCompletion, 1.5)
                let percent = Int(ratio * 100)

                ProgressView(value: ratio, total: 1.0)
                    .tint(Color.Glu.bodyDomain)

                Text("Goal completion: \(percent)% of \(model.sleepGoalMinutes) min")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)    // white card
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func formattedSleep(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours) h \(mins) min"
        } else {
            return "\(mins) min"
        }
    }
}

// MARK: - Heart & Stress: small tile

private struct HeartSmallCardDesign: View {

    let model: BodyOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("Heart & stress", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(model.restingHeartRateBpm) bpm")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Resting heart rate")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.hrvMs) ms")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("HRV today")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
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
                        .stroke(Color.Glu.bodyDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }
}

// MARK: - BMI: small tile

private struct BMISmallCardDesign: View {

    let model: BodyOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("BMI", systemImage: "figure.arms.open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", model.bmi))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(bmiCategoryText(for: model.bmi))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
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
                        .stroke(Color.Glu.bodyDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func bmiCategoryText(for bmi: Double) -> String {
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal range"
        case 25..<30:
            return "Overweight"
        default:
            return "Obesity range"
        }
    }
}

// MARK: - Body Fat: small tile

private struct BodyFatSmallCardDesign: View {

    let model: BodyOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label("Body fat", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f %%", model.bodyFatPercent))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Estimated body fat")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
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
                        .stroke(Color.Glu.bodyDomain.opacity(0.30), lineWidth: 1)
                )
        )
    }
}

// MARK: - Insight card

private struct BodyInsightCardDesign: View {

    let model: BodyOverviewDesignModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Body insight")
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
                        .stroke(Color.Glu.bodyDomain.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private func insightText() -> String {
        // Very simple dummy logic based on weight trend + sleep
        guard let first = model.weightTrend.first?.weightKg,
              let last = model.weightTrend.last?.weightKg else {
            return "There is not enough data yet to generate a meaningful body insight."
        }

        let diff = last - first
        if diff > 0.5 {
            if model.lastNightSleepMinutes < model.sleepGoalMinutes {
                return "Your weight has slightly increased over the last days. Try to keep an eye on sleep, activity and lighter dinners in the evening."
            } else {
                return "Your weight has slightly increased while your sleep looks quite stable. Watch your energy balance and aim for regular movement throughout the day."
            }
        } else if diff < -0.5 {
            return "Your weight has slightly decreased over the last days – well done. Staying consistent with your current routine for sleep, nutrition and activity can help you maintain this trend."
        } else {
            return "Your weight has been fairly stable over the last days. This is ideal if your goal is weight maintenance. Small adjustments in sleep or activity can still add extra reserves."
        }
    }
}

// MARK: - Mini chart for weight (bar chart, smaller)

private struct WeightMiniTrendChartDesign: View {

    let data: [WeightTrendPointDesign]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Weight", point.weightKg)
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
    }
}

// MARK: - Preview

struct BodyOverviewDesignView_Previews: PreviewProvider {
    static var previews: some View {
        BodyOverviewDesignView()
            .previewDisplayName("Body Overview – Design Test")
    }
}
