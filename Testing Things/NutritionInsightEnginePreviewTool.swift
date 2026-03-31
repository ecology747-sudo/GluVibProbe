//
//  NutritionInsightEnginePreviewTool.swift
//  GluVibProbe
//
//  Debug / Preview Tool for NutritionInsightEngine
//
//  V2
//  - Manual testing only
//  - No scenario picker
//  - Uses nutrition targets, meal blocks, energy context and KH split
//  - Only meal blocks up to Preview Time are evaluated
//  - Built in the same style as ActivityInsightEnginePreviewTool
//

import SwiftUI

struct NutritionInsightEnginePreviewTool: View {

    // ============================================================
    // MARK: - Nested Models
    // ============================================================

    struct NutritionBlock: Identifiable {
        let id = UUID()

        var isEnabled: Bool = true
        var time: Date
        var title: String

        var carbs: Int
        var sugar: Int
        var protein: Int
        var fat: Int
        var nutritionEnergyKcal: Int
    }

    private struct AggregatedScenario {
        let carbsToday: Int
        let sugarToday: Int
        let proteinToday: Int
        let fatToday: Int
        let nutritionEnergyTodayKcal: Int

        let carbsMorningGrams: Int
        let carbsAfternoonGrams: Int
        let carbsNightGrams: Int
    }

    private struct EngineDebugSnapshot {
        let windowStage: String // 🟨 UPDATED
        let isPracticalDayClose: Bool // 🟨 UPDATED
        let availability: String // 🟨 UPDATED

        let carbsStatus: String // 🟨 UPDATED
        let proteinStatus: String // 🟨 UPDATED
        let fatStatus: String // 🟨 UPDATED
        let caloriesStatus: String // 🟨 UPDATED
        let energyStatus: String // 🟨 UPDATED

        let carbsProgressState: String // 🟨 UPDATED
        let proteinProgressState: String // 🟨 UPDATED
        let fatProgressState: String // 🟨 UPDATED
        let caloriesProgressState: String // 🟨 UPDATED

        let macroStructureStatus: String // 🟨 UPDATED
        let carbSplitStatus: String // 🟨 UPDATED
        let combinedBias: String // 🟨 UPDATED
        let mainCriteriaAlignment: String // 🟨 UPDATED
        let achievementState: String // 🟨 UPDATED
        let mainTargetLeadState: String // 🟨 UPDATED

        let achievedMainTargetCount: Int // 🟨 UPDATED
        let strongAchievedMainTargetCount: Int // 🟨 UPDATED
        let laggingMainTargetCount: Int // 🟨 UPDATED
        let onTrackMainTargetCount: Int // 🟨 UPDATED
        let aheadMainTargetCount: Int // 🟨 UPDATED
        let overrunMainTargetCount: Int // 🟨 UPDATED

        let carbsRatio: Double?
        let proteinRatio: Double?
        let fatRatio: Double?
        let caloriesRatio: Double?
        let balanceRatio: Double?
        let currentEnergyDeltaKcal: Int
    }

    // ============================================================
    // MARK: - State
    // ============================================================

    @State private var previewNow: Date = Self.makeTodayTime(hour: 22, minute: 30)

    @State private var carbsTarget: Int = 200
    @State private var sugarTarget: Int = 200
    @State private var proteinTarget: Int = 180
    @State private var fatTarget: Int = 120
    @State private var caloriesTarget: Int = 2500

    @State private var activeEnergyTodayKcal: Int = 620
    @State private var restingEnergyTodayKcal: Int = 1650
    @State private var isDataAccessBlocked: Bool = false

    @State private var block1: NutritionBlock = .init(
        time: Self.makeTodayTime(hour: 8, minute: 30),
        title: "Meal Block 1",
        carbs: 55,
        sugar: 10,
        protein: 25,
        fat: 15,
        nutritionEnergyKcal: 440
    )

    @State private var block2: NutritionBlock = .init(
        time: Self.makeTodayTime(hour: 13, minute: 15),
        title: "Meal Block 2",
        carbs: 70,
        sugar: 20,
        protein: 30,
        fat: 20,
        nutritionEnergyKcal: 640
    )

    @State private var block3: NutritionBlock = .init(
        time: Self.makeTodayTime(hour: 19, minute: 30),
        title: "Meal Block 3",
        carbs: 70,
        sugar: 10,
        protein: 30,
        fat: 25,
        nutritionEnergyKcal: 720
    )

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var allEnabledBlocks: [NutritionBlock] {
        [block1, block2, block3]
            .filter { $0.isEnabled }
            .sorted { $0.time < $1.time }
    }

    private var effectiveBlocksForPreviewTime: [NutritionBlock] {
        allEnabledBlocks.filter { $0.time <= previewNow }
    }

    private var scenario: AggregatedScenario {
        let carbsToday = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.carbs) }
        let sugarToday = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.sugar) }
        let proteinToday = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.protein) }
        let fatToday = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.fat) }
        let nutritionEnergyTodayKcal = effectiveBlocksForPreviewTime.reduce(0) { $0 + max(0, $1.nutritionEnergyKcal) }

        let carbsMorningGrams = effectiveBlocksForPreviewTime
            .filter { Self.daypart(for: $0.time) == .morning }
            .reduce(0) { $0 + max(0, $1.carbs) }

        let carbsAfternoonGrams = effectiveBlocksForPreviewTime
            .filter { Self.daypart(for: $0.time) == .afternoon }
            .reduce(0) { $0 + max(0, $1.carbs) }

        let carbsNightGrams = effectiveBlocksForPreviewTime
            .filter { Self.daypart(for: $0.time) == .night }
            .reduce(0) { $0 + max(0, $1.carbs) }

        return AggregatedScenario(
            carbsToday: carbsToday,
            sugarToday: sugarToday,
            proteinToday: proteinToday,
            fatToday: fatToday,
            nutritionEnergyTodayKcal: nutritionEnergyTodayKcal,
            carbsMorningGrams: carbsMorningGrams,
            carbsAfternoonGrams: carbsAfternoonGrams,
            carbsNightGrams: carbsNightGrams
        )
    }

    private var engineInput: NutritionInsightEngineV1.Input { // 🟨 UPDATED
        NutritionInsightEngineV1.Input(
            now: previewNow,
            calendar: .current,
            isToday: true,
            carbsGrams: scenario.carbsToday,
            sugarGrams: scenario.sugarToday,
            proteinGrams: scenario.proteinToday,
            fatGrams: scenario.fatToday,
            targetCarbsGrams: carbsTarget,
            targetSugarGrams: sugarTarget,
            targetProteinGrams: proteinTarget,
            targetFatGrams: fatTarget,
            targetCalories: caloriesTarget,
            nutritionEnergyKcal: scenario.nutritionEnergyTodayKcal,
            activeEnergyKcal: activeEnergyTodayKcal,
            restingEnergyKcal: restingEnergyTodayKcal,
            carbsMorningGrams: scenario.carbsMorningGrams,
            carbsAfternoonGrams: scenario.carbsAfternoonGrams,
            carbsNightGrams: scenario.carbsNightGrams,
            isDataAccessBlocked: isDataAccessBlocked
        )
    }

    private var insightOutput: NutritionInsightEngineV1.Output {
        NutritionInsightEngineV1().evaluate(engineInput)
    }

    private var engineSignals: NITClassifiedSignalsV1 { // 🟨 UPDATED
        NutritionInsightEngineClassifierV1.classify(from: engineInput)
    }

    private var engineDecision: NITResolvedDecisionV1 { // 🟨 UPDATED
        NutritionInsightEngineResolverV1.resolve(from: engineSignals)
    }

    private var engineDebugSnapshot: EngineDebugSnapshot {
        let carbsRatio = carbsTarget > 0
            ? Double(scenario.carbsToday) / Double(carbsTarget)
            : nil

        let proteinRatio = proteinTarget > 0
            ? Double(scenario.proteinToday) / Double(proteinTarget)
            : nil

        let fatRatio = fatTarget > 0
            ? Double(scenario.fatToday) / Double(fatTarget)
            : nil

        let caloriesRatio = caloriesTarget > 0
            ? Double(scenario.nutritionEnergyTodayKcal) / Double(caloriesTarget)
            : nil

        let burned = activeEnergyTodayKcal + restingEnergyTodayKcal
        let balanceRatio = burned > 0
            ? Double(scenario.nutritionEnergyTodayKcal) / Double(burned)
            : nil

        return EngineDebugSnapshot(
            windowStage: engineDecision.windowStage.rawValue,
            isPracticalDayClose: engineDecision.isPracticalDayClose,
            availability: engineDecision.availabilityState.rawValue,
            carbsStatus: engineDecision.carbsStatus.rawValue,
            proteinStatus: engineDecision.proteinStatus.rawValue,
            fatStatus: engineDecision.fatStatus.rawValue,
            caloriesStatus: engineDecision.caloriesStatus.rawValue,
            energyStatus: engineDecision.energyStatus.rawValue,
            carbsProgressState: engineDecision.carbsProgressState.rawValue,
            proteinProgressState: engineDecision.proteinProgressState.rawValue,
            fatProgressState: engineDecision.fatProgressState.rawValue,
            caloriesProgressState: engineDecision.caloriesProgressState.rawValue,
            macroStructureStatus: engineDecision.macroStructureStatus.rawValue,
            carbSplitStatus: engineDecision.carbSplitStatus.rawValue,
            combinedBias: engineDecision.combinedBias.rawValue,
            mainCriteriaAlignment: engineDecision.mainCriteriaAlignment.rawValue,
            achievementState: engineDecision.achievementState.rawValue,
            mainTargetLeadState: engineDecision.mainTargetLeadState.rawValue,
            achievedMainTargetCount: engineDecision.achievedMainTargetCount,
            strongAchievedMainTargetCount: engineDecision.strongAchievedMainTargetCount,
            laggingMainTargetCount: engineDecision.laggingMainTargetCount,
            onTrackMainTargetCount: engineDecision.onTrackMainTargetCount,
            aheadMainTargetCount: engineDecision.aheadMainTargetCount,
            overrunMainTargetCount: engineDecision.overrunMainTargetCount,
            carbsRatio: carbsRatio,
            proteinRatio: proteinRatio,
            fatRatio: fatRatio,
            caloriesRatio: caloriesRatio,
            balanceRatio: balanceRatio,
            currentEnergyDeltaKcal: scenario.nutritionEnergyTodayKcal - burned
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

    private func isBlockInPastOrPresent(_ block: NutritionBlock) -> Bool {
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

                CompactNutritionBlockEditor(
                    block: $block1,
                    isEffectiveForPreview: isBlockInPastOrPresent(block1)
                )

                CompactNutritionBlockEditor(
                    block: $block2,
                    isEffectiveForPreview: isBlockInPastOrPresent(block2)
                )

                CompactNutritionBlockEditor(
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
                    Color.Glu.nutritionDomain.opacity(0.16)
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

private extension NutritionInsightEnginePreviewTool {

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
                title: "Active Energy",
                valueText: "\(activeEnergyTodayKcal) kcal",
                value: $activeEnergyTodayKcal,
                step: 50,
                range: 0...2500
            )

            compactStepperRow(
                title: "Resting Energy",
                valueText: "\(restingEnergyTodayKcal) kcal",
                value: $restingEnergyTodayKcal,
                step: 50,
                range: 0...3000
            )

            HStack(spacing: 6) {
                Text("Data Blocked")
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer(minLength: 6)

                Toggle("", isOn: $isDataAccessBlocked)
                    .labelsHidden()
                    .scaleEffect(0.72)
            }
        }
        .padding(8)
        .compactCard()
    }

    var computedMetricsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Computed Engine Input")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            compactMetricRow("Carbs Today", "\(scenario.carbsToday) g (\(carbsTarget) g)")
            compactMetricRow("Sugar Today", "\(scenario.sugarToday) g (\(sugarTarget) g)")
            compactMetricRow("Protein Today", "\(scenario.proteinToday) g (\(proteinTarget) g)")
            compactMetricRow("Fat Today", "\(scenario.fatToday) g (\(fatTarget) g)")
            compactMetricRow("Energy Today", "\(scenario.nutritionEnergyTodayKcal) kcal (\(caloriesTarget) kcal)")
            compactMetricRow("KH Morning", "\(scenario.carbsMorningGrams) g")
            compactMetricRow("KH Afternoon", "\(scenario.carbsAfternoonGrams) g")
            compactMetricRow("KH Night", "\(scenario.carbsNightGrams) g")
            compactMetricRow("Counted Blocks", "\(effectiveBlocksForPreviewTime.count) / \(allEnabledBlocks.count)")
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

            if let secondaryText = insightOutput.secondaryText, !secondaryText.isEmpty {
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }

            Divider()
                .padding(.top, 2)

            compactMetricRow("Category", insightOutput.category.rawValue)
            compactMetricRow("Score", "\(insightOutput.score)")
        }
        .padding(8)
        .compactCard()
    }

    var debugSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Engine Debug")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            compactMetricRow("Output Class", engineDecision.outputClass.rawValue) // 🟨 UPDATED
            compactMetricRow("Confidence", engineDecision.confidence.rawValue)
            compactMetricRow("Window Stage", engineDebugSnapshot.windowStage)
            compactMetricRow("Practical Day Close", formatBool(engineDebugSnapshot.isPracticalDayClose))
            compactMetricRow("Availability", engineDebugSnapshot.availability)
            compactMetricRow("Carbs Status", engineDebugSnapshot.carbsStatus)
            compactMetricRow("Protein Status", engineDebugSnapshot.proteinStatus)
            compactMetricRow("Fat Status", engineDebugSnapshot.fatStatus)
            compactMetricRow("Calories Status", engineDebugSnapshot.caloriesStatus)
            compactMetricRow("Energy Status", engineDebugSnapshot.energyStatus)
            compactMetricRow("Carbs Progress", engineDebugSnapshot.carbsProgressState)
            compactMetricRow("Protein Progress", engineDebugSnapshot.proteinProgressState)
            compactMetricRow("Fat Progress", engineDebugSnapshot.fatProgressState)
            compactMetricRow("Calories Progress", engineDebugSnapshot.caloriesProgressState)
            compactMetricRow("Macro Structure", engineDebugSnapshot.macroStructureStatus)
            compactMetricRow("KH Split", engineDebugSnapshot.carbSplitStatus)
            compactMetricRow("Main Criteria", engineDebugSnapshot.mainCriteriaAlignment)
            compactMetricRow("Combined Primary", engineDecision.combinedPrimary.rawValue)
            compactMetricRow("Combined Bias", engineDebugSnapshot.combinedBias)
            compactMetricRow("Achievement", engineDebugSnapshot.achievementState)
            compactMetricRow("Lead State", engineDebugSnapshot.mainTargetLeadState)
            compactMetricRow("Open Day State", engineDecision.openDayProgressState?.rawValue ?? "–")
            compactMetricRow("Closed Day State", engineDecision.closedDayEvaluationState?.rawValue ?? "–")
            compactMetricRow("Suppression", engineDecision.suppressionReason?.rawValue ?? "–")
            compactMetricRow("Achieved Count", "\(engineDebugSnapshot.achievedMainTargetCount)")
            compactMetricRow("Strong Achieved Count", "\(engineDebugSnapshot.strongAchievedMainTargetCount)")
            compactMetricRow("Lagging Count", "\(engineDebugSnapshot.laggingMainTargetCount)")
            compactMetricRow("On Track Count", "\(engineDebugSnapshot.onTrackMainTargetCount)")
            compactMetricRow("Ahead Count", "\(engineDebugSnapshot.aheadMainTargetCount)")
            compactMetricRow("Overrun Count", "\(engineDebugSnapshot.overrunMainTargetCount)")
            compactMetricRow("Carbs Ratio", formatRatio(engineDebugSnapshot.carbsRatio))
            compactMetricRow("Protein Ratio", formatRatio(engineDebugSnapshot.proteinRatio))
            compactMetricRow("Fat Ratio", formatRatio(engineDebugSnapshot.fatRatio))
            compactMetricRow("Calories Ratio", formatRatio(engineDebugSnapshot.caloriesRatio))
            compactMetricRow("Energy Balance Ratio", formatRatio(engineDebugSnapshot.balanceRatio))
            compactMetricRow("Energy Delta", formatSignedKcal(engineDebugSnapshot.currentEnergyDeltaKcal))
            compactMetricRow("Day Progress", formatPercent(dayProgressFraction))
            compactMetricRow("Applied Rules", engineDecision.appliedRules.map(\.rawValue).joined(separator: ", "))
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
// MARK: - Compact Nutrition Block Editor
// ============================================================

private struct CompactNutritionBlockEditor: View {

    @Binding var block: NutritionInsightEnginePreviewTool.NutritionBlock
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
                title: "Carbs",
                valueText: "\(block.carbs) g",
                value: $block.carbs,
                step: 20,
                range: 0...300
            )

            compactStepperRow(
                title: "Sugar",
                valueText: "\(block.sugar) g",
                value: $block.sugar,
                step: 20,
                range: 0...150
            )

            compactStepperRow(
                title: "Protein",
                valueText: "\(block.protein) g",
                value: $block.protein,
                step: 20,
                range: 0...200
            )

            compactStepperRow(
                title: "Fat",
                valueText: "\(block.fat) g",
                value: $block.fat,
                step: 20,
                range: 0...150
            )

            compactStepperRow(
                title: "Energy",
                valueText: "\(block.nutritionEnergyKcal) kcal",
                value: $block.nutritionEnergyKcal,
                step: 50,
                range: 0...2000
            )
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
                    .stroke(Color.Glu.nutritionDomain.opacity(0.55), lineWidth: 1.1)
            )
    }
}

// ============================================================
// MARK: - Formatting Helpers
// ============================================================

private extension NutritionInsightEnginePreviewTool {

    func formatPercent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.0f%%", value * 100.0)
    }

    func formatRatio(_ value: Double?) -> String {
        guard let value else { return "–" }
        return String(format: "%.2f", value)
    }

    func formatSignedKcal(_ value: Int) -> String {
        if value > 0 { return "+\(value) kcal" }
        if value < 0 { return "−\(abs(value)) kcal" }
        return "0 kcal"
    }

    static func makeTodayTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }

    static func daypart(for date: Date) -> CarbsDaypartV1 {
        let hour = Calendar.current.component(.hour, from: date)

        if hour >= 6 && hour <= 11 { return .morning }
        if hour >= 12 && hour <= 17 { return .afternoon }
        return .night
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Nutrition Insight Tool") {
    NutritionInsightEnginePreviewTool()
        .environmentObject(EntitlementManager.shared)
}
