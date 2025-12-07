//
//  NutritionInsightEngine.swift
//  GluVibProbe
//
//  Vereinfachte, tageszeit-basierte Text-Engine für die Nutrition Insight Card
//

import Foundation

// MARK: - Tageskontext (heute / gestern / vorgestern)

enum DayContext {
    case today
    case yesterday
    case dayBefore
}

// MARK: - Tageszeit-Bänder (nur für HEUTE-„so far“-Insights)

enum TimeOfDayBand {
    case morning
    case afternoon
    case evening
}

// MARK: - Phase für „today“

private enum TodayPhase {
    case soFar    // Tag läuft noch
    case final    // Tagesfazit (ab ~21:00 Uhr)
}

// MARK: - Input-Daten für die Engine

struct NutritionInsightInput {
    let todayEnergyKcal: Int
    let todayActiveEnergyKcal: Int
    let restingEnergyKcal: Int

    let todayCarbsGrams: Int
    let todayProteinGrams: Int
    let todayFatGrams: Int

    let energyBalanceKcal: Int

    let carbsShare: Double
    let proteinShare: Double
    let fatShare: Double

    let nutritionScore: Int

    // Ziele & Tageskontext
    let dailyEnergyGoal: Int
    let targetCarbsGrams: Int
    let targetProteinGrams: Int
    let targetFatGrams: Int

    let now: Date
    let dayContext: DayContext
}

// MARK: - Klassifizierungen

private enum EnergyLevel {
    case low        // deutlich zu wenig
    case moderate   // im moderaten Bereich
    case high       // eher viel / hoch
}

private enum MacroProfile {
    case noIntake
    case balanced
    case carbLeaning
    case proteinLeaning
    case fatLeaning
}

private enum MacroTargetMatch {
    case nearTargets
    case offTargets
}

// MARK: - Engine

struct NutritionInsightEngine {

    func makeInsight(for input: NutritionInsightInput) -> String {

        // 1) Energy-Level auf Basis von Budget vs. Intake
        let budget = max(input.todayActiveEnergyKcal + input.restingEnergyKcal, 1)
        let energyLevel = Self.classifyEnergyLevel(
            intake: input.todayEnergyKcal,
            budget: budget
        )

        // 2) Makro-Profil & Target-Match
        let macroProfile = Self.classifyMacroProfile(
            carbsShare: input.carbsShare,
            proteinShare: input.proteinShare,
            fatShare: input.fatShare,
            totalGrams: input.todayCarbsGrams + input.todayProteinGrams + input.todayFatGrams
        )

        let targetMatch = Self.classifyMacroTargetMatch(
            carbs: input.todayCarbsGrams,
            protein: input.todayProteinGrams,
            fat: input.todayFatGrams,
            targetCarbs: input.targetCarbsGrams,
            targetProtein: input.targetProteinGrams,
            targetFat: input.targetFatGrams
        )

        // 3) Tageszeit / Phase bestimmen
        let timeBand = Self.timeOfDayBand(for: input.now)
        let todayPhase = Self.todayPhase(for: input.now, dayContext: input.dayContext)

        // 4) Text je DayContext
        switch input.dayContext {

        case .today:
            return Self.buildTodayInsight(
                energyLevel: energyLevel,
                macroProfile: macroProfile,
                targetMatch: targetMatch,
                timeBand: timeBand,
                phase: todayPhase
            )

        case .yesterday:
            return Self.buildPastInsight(
                dayLabel: "Yesterday",
                energyLevel: energyLevel,
                macroProfile: macroProfile,
                targetMatch: targetMatch
            )

        case .dayBefore:
            return Self.buildPastInsight(
                dayLabel: "The day before",
                energyLevel: energyLevel,
                macroProfile: macroProfile,
                targetMatch: targetMatch
            )
        }
    }
}

// MARK: - Klassifikations-Helpers

private extension NutritionInsightEngine {

    static func classifyEnergyLevel(intake: Int, budget: Int) -> EnergyLevel {
        let ratio = Double(intake) / Double(budget)   // 0.0 … >1.0

        if ratio < 0.4 {
            return .low
        } else if ratio <= 0.75 {
            return .moderate
        } else {
            return .high
        }
    }

    static func classifyMacroProfile(
        carbsShare: Double,
        proteinShare: Double,
        fatShare: Double,
        totalGrams: Int
    ) -> MacroProfile {

        if totalGrams < 20 {
            return .noIntake
        }

        let c = carbsShare
        let p = proteinShare
        let f = fatShare

        let maxShare = max(c, max(p, f))
        let sorted = [c, p, f].sorted(by: >)
        let secondMax = sorted.count > 1 ? sorted[1] : 0.0
        let gap = maxShare - secondMax

        if gap < 0.12 {
            return .balanced
        } else if maxShare == c {
            return .carbLeaning
        } else if maxShare == p {
            return .proteinLeaning
        } else {
            return .fatLeaning
        }
    }

    static func classifyMacroTargetMatch(
        carbs: Int,
        protein: Int,
        fat: Int,
        targetCarbs: Int,
        targetProtein: Int,
        targetFat: Int
    ) -> MacroTargetMatch {

        func ratio(_ value: Int, _ target: Int) -> Double? {
            guard target > 0 else { return nil }
            return Double(value) / Double(target)
        }

        let ratios = [
            ratio(carbs, targetCarbs),
            ratio(protein, targetProtein),
            ratio(fat, targetFat)
        ].compactMap { $0 }

        guard !ratios.isEmpty else {
            return .nearTargets
        }

        let allNear = ratios.allSatisfy { $0 >= 0.6 && $0 <= 1.4 }
        return allNear ? .nearTargets : .offTargets
    }

    static func timeOfDayBand(for date: Date) -> TimeOfDayBand {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        default:
            return .evening
        }
    }

    static func todayPhase(for date: Date, dayContext: DayContext) -> TodayPhase {
        switch dayContext {
        case .today:
            let hour = Calendar.current.component(.hour, from: date)
            return hour >= 21 ? .final : .soFar
        case .yesterday, .dayBefore:
            return .final
        }
    }

    static func todayIntro(for band: TimeOfDayBand) -> String {
        switch band {
        case .morning:
            return "So far this morning,"
        case .afternoon:
            return "So far this afternoon,"
        case .evening:
            return "So far today,"
        }
    }
}

// MARK: - Text-Bausteine

private extension NutritionInsightEngine {

    // ------------------------------------------------------------
    // HEUTE
    // ------------------------------------------------------------
    static func buildTodayInsight(
        energyLevel: EnergyLevel,
        macroProfile: MacroProfile,
        targetMatch: MacroTargetMatch,
        timeBand: TimeOfDayBand,
        phase: TodayPhase
    ) -> String {

        switch phase {

        // 🔹 Tag läuft noch → KEIN Target-Vergleich, nur „so far“
        case .soFar:
            let prefix = todayIntro(for: timeBand)

            let energySentence: String
            switch energyLevel {
            case .low:
                energySentence = "\(prefix) your energy intake is still low for today’s needs."
            case .moderate:
                energySentence = "\(prefix) your energy intake is moderate for today’s needs."
            case .high:
                energySentence = "\(prefix) your energy intake is already on the higher side."
            }

            let macroSentence: String
            switch macroProfile {
            case .noIntake:
                macroSentence = "You have too little logged intake for a clear macro pattern."
            case .balanced:
                macroSentence = "Your macros are broadly balanced so far."
            case .carbLeaning:
                macroSentence = "Your macros lean toward carbohydrates so far."
            case .proteinLeaning:
                macroSentence = "Your macros lean toward protein so far."
            case .fatLeaning:
                macroSentence = "Your macros lean toward fats so far."
            }

            return energySentence + " " + macroSentence

        // 🔹 Tagesfazit (ab 21 Uhr) → Target-Vergleich erlaubt
        case .final:
            let prefix = "For today overall,"

            let energySentence: String
            switch energyLevel {
            case .low:
                energySentence = "\(prefix) your energy intake was below your estimated needs."
            case .moderate:
                energySentence = "\(prefix) your energy intake was close to your needs."
            case .high:
                energySentence = "\(prefix) your energy intake was above your estimated needs."
            }

            let macroSentence: String
            switch macroProfile {
            case .noIntake:
                macroSentence = "There was too little logged intake for a clear macro pattern."
            case .balanced:
                switch targetMatch {
                case .nearTargets:
                    macroSentence = "Macros were balanced and close to your targets."
                case .offTargets:
                    macroSentence = "Macros were balanced but differed from your targets."
                }
            case .carbLeaning:
                switch targetMatch {
                case .nearTargets:
                    macroSentence = "Macros leaned toward carbohydrates within your target range."
                case .offTargets:
                    macroSentence = "Macros leaned toward carbohydrates and away from your targets."
                }
            case .proteinLeaning:
                switch targetMatch {
                case .nearTargets:
                    macroSentence = "Macros were slightly protein-focused and near your targets."
                case .offTargets:
                    macroSentence = "Macros were protein-focused and away from your target split."
                }
            case .fatLeaning:
                switch targetMatch {
                case .nearTargets:
                    macroSentence = "Macros were somewhat higher in fats but still near your targets."
                case .offTargets:
                    macroSentence = "Macros were fat-heavy and clearly away from your targets."
                }
            }

            return energySentence + " " + macroSentence
        }
    }

    // ------------------------------------------------------------
    // VERGANGENE TAGE (yesterday / day before)
    // ------------------------------------------------------------
    static func buildPastInsight(
        dayLabel: String,
        energyLevel: EnergyLevel,
        macroProfile: MacroProfile,
        targetMatch: MacroTargetMatch
    ) -> String {

        let energySentence: String
        switch energyLevel {
        case .low:
            energySentence = "\(dayLabel), your energy intake was below your estimated needs."
        case .moderate:
            energySentence = "\(dayLabel), your energy intake was close to your needs."
        case .high:
            energySentence = "\(dayLabel), your energy intake was above your estimated needs."
        }

        let macroSentence: String
        switch macroProfile {
        case .noIntake:
            macroSentence = "Macros could not be assessed due to low logged intake."
        case .balanced:
            switch targetMatch {
            case .nearTargets:
                macroSentence = "Macros were balanced and close to your targets."
            case .offTargets:
                macroSentence = "Macros were balanced but away from your targets."
            }
        case .carbLeaning:
            switch targetMatch {
            case .nearTargets:
                macroSentence = "Macros leaned toward carbohydrates within your target range."
            case .offTargets:
                macroSentence = "Macros leaned toward carbohydrates and away from your targets."
            }
        case .proteinLeaning:
            switch targetMatch {
            case .nearTargets:
                macroSentence = "Macros were more protein-focused and near your targets."
            case .offTargets:
                macroSentence = "Macros were protein-focused and away from your target split."
            }
        case .fatLeaning:
            switch targetMatch {
            case .nearTargets:
                macroSentence = "Macros were somewhat higher in fats but still near your targets."
            case .offTargets:
                macroSentence = "Macros were fat-heavy and clearly away from your targets."
            }
        }

        return energySentence + " " + macroSentence
    }
}
