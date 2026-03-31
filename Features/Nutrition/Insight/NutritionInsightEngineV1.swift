//
//  NutritionInsightEngine.swift
//  GluVibProbe
//
//  Domain: Nutrition / Overview Insight
//
//  Purpose
//  - Public output engine for the Nutrition insight card.
//  - TODAY ONLY.
//  - Uses Nutrition targets, intake, energy balance and optional KH split context.
//  - Converts resolved Nutrition decisions into UI-ready text and presentation values.
//
//  Important
//  - No HealthKit access
//  - No UI fetching logic
//  - Internal logic is routed through:
//    - NutritionInsightEngineModelsV1
//    - NutritionInsightEngineClassifierV1
//    - NutritionInsightEngineResolverV1
//

import Foundation
import SwiftUI

// ============================================================
// MARK: - Public Models
// ============================================================

enum NutritionInsightCategory: String {
    case neutral
    case target
    case energy
}

// ============================================================
// MARK: - Public Engine
// ============================================================

struct NutritionInsightEngineV1 {

    struct Input {
        let now: Date
        let calendar: Calendar
        let isToday: Bool

        let carbsGrams: Int
        let sugarGrams: Int
        let proteinGrams: Int
        let fatGrams: Int

        let targetCarbsGrams: Int
        let targetSugarGrams: Int
        let targetProteinGrams: Int
        let targetFatGrams: Int
        let targetCalories: Int

        let nutritionEnergyKcal: Int
        let activeEnergyKcal: Int
        let restingEnergyKcal: Int

        let carbsMorningGrams: Int
        let carbsAfternoonGrams: Int
        let carbsNightGrams: Int

        let isDataAccessBlocked: Bool

        init(
            now: Date = Date(),
            calendar: Calendar = .current,
            isToday: Bool,
            carbsGrams: Int,
            sugarGrams: Int = 0,
            proteinGrams: Int,
            fatGrams: Int,
            targetCarbsGrams: Int,
            targetSugarGrams: Int = 0,
            targetProteinGrams: Int,
            targetFatGrams: Int,
            targetCalories: Int = 0,
            nutritionEnergyKcal: Int,
            activeEnergyKcal: Int,
            restingEnergyKcal: Int,
            carbsMorningGrams: Int = 0,
            carbsAfternoonGrams: Int = 0,
            carbsNightGrams: Int = 0,
            isDataAccessBlocked: Bool = false
        ) {
            self.now = now
            self.calendar = calendar
            self.isToday = isToday

            self.carbsGrams = carbsGrams
            self.sugarGrams = sugarGrams
            self.proteinGrams = proteinGrams
            self.fatGrams = fatGrams

            self.targetCarbsGrams = targetCarbsGrams
            self.targetSugarGrams = targetSugarGrams
            self.targetProteinGrams = targetProteinGrams
            self.targetFatGrams = targetFatGrams
            self.targetCalories = targetCalories

            self.nutritionEnergyKcal = nutritionEnergyKcal
            self.activeEnergyKcal = activeEnergyKcal
            self.restingEnergyKcal = restingEnergyKcal

            self.carbsMorningGrams = carbsMorningGrams
            self.carbsAfternoonGrams = carbsAfternoonGrams
            self.carbsNightGrams = carbsNightGrams

            self.isDataAccessBlocked = isDataAccessBlocked
        }
    }

    struct Output {
        let primaryText: String
        let secondaryText: String?
        let category: NutritionInsightCategory
        let score: Int
        let scoreColor: Color

        let carbsGoalPercent: Int
        let sugarGoalPercent: Int
        let proteinGoalPercent: Int
        let fatGoalPercent: Int

        let carbsShare: Double
        let proteinShare: Double
        let fatShare: Double

        let isEnergyRemaining: Bool
        let energyProgress: Double
        let formattedEnergyBalanceValue: String
        let energyBalanceLabelText: String
    }

    func evaluate(_ input: Input) -> Output {
        let signals = NutritionInsightEngineClassifierV1.classify(from: input)
        let decision = NutritionInsightEngineResolverV1.resolve(from: signals)

        let shares = resolveMacroShares(
            carbs: input.carbsGrams,
            protein: input.proteinGrams,
            fat: input.fatGrams
        )

        let energyPresentation = resolveEnergyPresentation(
            intakeKcal: input.nutritionEnergyKcal,
            activeKcal: input.activeEnergyKcal,
            restingKcal: input.restingEnergyKcal
        )

        return Output(
            primaryText: resolvePrimaryText(from: signals, decision: decision, isToday: input.isToday),
            secondaryText: resolveSecondaryText(from: signals, decision: decision, isToday: input.isToday),
            category: mapCategory(from: decision.outputClass),
            score: resolveScore(from: decision.outputClass),
            scoreColor: resolveScoreColor(from: decision.outputClass),

            carbsGoalPercent: percent(value: input.carbsGrams, target: input.targetCarbsGrams),
            sugarGoalPercent: percent(value: input.sugarGrams, target: input.targetSugarGrams),
            proteinGoalPercent: percent(value: input.proteinGrams, target: input.targetProteinGrams),
            fatGoalPercent: percent(value: input.fatGrams, target: input.targetFatGrams),

            carbsShare: shares.carbs,
            proteinShare: shares.protein,
            fatShare: shares.fat,

            isEnergyRemaining: energyPresentation.isRemaining,
            energyProgress: energyPresentation.progress,
            formattedEnergyBalanceValue: energyPresentation.balanceValue,
            energyBalanceLabelText: energyPresentation.balanceLabel
        )
    }
}

// ============================================================
// MARK: - Output Mapping
// ============================================================

private extension NutritionInsightEngineV1 {

    func mapCategory(from outputClass: NITOutputClassV1) -> NutritionInsightCategory {
        switch outputClass {
        case .overTargetDay:
            return .energy

        case .balancedProgress,
             .mixedProgress,
             .leadProgress,
             .laggingProgress,
             .targetBalancedDay,
             .targetMostlyMet,
             .unevenDay,
             .underTargetDay:
            return .target

        case .blocked,
             .noData,
             .insufficientData,
             .midZone:
            return .neutral
        }
    }

    func resolvePrimaryText(
        from signals: NITClassifiedSignalsV1,
        decision: NITResolvedDecisionV1,
        isToday: Bool
    ) -> String {
        guard isToday else { return "" }

        if shouldShowNoNutritionLoggedText(from: signals, decision: decision) {
            return noNutritionLoggedText(for: decision.windowStage)
        }

        switch decision.outputClass {
        case .blocked:
            return "Nutrition data is currently unavailable."

        case .noData:
            return noNutritionLoggedText(for: decision.windowStage)

        case .insufficientData:
            return "There is not enough nutrition data yet for a stable interpretation."

        case .balancedProgress:
            return resolveBalancedProgressPrimaryText(from: decision)

        case .mixedProgress:
            return resolveMixedProgressPrimaryText(from: decision)

        case .leadProgress:
            return resolveLeadProgressPrimaryText(from: decision)

        case .laggingProgress:
            return resolveLaggingProgressPrimaryText(from: decision)

        case .midZone:
            return resolveMidZonePrimaryText(from: decision)

        case .targetBalancedDay:
            return resolveTargetBalancedDayPrimaryText(from: decision)

        case .targetMostlyMet:
            return resolveTargetMostlyMetPrimaryText(from: decision)

        case .unevenDay:
            return resolveUnevenDayPrimaryText(from: decision)

        case .overTargetDay:
            return resolveOverTargetDayPrimaryText(from: decision)

        case .underTargetDay:
            return resolveUnderTargetDayPrimaryText(from: decision)
        }
    }

    func resolveSecondaryText(
        from signals: NITClassifiedSignalsV1,
        decision: NITResolvedDecisionV1,
        isToday: Bool
    ) -> String? {
        guard isToday else { return nil }
        guard decision.availabilityState == .ready else { return nil }
        guard !shouldShowNoNutritionLoggedText(from: signals, decision: decision) else { return nil }
        return resolveCarbSplitSecondaryText(from: signals, decision: decision)
    }
}

// ============================================================
// MARK: - Early No-Intake Gate
// ============================================================

private extension NutritionInsightEngineV1 {

    func shouldShowNoNutritionLoggedText(
        from signals: NITClassifiedSignalsV1,
        decision: NITResolvedDecisionV1
    ) -> Bool {
        guard decision.availabilityState != .blocked else { return false }

        let hasAnyNutritionIntake =
            signals.carbsPrepared.todayValue > 0 ||
            signals.proteinPrepared.todayValue > 0 ||
            signals.fatPrepared.todayValue > 0 ||
            signals.caloriesPrepared.todayValue > 0

        return !hasAnyNutritionIntake
    }

    func noNutritionLoggedText(for stage: NITWindowStageV1) -> String {
        switch stage {
        case .dayClosed:
            return "No nutrition data was logged today."
        case .morning, .afternoon, .evening:
            return "No nutrition data has been logged today yet."
        }
    }
}

// ============================================================
// MARK: - Secondary Text / Carb Split
// ============================================================

private extension NutritionInsightEngineV1 {

    func resolveCarbSplitSecondaryText(
        from signals: NITClassifiedSignalsV1,
        decision: NITResolvedDecisionV1
    ) -> String? {
        guard signals.carbSplitPrepared.completedWindowsCount > 0 else { return nil }
        guard signals.carbSplitPrepared.isAssessable else { return nil }

        switch decision.windowStage {
        case .morning:
            return nil

        case .afternoon:
            return resolveSingleCompletedBlockContext(
                title: "Morning",
                grams: signals.carbSplitPrepared.morningGrams,
                targetShare: signals.carbSplitPrepared.morningTargetShare,
                isDayClosed: false
            )

        case .evening:
            if let afternoonContext = resolveSingleCompletedBlockContext(
                title: "Afternoon",
                grams: signals.carbSplitPrepared.afternoonGrams,
                targetShare: signals.carbSplitPrepared.afternoonTargetShare,
                isDayClosed: false
            ) {
                return afternoonContext
            }

            return resolveSingleCompletedBlockContext(
                title: "Morning",
                grams: signals.carbSplitPrepared.morningGrams,
                targetShare: signals.carbSplitPrepared.morningTargetShare,
                isDayClosed: false
            )

        case .dayClosed:
            return resolveDominantClosedDayBlockContext(from: signals.carbSplitPrepared)
        }
    }

    func resolveSingleCompletedBlockContext(
        title: String,
        grams: Double,
        targetShare: Double,
        isDayClosed: Bool
    ) -> String? {
        guard grams > 0 else { return nil }

        let percentValue = Int((targetShare * 100.0).rounded())
        guard percentValue > 0 else { return nil }

        if isDayClosed {
            switch percentValue {
            case 45...:
                return "\(title) accounted for a large share of your carb target today (\(percentValue)%)."
            case 25...44:
                return "\(title) contributed a notable share of your carb target today (\(percentValue)%)."
            default:
                return "\(title) contributed \(percentValue)% of your carb target today."
            }
        }

        switch percentValue {
        case 45...:
            return "\(title) accounted for a large share of your carb target so far (\(percentValue)%)."
        case 25...44:
            return "\(title) contributed a notable share of your carb target so far (\(percentValue)%)."
        default:
            return "\(title) contributed \(percentValue)% of your carb target so far."
        }
    }

    func resolveDominantClosedDayBlockContext(from prepared: NITPreparedCarbSplitMetricV1) -> String? {
        let blockContexts: [(title: String, grams: Double, targetShare: Double)] = [
            ("Morning", prepared.morningGrams, prepared.morningTargetShare),
            ("Afternoon", prepared.afternoonGrams, prepared.afternoonTargetShare),
            ("Night", prepared.nightGrams, prepared.nightTargetShare)
        ]

        guard let dominant = blockContexts
            .filter({ $0.grams > 0 && $0.targetShare > 0 })
            .max(by: { $0.targetShare < $1.targetShare }) else {
            return nil
        }

        let percentValue = Int((dominant.targetShare * 100.0).rounded())
        guard percentValue >= 25 else { return nil }

        return "\(dominant.title) contributed the largest share of your carb target today (\(percentValue)%)."
    }
}

// ============================================================
// MARK: - Primary Text
// ============================================================

private extension NutritionInsightEngineV1 {

    func resolveBalancedProgressPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let coveredText = humanReadableTargetKinds(decision.targetSummary.covered)
        let aboveText = humanReadableTargetKinds(decision.targetSummary.aboveTarget)

        if !aboveText.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(aboveText.capitalized) are already beyond target this morning."
            case .afternoon:
                return "\(aboveText.capitalized) are already beyond target so far today."
            case .evening:
                return "\(aboveText.capitalized) are already beyond target today."
            case .dayClosed:
                return "\(aboveText.capitalized) ended above target today."
            }
        }

        if !coveredText.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(coveredText.capitalized) are already covered this morning, while the overall picture still looks balanced."
            case .afternoon:
                return "\(coveredText.capitalized) are already covered so far today, while the overall picture still looks balanced."
            case .evening:
                return "\(coveredText.capitalized) are already covered today, while the overall picture still looks balanced."
            case .dayClosed:
                return "\(coveredText.capitalized) ended the day covered, with an overall balanced picture."
            }
        }

        switch decision.windowStage {
        case .morning:
            return "Your main nutrition targets look balanced so far this morning."
        case .afternoon:
            return "Your main nutrition targets look balanced so far today."
        case .evening:
            return "Your main nutrition targets still look balanced so far today."
        case .dayClosed:
            return "Your main nutrition targets looked balanced by the end of the day."
        }
    }

    func resolveMixedProgressPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let aboveText = humanReadableTargetKinds(decision.targetSummary.aboveTarget)
        let coveredText = humanReadableTargetKinds(decision.targetSummary.covered)
        let belowText = humanReadableTargetKinds(decision.targetSummary.belowTarget)
        let leadLabel = leadLabel(from: decision.mainTargetLeadState) // 🟨 UPDATED
        let capitalizedLead = leadLabel?.capitalized ?? "One main target" // 🟨 UPDATED

        if !aboveText.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(aboveText.capitalized) are already beyond target this morning, while the rest of the picture is still mixed."
            case .afternoon:
                return "\(aboveText.capitalized) are already beyond target so far today, while the rest of the picture is still mixed."
            case .evening:
                return "\(aboveText.capitalized) are already beyond target today, while the rest of the picture is still mixed."
            case .dayClosed:
                return "\(aboveText.capitalized) ended above target, while the rest of the picture stayed mixed."
            }
        }

        if leadLabel != nil && !belowText.isEmpty { // 🟨 UPDATED
            switch decision.windowStage { // 🟨 UPDATED
            case .morning: // 🟨 UPDATED
                return "\(capitalizedLead) is already building clearly this morning, while \(belowText) are still behind." // 🟨 UPDATED
            case .afternoon: // 🟨 UPDATED
                return "\(capitalizedLead) is already giving the day some forward progress, while \(belowText) are still behind." // 🟨 UPDATED
            case .evening: // 🟨 UPDATED
                return "\(capitalizedLead) remains clearly ahead, while \(belowText) are still behind today." // 🟨 UPDATED
            case .dayClosed: // 🟨 UPDATED
                return "\(capitalizedLead) ended the day ahead, while \(belowText) remained below target." // 🟨 UPDATED
            }
        }

        if !coveredText.isEmpty && !belowText.isEmpty { // 🟨 UPDATED
            switch decision.windowStage { // 🟨 UPDATED
            case .morning: // 🟨 UPDATED
                return "\(coveredText.capitalized) are already covered this morning, while \(belowText) are still behind." // 🟨 UPDATED
            case .afternoon: // 🟨 UPDATED
                return "\(coveredText.capitalized) are already covered so far today, while \(belowText) are still behind." // 🟨 UPDATED
            case .evening: // 🟨 UPDATED
                return "\(coveredText.capitalized) are already covered today, while \(belowText) are still behind." // 🟨 UPDATED
            case .dayClosed: // 🟨 UPDATED
                return "\(coveredText.capitalized) ended the day covered, while \(belowText) remained below target." // 🟨 UPDATED
            }
        }

        if !coveredText.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(coveredText.capitalized) are already covered this morning, while the overall picture is still mixed."
            case .afternoon:
                return "\(coveredText.capitalized) are already covered so far today, while the overall picture is still mixed."
            case .evening:
                return "\(coveredText.capitalized) are already covered today, while the overall picture remains mixed."
            case .dayClosed:
                return "\(coveredText.capitalized) ended the day covered, while the overall picture stayed mixed."
            }
        }

        switch decision.windowStage {
        case .morning:
            return "Your nutrition progress is mixed so far this morning."
        case .afternoon:
            return "Your nutrition progress is mixed so far today."
        case .evening:
            return "Your nutrition progress remains mixed so far today."
        case .dayClosed:
            return "Your nutrition progress was mixed by the end of the day."
        }
    }

    func resolveLeadProgressPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let leadLabel = leadLabel(from: decision.mainTargetLeadState)
        let capitalizedLead = leadLabel?.capitalized ?? "One main target"

        if !decision.targetSummary.aboveTarget.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(capitalizedLead) is already beyond target this morning."
            case .afternoon:
                return "\(capitalizedLead) is already beyond target so far today."
            case .evening:
                return "\(capitalizedLead) is already beyond target today."
            case .dayClosed:
                return "\(capitalizedLead) ended above target today."
            }
        }

        if !decision.targetSummary.covered.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(capitalizedLead) is already covered this morning and is ahead of your other main targets."
            case .afternoon:
                return "\(capitalizedLead) is already covered so far today and is ahead of your other main targets."
            case .evening:
                return "\(capitalizedLead) is already covered today and remains ahead of your other main targets."
            case .dayClosed:
                return "\(capitalizedLead) ended the day covered and ahead of your other main targets."
            }
        }

        switch decision.windowStage {
        case .morning:
            return "\(capitalizedLead) is currently ahead of your other main targets this morning."
        case .afternoon:
            return "\(capitalizedLead) is currently ahead of your other main targets so far today."
        case .evening:
            return "\(capitalizedLead) remains ahead of your other main targets today."
        case .dayClosed:
            return "\(capitalizedLead) ended the day ahead of your other main targets."
        }
    }

    func resolveLaggingProgressPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let belowText = humanReadableTargetKinds(decision.targetSummary.belowTarget)

        if !belowText.isEmpty {
            switch decision.windowStage {
            case .morning:
                return "\(belowText.capitalized) are still behind this morning."
            case .afternoon:
                return "\(belowText.capitalized) are still behind so far today."
            case .evening:
                return "\(belowText.capitalized) are still behind today."
            case .dayClosed:
                return "\(belowText.capitalized) stayed below target by the end of the day."
            }
        }

        switch decision.windowStage {
        case .morning:
            return "Your main nutrition targets are still building slowly this morning."
        case .afternoon:
            return "Several main nutrition targets are still behind so far today."
        case .evening:
            return "Several main nutrition targets are still behind today."
        case .dayClosed:
            return "Several main nutrition targets stayed below target by the end of the day."
        }
    }

    func resolveMidZonePrimaryText(from decision: NITResolvedDecisionV1) -> String {
        switch decision.windowStage {
        case .morning:
            return "Your nutrition picture is still fairly open this morning."
        case .afternoon:
            return "Your nutrition picture is still fairly open today."
        case .evening:
            return "Your nutrition picture is still in a neutral range today."
        case .dayClosed:
            return "Your nutrition picture stayed in a neutral range by the end of the day."
        }
    }

    func resolveTargetBalancedDayPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let coveredText = humanReadableTargetKinds(decision.targetSummary.covered)

        if !coveredText.isEmpty {
            switch decision.energyNarrative {
            case .nearBalance:
                if decision.windowStage == .dayClosed {
                    return "\(coveredText.capitalized) ended the day covered, and energy intake stayed close to your total burn."
                }
                return "\(coveredText.capitalized) are covered, and energy intake is currently close to your total burn."

            default:
                if decision.windowStage == .dayClosed {
                    return "\(coveredText.capitalized) ended the day in a balanced target range."
                }
                return "\(coveredText.capitalized) are currently in a balanced target range."
            }
        }

        switch decision.energyNarrative {
        case .nearBalance:
            if decision.windowStage == .dayClosed {
                return "Your main nutrition targets ended the day in a balanced target range, and energy intake stayed close to your total burn."
            }
            return "Your main nutrition targets are currently in a balanced target range, and energy intake is close to your total burn."

        default:
            if decision.windowStage == .dayClosed {
                return "Your main nutrition targets ended the day in a balanced target range."
            }
            return "Your main nutrition targets are currently in a balanced target range."
        }
    }

    func resolveTargetMostlyMetPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let coveredText = humanReadableTargetKinds(decision.targetSummary.covered)
        let belowText = humanReadableTargetKinds(decision.targetSummary.belowTarget)
        let energyText = closedDayEnergySentence(from: decision)

        if decision.windowStage == .dayClosed {
            if !coveredText.isEmpty && !belowText.isEmpty {
                return "\(coveredText.capitalized) ended the day covered, while \(belowText) remained below target\(energyText)."
            }

            if !coveredText.isEmpty {
                return "\(coveredText.capitalized) ended the day covered\(energyText)."
            }

            return "Most of your main nutrition targets were covered by the end of the day\(energyText)."
        }

        if !coveredText.isEmpty && !belowText.isEmpty {
            return "\(coveredText.capitalized) are already covered, while \(belowText) are still below target\(energyText)."
        }

        if !coveredText.isEmpty {
            return "\(coveredText.capitalized) are already covered\(energyText)."
        }

        return "Most of your main nutrition targets are already covered so far today\(energyText)."
    }

    func resolveUnevenDayPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let aboveText = humanReadableTargetKinds(decision.targetSummary.aboveTarget)
        let belowText = humanReadableTargetKinds(decision.targetSummary.belowTarget)
        let energyText = closedDayEnergySentence(from: decision)

        if decision.windowStage == .dayClosed {
            if !aboveText.isEmpty && !belowText.isEmpty {
                return "\(aboveText.capitalized) ended above target, while \(belowText) remained below target\(energyText)."
            }

            if !aboveText.isEmpty {
                return "\(aboveText.capitalized) ended too far ahead of your other main targets\(energyText)."
            }

            if decision.macroStructureStatus == .imbalanced {
                return "Your main nutrition targets ended the day uneven, with a clearly imbalanced overall intake structure\(energyText)."
            }

            return "Your main nutrition targets ended the day uneven overall\(energyText)."
        }

        if !aboveText.isEmpty && !belowText.isEmpty {
            return "\(aboveText.capitalized) are already above target, while \(belowText) are still below target\(energyText)."
        }

        if !aboveText.isEmpty {
            return "\(aboveText.capitalized) are already too far ahead of your other main targets\(energyText)."
        }

        if decision.macroStructureStatus == .imbalanced {
            return "Your main nutrition targets are currently uneven, with a clearly imbalanced overall intake structure\(energyText)."
        }

        return "Your main nutrition targets are currently uneven overall\(energyText)."
    }

    func resolveOverTargetDayPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let aboveText = humanReadableTargetKinds(decision.targetSummary.aboveTarget)
        let belowText = humanReadableTargetKinds(decision.targetSummary.belowTarget)
        let coveredText = humanReadableTargetKinds(
            decision.targetSummary.covered.filter { !decision.targetSummary.aboveTarget.contains($0) }
        )

        var parts: [String] = []

        if decision.windowStage == .dayClosed {
            if !aboveText.isEmpty {
                parts.append("\(aboveText.capitalized) ended above target")
            }

            if !belowText.isEmpty {
                parts.append("\(belowText) remained below target")
            } else if !coveredText.isEmpty && aboveText.isEmpty {
                parts.append("\(coveredText.capitalized) ended the day covered")
            }
        } else {
            if !aboveText.isEmpty {
                parts.append("\(aboveText.capitalized) are already above target")
            }

            if !belowText.isEmpty {
                parts.append("\(belowText) are still below target")
            } else if !coveredText.isEmpty && aboveText.isEmpty {
                parts.append("\(coveredText.capitalized) are already covered")
            }
        }

        switch decision.energyNarrative {
        case .intakeAboveTotalBurn:
            parts.append(
                decision.windowStage == .dayClosed
                    ? "energy intake also ended above your total burn"
                    : "energy intake is already above your total burn"
            )
        case .nearBalance, .intakeBelowTotalBurn, .none:
            break
        }

        if !parts.isEmpty {
            return joinSentenceParts(parts) + "."
        }

        return decision.windowStage == .dayClosed
            ? "Energy intake ended above your total burn."
            : "Energy intake is already above your total burn."
    }

    func resolveUnderTargetDayPrimaryText(from decision: NITResolvedDecisionV1) -> String {
        let belowText = humanReadableTargetKinds(decision.targetSummary.belowTarget)

        if !belowText.isEmpty {
            return decision.windowStage == .dayClosed
                ? "\(belowText.capitalized) stayed below target by the end of the day."
                : "\(belowText.capitalized) are still below target so far today."
        }

        return decision.windowStage == .dayClosed
            ? "Several of your main nutrition targets stayed clearly below target by the end of the day."
            : "Several of your main nutrition targets are still clearly below target so far today."
    }
}

// ============================================================
// MARK: - Text Helpers
// ============================================================

private extension NutritionInsightEngineV1 {

    func leadLabel(from state: NITMainTargetLeadStateV1) -> String? {
        switch state {
        case .carbsLeading:
            return "carbs"
        case .proteinLeading:
            return "protein"
        case .fatLeading:
            return "fat"
        case .caloriesLeading:
            return "calories"
        case .none, .mixedLead:
            return nil
        }
    }

    func humanReadableTargetKinds(_ values: [NITMainTargetKindV1]) -> String {
        humanReadableList(values.map { targetLabel(for: $0) })
    }

    func targetLabel(for kind: NITMainTargetKindV1) -> String {
        switch kind {
        case .carbs:
            return "carbs"
        case .protein:
            return "protein"
        case .fat:
            return "fat"
        case .calories:
            return "calories"
        }
    }

    func closedDayEnergySentence(from decision: NITResolvedDecisionV1) -> String {
        switch decision.energyNarrative {
        case .intakeAboveTotalBurn:
            return decision.windowStage == .dayClosed
                ? ", and energy intake ended above your total burn"
                : ", and energy intake is already above your total burn"

        case .nearBalance:
            return decision.windowStage == .dayClosed
                ? ", while energy intake stayed close to your total burn"
                : ", while energy intake is currently close to your total burn"

        case .intakeBelowTotalBurn, .none:
            return ""
        }
    }

    func joinSentenceParts(_ parts: [String]) -> String {
        switch parts.count {
        case 0:
            return ""
        case 1:
            return parts[0]
        case 2:
            return "\(parts[0]), and \(parts[1])"
        default:
            let head = parts.dropLast().joined(separator: ", ")
            let tail = parts.last ?? ""
            return "\(head), and \(tail)"
        }
    }

    func humanReadableList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            let head = values.dropLast().joined(separator: ", ")
            let tail = values.last ?? ""
            return "\(head), and \(tail)"
        }
    }
}

// ============================================================
// MARK: - Score / Category / Color
// ============================================================

private extension NutritionInsightEngineV1 {

    func resolveScore(from outputClass: NITOutputClassV1) -> Int {
        switch outputClass {
        case .blocked, .noData, .insufficientData:
            return 0

        case .targetBalancedDay:
            return 90
        case .targetMostlyMet:
            return 78

        case .balancedProgress:
            return 70
        case .mixedProgress:
            return 58
        case .leadProgress:
            return 55
        case .midZone:
            return 50
        case .laggingProgress:
            return 38
        case .unevenDay:
            return 32
        case .underTargetDay:
            return 25
        case .overTargetDay:
            return 20
        }
    }

    func resolveScoreColor(from outputClass: NITOutputClassV1) -> Color {
        switch outputClass {
        case .targetBalancedDay,
             .targetMostlyMet:
            return Color.Glu.successGreen

        case .balancedProgress:
            return Color.Glu.nutritionDomain

        case .mixedProgress,
             .leadProgress,
             .midZone:
            return .orange

        case .laggingProgress,
             .unevenDay,
             .underTargetDay,
             .overTargetDay:
            return .red

        case .blocked,
             .noData,
             .insufficientData:
            return Color.Glu.nutritionDomain
        }
    }
}

// ============================================================
// MARK: - UI Compatibility Helpers
// ============================================================

private extension NutritionInsightEngineV1 {

    func percent(value: Int, target: Int) -> Int {
        guard target > 0 else { return 0 }
        let raw = (Double(max(0, value)) / Double(target)) * 100.0
        return Int(raw.rounded())
    }

    func resolveMacroShares(
        carbs: Int,
        protein: Int,
        fat: Int
    ) -> (carbs: Double, protein: Double, fat: Double) {
        let safeCarbs = max(0, carbs)
        let safeProtein = max(0, protein)
        let safeFat = max(0, fat)

        let total = safeCarbs + safeProtein + safeFat
        guard total > 0 else {
            return (0, 0, 0)
        }

        return (
            Double(safeCarbs) / Double(total),
            Double(safeProtein) / Double(total),
            Double(safeFat) / Double(total)
        )
    }

    func resolveEnergyPresentation(
        intakeKcal: Int,
        activeKcal: Int,
        restingKcal: Int
    ) -> (isRemaining: Bool, progress: Double, balanceValue: String, balanceLabel: String) {
        let safeIntake = max(0, intakeKcal)
        let safeBurned = max(0, activeKcal) + max(0, restingKcal)

        let diff = safeBurned - safeIntake
        let isRemaining = diff >= 0

        let absDiff = abs(diff)
        let maxSide = max(safeIntake, safeBurned, 1)
        let minSide = min(safeIntake, safeBurned)
        let progress = min(max(Double(minSide) / Double(maxSide), 0), 1)

        return (
            isRemaining: isRemaining,
            progress: progress,
            balanceValue: "\(absDiff)",
            balanceLabel: isRemaining ? "kcal remaining" : "kcal over"
        )
    }
}
