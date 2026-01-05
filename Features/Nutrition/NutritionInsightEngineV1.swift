//
//  NutritionInsightEngineV1.swift
//  GluVibProbe
//
//  V1: Stateless Engine for Nutrition Overview
//  - Pure compute (no side effects)
//  - Produces derived UI outputs: score, percents, shares, energy balance, insight
//

import Foundation
import SwiftUI

struct NutritionInsightEngineV1 {

    // ============================================================
    // MARK: - Input / Output
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

        // --- Percents
        let carbsPct = percent(current: input.carbsGrams, target: input.targetCarbsGrams)
        let proteinPct = percent(current: input.proteinGrams, target: input.targetProteinGrams)
        let fatPct = percent(current: input.fatGrams, target: input.targetFatGrams)

        // --- Shares
        let totalMacros = max(0, input.carbsGrams + input.proteinGrams + input.fatGrams)
        let (carbShare, protShare, fatShare) = macroShares(
            total: totalMacros,
            carbs: input.carbsGrams,
            protein: input.proteinGrams,
            fat: input.fatGrams
        )

        // --- Energy
        let totalBurned = max(0, input.activeEnergyKcal + input.restingEnergyKcal)
        let balance = totalBurned - input.nutritionEnergyKcal   // >0 remaining, <0 over
        let isRemaining = balance >= 0

        let denom = max(1, totalBurned)
        let progress = clamp01(Double(input.nutritionEnergyKcal) / Double(denom))

        let balanceValue = "\(abs(balance))"
        let balanceLabel = isRemaining ? "kcal remaining" : "kcal over"

        // --- Score (simple)
        let anyData = (totalMacros + input.nutritionEnergyKcal) > 0
        let score: Int = {
            guard anyData else { return 0 }
            let a = min(carbsPct, 100)
            let b = min(proteinPct, 100)
            let c = min(fatPct, 100)
            return Int((Double(a + b + c) / 3.0).rounded())
        }()

        let scoreColor: Color = {
            if score >= 80 { return .green }
            if score >= 50 { return Color.Glu.nutritionDomain }
            return .orange
        }()

        // --- Insight (nur Today)
        let insight: String = {
            guard input.isToday else { return "" }

            guard anyData else {
                return "No nutrition data recorded yet today."
            }

            if carbsPct > 110 {
                return "Carbs are above your target today."
            }

            if proteinPct < 60 && input.targetProteinGrams > 0 {
                return "Protein is still low today — consider a protein-rich meal."
            }

            if isRemaining {
                return "You still have energy remaining for today."
            } else {
                return "You are currently over your daily energy burn."
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
    // MARK: - Helpers
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
