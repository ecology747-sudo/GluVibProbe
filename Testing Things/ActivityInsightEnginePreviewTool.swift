//
//  ActivityInsightEnginePreviewTool.swift
//  GluVibProbe
//
//  Debug / Preview Tool for ActivityInsightEngine
//
//  V7
//  - Manual testing only
//  - No scenario picker
//  - Uses only Steps + Active Energy + Time + Goal/Baselines
//  - Only blocks up to Preview Time are evaluated
//  - Updated for simplified closed-state Activity Insight Engine
//  - 🟨 UPDATED: supports optional workout context per activity block
//

import SwiftUI

struct ActivityInsightEnginePreviewTool: View {

    // ============================================================
    // MARK: - Nested Models
    // ============================================================

    struct ActivityBlock: Identifiable {
        let id = UUID()

        var isEnabled: Bool = true
        var time: Date
        var title: String

        var steps: Int
        var activeEnergyKcal: Int

        // 🟨 UPDATED
        var hasWorkout: Bool = false
        var workoutMinutes: Int = 0
        var workoutTitle: String = "Workout"
    }

    private struct AggregatedScenario {
        let stepsToday: Int
        let activeEnergyTodayKcal: Int
        let lastWorkout: ActivityLastWorkoutInfo?
        let hasWorkoutContextHint: Bool
    }

    private struct EngineDebugSnapshot {
        let stepsDeviationPercent: Double?
        let energyDeviationPercent: Double?
        let goalRatio: Double?
    }

    // ============================================================
    // MARK: - State
    // ============================================================

    @State private var previewNow: Date = Self.makeTodayTime(hour: 22, minute: 30)

    @State private var stepsGoal: Int = 10_000
    @State private var steps7DayAverage: Int = 8_000
    @State private var activeEnergy30DayAverage: Int = 820

    @State private var block1: ActivityBlock = .init(
        time: Self.makeTodayTime(hour: 9, minute: 0),
        title: "Activity Block 1",
        steps: 1_800,
        activeEnergyKcal: 60,
        hasWorkout: false,
        workoutMinutes: 50,
        workoutTitle: "Gym Workout"
    )

    @State private var block2: ActivityBlock = .init(
        time: Self.makeTodayTime(hour: 14, minute: 0),
        title: "Activity Block 2",
        steps: 1_400,
        activeEnergyKcal: 55,
        hasWorkout: false,
        workoutMinutes: 30,
        workoutTitle: "Workout"
    )

    @State private var block3: ActivityBlock = .init(
        time: Self.makeTodayTime(hour: 19, minute: 0),
        title: "Activity Block 3",
        steps: 2_200,
        activeEnergyKcal: 620,
        hasWorkout: false,
        workoutMinutes: 45,
        workoutTitle: "Workout"
    )

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var allEnabledBlocks: [ActivityBlock] {
        [block1, block2, block3]
            .filter { $0.isEnabled }
            .sorted { $0.time < $1.time }
    }

    private var effectiveBlocksForPreviewTime: [ActivityBlock] {
        allEnabledBlocks.filter { $0.time <= previewNow }
    }

    private var scenario: AggregatedScenario {
        let stepsToday = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.steps) }
        let activeEnergyTodayKcal = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.activeEnergyKcal) }

        let lastWorkoutBlock = effectiveBlocksForPreviewTime
            .filter { $0.hasWorkout && $0.workoutMinutes > 0 }
            .sorted { $0.time > $1.time }
            .first

        let lastWorkout: ActivityLastWorkoutInfo? = {
            guard let block = lastWorkoutBlock else { return nil }

            return ActivityLastWorkoutInfo(
                name: block.workoutTitle,
                minutes: block.workoutMinutes,
                distanceKm: nil,
                energyKcal: block.activeEnergyKcal > 0 ? block.activeEnergyKcal : nil,
                startDate: block.time
            )
        }()

        return AggregatedScenario(
            stepsToday: stepsToday,
            activeEnergyTodayKcal: activeEnergyTodayKcal,
            lastWorkout: lastWorkout,
            hasWorkoutContextHint: lastWorkout != nil
        )
    }

    private var insightOutput: ActivityInsightOutput {
        let input = ActivityInsightInput(
            now: previewNow,
            calendar: .current,
            stepsToday: scenario.stepsToday,
            stepsGoal: stepsGoal,
            steps7DayAverage: steps7DayAverage,
            activeEnergyTodayKcal: scenario.activeEnergyTodayKcal,
            activeEnergy30DayAverageKcal: activeEnergy30DayAverage,
            lastWorkout: scenario.lastWorkout,
            hasWorkoutContextHint: scenario.hasWorkoutContextHint
        )

        return ActivityInsightEngine.generateInsight(from: input)
    }

    private var engineDebugSnapshot: EngineDebugSnapshot {
        let progress = max(dayProgressFraction, 0.05)

        let stepsExpected = Double(steps7DayAverage) * progress
        let energyExpected = Double(activeEnergy30DayAverage) * progress

        let stepsDeviation: Double? = stepsExpected > 0
            ? (Double(scenario.stepsToday) - stepsExpected) / stepsExpected
            : nil

        let energyDeviation: Double? = energyExpected > 0
            ? (Double(scenario.activeEnergyTodayKcal) - energyExpected) / energyExpected
            : nil

        let goalRatio: Double? = stepsGoal > 0
            ? Double(scenario.stepsToday) / Double(stepsGoal)
            : nil

        return EngineDebugSnapshot(
            stepsDeviationPercent: stepsDeviation,
            energyDeviationPercent: energyDeviation,
            goalRatio: goalRatio
        )
    }

    private var minutesElapsedToday: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: previewNow)
        return max(0, min(Int(previewNow.timeIntervalSince(startOfDay) / 60.0), 1440))
    }

    private var dayProgressFraction: Double {
        Double(minutesElapsedToday) / 1440.0
    }

    private func isBlockInPastOrPresent(_ block: ActivityBlock) -> Bool {
        block.time <= previewNow
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                insightSection
                previewTimeSection
                baselineSection
                computedMetricsSection

                CompactActivityBlockEditor(
                    block: $block1,
                    isEffectiveForPreview: isBlockInPastOrPresent(block1)
                )

                CompactActivityBlockEditor(
                    block: $block2,
                    isEffectiveForPreview: isBlockInPastOrPresent(block2)
                )

                CompactActivityBlockEditor(
                    block: $block3,
                    isEffectiveForPreview: isBlockInPastOrPresent(block3)
                )

                debugSection
            }
            .padding(10)
            .padding(.bottom, 44)
        }
        .background(
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.activityDomain.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// ============================================================
// MARK: - Sections
// ============================================================

private extension ActivityInsightEnginePreviewTool {

    var previewTimeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            DatePicker(
                "",
                selection: $previewNow,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .scaleEffect(0.92, anchor: .leading)
            .fixedSize()
        }
        .padding(8)
        .compactCard()
    }

    var baselineSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            compactStepperRow(
                title: "Step Goal",
                valueText: stepsGoal.formatted(.number.grouping(.automatic)),
                value: $stepsGoal,
                step: 500,
                range: 0...30_000
            )

            compactStepperRow(
                title: "Steps 7d Avg",
                valueText: steps7DayAverage.formatted(.number.grouping(.automatic)),
                value: $steps7DayAverage,
                step: 500,
                range: 0...30_000
            )

            compactStepperRow(
                title: "Energy 30d Avg",
                valueText: "\(activeEnergy30DayAverage) kcal",
                value: $activeEnergy30DayAverage,
                step: 25,
                range: 0...2_000
            )
        }
        .padding(8)
        .compactCard()
    }

    var computedMetricsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Computed Engine Input")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            compactMetricRow("Steps Today", "\(scenario.stepsToday)")
            compactMetricRow("Energy Today", "\(scenario.activeEnergyTodayKcal) kcal")
            compactMetricRow("Counted Blocks", "\(effectiveBlocksForPreviewTime.count) / \(allEnabledBlocks.count)")
            compactMetricRow("Workout Context", scenario.hasWorkoutContextHint ? "true" : "false")

            if let lastWorkout = scenario.lastWorkout {
                compactMetricRow("Last Workout", "\(lastWorkout.name) · \(lastWorkout.minutes) min")
            }
        }
        .padding(8)
        .compactCard()
    }

    var insightSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insight")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Text(insightOutput.primaryText)
                .font(.footnote)
                .foregroundStyle(Color.Glu.primaryBlue)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(8)
        .compactCard()
    }

    var debugSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Engine Debug")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            compactMetricRow("Output Class", insightOutput.debug?.outputClass ?? "–")
            compactMetricRow("Confidence", insightOutput.debug?.confidence ?? "–")
            compactMetricRow("Window Stage", insightOutput.debug?.windowStage ?? "–")
            compactMetricRow("Practical Day Close", formatBool(insightOutput.debug?.isPracticalDayClose))
            compactMetricRow("Availability", insightOutput.debug?.availability ?? "–")
            compactMetricRow("Steps Status", insightOutput.debug?.stepsStatus ?? "–")
            compactMetricRow("Energy Status", insightOutput.debug?.energyStatus ?? "–")
            compactMetricRow("Combined Primary", insightOutput.debug?.combinedPrimary ?? "–")
            compactMetricRow("Combined Bias", insightOutput.debug?.combinedBias ?? "–")
            compactMetricRow("Goal Status", insightOutput.debug?.goalStatus ?? "–")
            compactMetricRow("Achievement", insightOutput.debug?.achievementState ?? "–")
            compactMetricRow("Suppression", insightOutput.debug?.suppressionReason ?? "–")
            compactMetricRow("Steps Deviation", formatPercent(engineDebugSnapshot.stepsDeviationPercent))
            compactMetricRow("Energy Deviation", formatPercent(engineDebugSnapshot.energyDeviationPercent))
            compactMetricRow("Goal Ratio", formatRatio(engineDebugSnapshot.goalRatio))
            compactMetricRow("Day Progress", formatPercent(dayProgressFraction))

            if let rules = insightOutput.debug?.appliedRules, !rules.isEmpty {
                compactMetricRow("Applied Rules", rules.joined(separator: ", "))
            }
        }
        .padding(8)
        .compactCard()
    }

    func compactMetricRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Spacer(minLength: 6)

            Text(value)
                .font(.caption)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.88))
                .multilineTextAlignment(.trailing)
        }
    }

    func formatBool(_ value: Bool?) -> String {
        guard let value else { return "–" }
        return value ? "true" : "false"
    }
}

// ============================================================
// MARK: - Compact Activity Block Editor
// ============================================================

private struct CompactActivityBlockEditor: View {

    @Binding var block: ActivityInsightEnginePreviewTool.ActivityBlock
    let isEffectiveForPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(block.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer(minLength: 6)

                Toggle("", isOn: $block.isEnabled)
                    .labelsHidden()
                    .scaleEffect(0.72)
            }

            if !isEffectiveForPreview, block.isEnabled {
                Text("Future block — not counted for current preview time")
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))
            }

            HStack(spacing: 6) {
                Text("Time")
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer(minLength: 6)

                DatePicker(
                    "",
                    selection: $block.time,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .scaleEffect(0.84, anchor: .trailing)
                .fixedSize()
            }

            compactStepperRow(
                title: "Steps",
                valueText: block.steps.formatted(.number.grouping(.automatic)),
                value: $block.steps,
                step: 500,
                range: 0...25_000
            )

            compactStepperRow(
                title: "Energy",
                valueText: "\(block.activeEnergyKcal) kcal",
                value: $block.activeEnergyKcal,
                step: 25,
                range: 0...2_000
            )

            // 🟨 UPDATED
            HStack(spacing: 6) {
                Text("Recorded Workout")
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer(minLength: 6)

                Toggle("", isOn: $block.hasWorkout)
                    .labelsHidden()
                    .scaleEffect(0.78)
            }

            if block.hasWorkout {
                compactStepperRow(
                    title: "Workout Minutes",
                    valueText: "\(block.workoutMinutes) min",
                    value: $block.workoutMinutes,
                    step: 5,
                    range: 0...240
                )
            }
        }
        .padding(8)
        .compactCard()
        .opacity((!isEffectiveForPreview && block.isEnabled) ? 0.78 : 1.0)
    }

    private func compactStepperRow(
        title: String,
        valueText: String,
        value: Binding<Int>,
        step: Int,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 6) {
            Text("\(title): \(valueText)")
                .font(.caption)
                .foregroundStyle(Color.Glu.primaryBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 6)

            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .scaleEffect(0.78, anchor: .trailing)
                .fixedSize()
        }
    }
}

// ============================================================
// MARK: - Shared Compact Stepper Row
// ============================================================

private func compactStepperRow(
    title: String,
    valueText: String,
    value: Binding<Int>,
    step: Int,
    range: ClosedRange<Int>
) -> some View {
    HStack(spacing: 6) {
        Text("\(title): \(valueText)")
            .font(.caption)
            .foregroundStyle(Color.Glu.primaryBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.85)

        Spacer(minLength: 6)

        Stepper("", value: value, in: range, step: step)
            .labelsHidden()
            .scaleEffect(0.78, anchor: .trailing)
            .fixedSize()
    }
}

// ============================================================
// MARK: - Compact Card Modifier
// ============================================================

private extension View {
    func compactCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.1)
            )
    }
}

// ============================================================
// MARK: - Formatting Helpers
// ============================================================

private extension ActivityInsightEnginePreviewTool {

    func formatPercent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.0f%%", value * 100.0)
    }

    func formatRatio(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.2f", value)
    }

    static func makeTodayTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Activity Insight Tool") {
    ActivityInsightEnginePreviewTool()
}
