//
//  NutritionInsightEngineV1.swift
//  GluVibProbe
//
//  Nutrition Overview — Insight Engine (V1)
//
//  Purpose
//  - Pure, stateless computation engine for Nutrition Overview.
//  - Derives UI-ready outputs for score, macro progress, macro shares,
//    energy balance and the current insight text.
//
//  Architecture
//  - No side effects.
//  - No HealthKit access.
//  - No fetching.
//  - Input in, derived output out.
//

import Foundation
import SwiftUI

struct NutritionInsightEngineV1 {

    // ============================================================
    // MARK: - Input / Output Models
    // ============================================================

    struct Input {
        let isToday: Bool

        let carbsGrams: Int
        let proteinGrams: Int
        let fatGrams: Int

        let targetCarbsGrams: Int
        let targetProteinGrams: Int
        let targetFatGrams: Int

        let nutritionEnergyKcal: Int
        let activeEnergyKcal: Int
        let restingEnergyKcal: Int
    }

    struct Output {
        let score: Int
        let scoreColor: Color
        let insightText: String

        let carbsGoalPercent: Int
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

    // ============================================================
    // MARK: - Public API
    // ============================================================

    func evaluate(_ input: Input) -> Output {

        // --------------------------------------------------------
        // 1) Macro goal progress
        // --------------------------------------------------------

        let carbsPct = percent(current: input.carbsGrams, target: input.targetCarbsGrams)
        let proteinPct = percent(current: input.proteinGrams, target: input.targetProteinGrams)
        let fatPct = percent(current: input.fatGrams, target: input.targetFatGrams)

        // --------------------------------------------------------
        // 2) Macro shares
        // --------------------------------------------------------

        let totalMacros = max(0, input.carbsGrams + input.proteinGrams + input.fatGrams)
        let (carbShare, protShare, fatShare) = macroShares(
            total: totalMacros,
            carbs: input.carbsGrams,
            protein: input.proteinGrams,
            fat: input.fatGrams
        )

        // --------------------------------------------------------
        // 3) Energy state
        // --------------------------------------------------------

        let totalBurned = max(0, input.activeEnergyKcal + input.restingEnergyKcal)
        let balance = totalBurned - input.nutritionEnergyKcal
        let isRemaining = balance >= 0

        let denom = max(1, totalBurned)
        let progress = clamp01(Double(input.nutritionEnergyKcal) / Double(denom))

        let balanceValue = "\(abs(balance))"
        let balanceLabel = isRemaining
            ? L10n.NutritionOverviewEnergy.remaining // 🟨 UPDATED
            : L10n.NutritionOverviewEnergy.over // 🟨 UPDATED

        // --------------------------------------------------------
        // 4) Score
        // --------------------------------------------------------

        let anyData = (totalMacros + input.nutritionEnergyKcal) > 0

        let score: Int = {
            guard anyData else { return 0 }
            let a = min(carbsPct, 100)
            let b = min(proteinPct, 100)
            let c = min(fatPct, 100)
            return Int((Double(a + b + c) / 3.0).rounded())
        }()

        let scoreColor: Color = {
            if score >= 80 { return Color.Glu.successGreen }
            if score >= 50 { return Color.Glu.nutritionDomain }
            return .orange
        }()

        // --------------------------------------------------------
        // 5) Insight text (today only)
        // --------------------------------------------------------

        let insight: String = {
            guard input.isToday else { return "" }

            guard anyData else {
                return L10n.NutritionOverviewInsight.noDataToday // 🟨 UPDATED
            }

            if carbsPct > 110 {
                return L10n.NutritionOverviewInsight.carbsAboveTarget // 🟨 UPDATED
            }

            if proteinPct < 60 && input.targetProteinGrams > 0 {
                return L10n.NutritionOverviewInsight.proteinLow // 🟨 UPDATED
            }

            if isRemaining {
                return L10n.NutritionOverviewInsight.energyRemaining // 🟨 UPDATED
            } else {
                return L10n.NutritionOverviewInsight.energyOver // 🟨 UPDATED
            }
        }()

        return Output(
            score: score,
            scoreColor: scoreColor,
            insightText: insight,
            carbsGoalPercent: carbsPct,
            proteinGoalPercent: proteinPct,
            fatGoalPercent: fatPct,
            carbsShare: carbShare,
            proteinShare: protShare,
            fatShare: fatShare,
            isEnergyRemaining: isRemaining,
            energyProgress: progress,
            formattedEnergyBalanceValue: balanceValue,
            energyBalanceLabelText: balanceLabel
        )
    }

    // ============================================================
    // MARK: - Pure Helpers
    // ============================================================

    private func percent(current: Int, target: Int) -> Int {
        guard target > 0 else { return 0 }
        let raw = (Double(max(0, current)) / Double(target)) * 100.0
        return Int(min(max(raw, 0), 999).rounded())
    }

    private func macroShares(total: Int, carbs: Int, protein: Int, fat: Int) -> (Double, Double, Double) {
        guard total > 0 else { return (0, 0, 0) }

        return (
            Double(max(0, carbs)) / Double(total),
            Double(max(0, protein)) / Double(total),
            Double(max(0, fat)) / Double(total)
        )
    }

    private func clamp01(_ x: Double) -> Double {
        min(max(x, 0), 1)
    }
}
