//
//  NutritionScoreEngine.swift
//  GluVibProbe
//

import Foundation

/// Input für die Score-Berechnung
struct NutritionScoreInput {
    let todayEnergyKcal: Int          // heutige Intake-Energie
    let dailyEnergyGoal: Int          // Tagesziel aus Settings

    let todayCarbsGrams: Int
    let todayProteinGrams: Int
    let todayFatGrams: Int

    let carbsShare: Double            // 0.0–1.0
    let proteinShare: Double          // 0.0–1.0
    let fatShare: Double              // 0.0–1.0

    let totalMacrosToday: Int         // Summe C+P+F in g

    let now: Date                     // Referenzzeitpunkt (für Tageszeit-Logik)
}

final class NutritionScoreEngine {

    // MARK: - Public API

    func makeScore(from input: NutritionScoreInput) -> Int {
        let energy = energyScore(from: input)
        let macro  = macroScore(from: input)

        // Gewichtung: Energie etwas wichtiger als Makros
        let combined = energy * 0.6 + macro * 0.4
        return Int(combined.rounded())
    }

    // MARK: - Energy Score (mit Tageszeit-Faktor)

    private func energyScore(from input: NutritionScoreInput) -> Double {
        guard input.dailyEnergyGoal > 0 else {
            return 50.0
        }

        // Erwartete Energie zu dieser Tageszeit
        let expected = expectedEnergyForTimeOfDay(
            goal: Double(input.dailyEnergyGoal),
            now: input.now
        )

        guard expected > 0 else {
            return 50.0
        }

        let ratio = Double(input.todayEnergyKcal) / expected
        // ratio ~ 1.0 ist ideal, Abweichungen werden bestraft

        let diff = abs(ratio - 1.0)

        // Bis ca. ±20 % kaum Strafe, bis ±60 % fällt der Score auf 0
        let toleratedDiff: Double = 0.2
        let maxDiff: Double       = 0.6

        if diff <= toleratedDiff {
            return 100.0
        }

        let over = min(diff, maxDiff) - toleratedDiff
        let range = maxDiff - toleratedDiff
        let penaltyFraction = over / range   // 0…1
        let score = 100.0 * (1.0 - penaltyFraction)

        return max(0.0, min(100.0, score))
    }

    /// Erwartete Energie-Aufnahme in Abhängigkeit von der Uhrzeit.
    ///
    /// - Bis 20 Uhr: Ziel wird nur anteilig erwartet (milder Score).
    /// - 21–23 Uhr: vollständige Tageslogik („End-of-day“).
    private func expectedEnergyForTimeOfDay(goal: Double, now: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: now)

        let factor: Double

        switch hour {
        case ..<8:
            factor = 0.25        // früher Morgen: sehr mild
        case 8..<12:
            factor = 0.45        // Vormittag
        case 12..<16:
            factor = 0.60        // Mittag / früher Nachmittag
        case 16..<20:
            factor = 0.75        // später Nachmittag / früher Abend
        case 20..<21:
            factor = 0.90        // Übergang zu „End-of-day“
        default:
            factor = 1.0         // 21–23 Uhr: voller Tagesvergleich
        }

        return goal * factor
    }

    // MARK: - Macro Score (Verteilung + Zielerreichung light)

    private func macroScore(from input: NutritionScoreInput) -> Double {
        guard input.totalMacrosToday > 0 else {
            // Noch nichts gegessen → neutraler Mittelwert
            return 50.0
        }

        // 1) Verteilungs-Score (wie ausgewogen sind C/P/F als Prozentanteile?)
        let distributionScore = distributionMacroScore(
            carbsShare: input.carbsShare,
            proteinShare: input.proteinShare,
            fatShare: input.fatShare
        )

        // 2) Zielerreichungs-Score (wie weit bist du von den absoluten Makrozielen weg?)
        let targetScore = targetMacroScore(
            carbs: input.todayCarbsGrams,
            protein: input.todayProteinGrams,
            fat: input.todayFatGrams,
            goalCarbs: input.dailyEnergyGoal > 0 ? nil : nil // Platzhalter, falls wir später echte Makro-Ziele hier reinziehen wollen
        )

        // Aktuell: Verteilung wichtiger als Zielerreichung
        let combined = distributionScore * 0.7 + targetScore * 0.3
        return combined
    }

    // Nur Verteilung – keine harten Zielwerte
    private func distributionMacroScore(
        carbsShare: Double,
        proteinShare: Double,
        fatShare: Double
    ) -> Double {

        // Ziel: grob ausgewogen → Carbs 40–50 %, Protein 25–35 %, Fat 20–35 %
        func scoreRange(_ value: Double, min: Double, max: Double) -> Double {
            if value < min {
                let diff = min - value
                if diff >= 0.20 { return 40.0 }
                if diff >= 0.10 { return 60.0 }
                return 80.0
            } else if value > max {
                let diff = value - max
                if diff >= 0.20 { return 40.0 }
                if diff >= 0.10 { return 60.0 }
                return 80.0
            } else {
                return 100.0
            }
        }

        let cScore = scoreRange(carbsShare,   min: 0.40, max: 0.50)
        let pScore = scoreRange(proteinShare, min: 0.25, max: 0.35)
        let fScore = scoreRange(fatShare,     min: 0.20, max: 0.35)

        return (cScore + pScore + fScore) / 3.0
    }

    /// Sehr einfache Zielerreichungs-Logik (aktuell nur „wie viel gegessen?“),
    /// kann später mit echten Makro-Zielen erweitert werden.
    private func targetMacroScore(
        carbs: Int,
        protein: Int,
        fat: Int,
        goalCarbs: Int?
    ) -> Double {

        // Solange wir nur begrenzt Zielwerte reinziehen, geben wir hier
        // einen relativ milden, konstant mittleren Wert zurück.
        // So bleibt der Score stabil und wird hauptsächlich von Verteilung + Energie gesteuert.
        return 70.0
    }
}
