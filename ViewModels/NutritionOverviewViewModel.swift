//
//  NutritionOverviewViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für die Nutrition-Overview (Header, Macro-Bars, Macro-Distribution,
//  Daily Energy Balance, Insight)
//

import Foundation
import Combine

@MainActor
final class NutritionOverviewViewModel: ObservableObject {

    // MARK: - Published Output (heutige Rohwerte)

    @Published var todayCarbsGrams: Int   = 0
    @Published var todayProteinGrams: Int = 0
    @Published var todayFatGrams: Int     = 0
    @Published var todayEnergyKcal: Int   = 0            // Nutrition Energy (intake)

    /// Trend-Daten für den Mini-Energy-Chart (z. B. letzte 14 Tage)
    @Published var energyTrendData: [(day: Int, energy: Int)] = []

    /// Einfacher 0–100 Nutrition-Score für Today (Energy + Macro-Balance)
    @Published var nutritionScore: Int = 0

    /// Kurztext-Insight, z. B. "You are below your energy goal. Today is carb-focused."
    @Published var insightText: String = ""

    // MARK: - Energy-Balance-spezifische Werte

    /// Heute verbrauchte Aktivitätsenergie (kcal) – aus HealthStore
    @Published var todayActiveEnergyKcal: Int = 0

    /// Ruheenergie-Ziel (kcal) – aus SettingsModel (Resting Energy)
    @Published var restingEnergyKcal: Int = 0

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        healthStore: HealthStore,
        settings: SettingsModel
    ) {
        self.healthStore = healthStore
        self.settings    = settings

        // Resting Energy immer mit SettingsModel verknüpfen
        restingEnergyKcal = settings.restingEnergy
        settings.$restingEnergy
            .receive(on: DispatchQueue.main)
            .assign(to: &$restingEnergyKcal)
    }

    // MARK: - Helper: Number Formatting

    /// Formatiert eine Int-Zahl mit Tausenderpunkt (z.B. 1496 → "1.496")
    private func formatNumber(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    // MARK: - Goal & Progress (Energy)

    /// Daily Nutrition Energy Goal (aus Settings – "Daily Calories")
    var dailyEnergyGoal: Int {
        max(settings.dailyCalories, 1)
    }

    /// Gesamt-Energiebudget = Active + Resting
    var energyBudgetKcal: Int {
        max(todayActiveEnergyKcal + restingEnergyKcal, 0)
    }

    /// Energiebilanz = Budget - Intake
    /// >0  → kcal remaining
    /// <0  → kcal over
    var energyBalanceKcal: Int {
        energyBudgetKcal - todayEnergyKcal
    }

    /// true, wenn noch kcal übrig sind (grün), false = "over" (rot)
    var isEnergyRemaining: Bool {
        energyBalanceKcal >= 0
    }

    /// Für den Text im Ring („801“), mit Tausenderpunkt
    var formattedEnergyBalanceValue: String {
        let value = abs(energyBalanceKcal)
        return formatNumber(value)
    }

    /// Label im Ring („kcal remaining“ / „kcal over“)
    var energyBalanceLabelText: String {
        isEnergyRemaining ? "kcal remaining" : "kcal over"
    }

    /// Fortschritt für den Ring: Anteil des Intake am Budget (0…1.2)
    var energyProgress: Double {
        guard energyBudgetKcal > 0 else { return 0 }
        let ratio = Double(todayEnergyKcal) / Double(energyBudgetKcal)
        return min(max(ratio, 0), 1.2)
    }

    /// Formatierte Zeilen für die rechte Spalte der Energy-Balance-Kachel
    var formattedActiveEnergyKcal: String {
        "\(formatNumber(todayActiveEnergyKcal)) kcal"
    }

    var formattedRestingEnergyKcal: String {
        "\(formatNumber(restingEnergyKcal)) kcal"
    }

    var formattedNutritionEnergyKcal: String {
        "\(formatNumber(todayEnergyKcal)) kcal"
    }

    // MARK: - Macro Distribution (Carbs / Protein / Fat)

    /// Summe der Makros heute (g) – Basis für prozentuale Verteilung
    private var totalMacrosToday: Int {
        let sum = todayCarbsGrams + todayProteinGrams + todayFatGrams
        return max(sum, 0)
    }

    /// Anteil Carbs (0.0–1.0)
    var carbsShare: Double {
        guard totalMacrosToday > 0 else { return 0 }
        return Double(todayCarbsGrams) / Double(totalMacrosToday)
    }

    /// Anteil Protein (0.0–1.0)
    var proteinShare: Double {
        guard totalMacrosToday > 0 else { return 0 }
        return Double(todayProteinGrams) / Double(totalMacrosToday)
    }

    /// Anteil Fat (0.0–1.0)
    var fatShare: Double {
        guard totalMacrosToday > 0 else { return 0 }
        return Double(todayFatGrams) / Double(totalMacrosToday)
    }

    /// Prozentwerte (0–100), gerundet – ideal für horizontale Balken
    var carbsPercent: Int   { Int((carbsShare   * 100).rounded()) }
    var proteinPercent: Int { Int((proteinShare * 100).rounded()) }
    var fatPercent: Int     { Int((fatShare     * 100).rounded()) }

    // MARK: - Macro-Targets aus Settings

    var targetCarbsGrams: Int   { settings.dailyCarbs }
    var targetProteinGrams: Int { settings.dailyProtein }
    var targetFatGrams: Int     { settings.dailyFat }

    var carbsGoalPercent: Int {
        guard targetCarbsGrams > 0 else { return 0 }
        return Int((Double(todayCarbsGrams) / Double(targetCarbsGrams) * 100).rounded())
    }

    var proteinGoalPercent: Int {
        guard targetProteinGrams > 0 else { return 0 }
        return Int((Double(todayProteinGrams) / Double(targetProteinGrams) * 100).rounded())
    }

    var fatGoalPercent: Int {
        guard targetFatGrams > 0 else { return 0 }
        return Int((Double(todayFatGrams) / Double(targetFatGrams) * 100).rounded())
    }

    // MARK: - Loading (HealthKit-Abfrage)

    func refresh() async {
        // 🔹 Aktivitätsenergie für heute anstoßen (nicht async, wie im ActivityEnergyViewModel)
        healthStore.fetchActiveEnergyToday()

        do {
            // Diese Funktionen müssen in HealthStore als async/throws existieren
            async let carbs   = try healthStore.fetchTodayCarbs()
            async let protein = try healthStore.fetchTodayProtein()
            async let fat     = try healthStore.fetchTodayFat()
            async let energy  = try healthStore.fetchTodayEnergy()
            async let trend   = try healthStore.fetchLast14DaysEnergy()

            let (c, p, f, e, t) = try await (carbs, protein, fat, energy, trend)

            todayCarbsGrams   = c
            todayProteinGrams = p
            todayFatGrams     = f
            todayEnergyKcal   = e
            energyTrendData   = t

            // Aktivitätsenergie aus HealthStore übernehmen
            todayActiveEnergyKcal = healthStore.todayActiveEnergy

            // Abgeleitete Werte aktualisieren (Score + Insight)
            recalculateDerivedValues()

        } catch {
            print("NutritionOverviewViewModel.refresh error:", error.localizedDescription)
        }
    }

    // MARK: - Derived Values (Score + Insight)

    private func recalculateDerivedValues() {
        nutritionScore = calculateNutritionScore()
        insightText    = buildInsightText()
    }

    /// Sehr einfache erste Version eines 0–100 Scores:
    /// - Energy-Komponente: wie nah bist du am Daily-Calorie-Goal?
    /// - Macro-Komponente: wie nah bist du an einer groben Zielverteilung (45C / 25P / 30F)?
    private func calculateNutritionScore() -> Int {
        // 1) Energy-Score (0–100)
        let energyScore: Double
        if dailyEnergyGoal <= 0 || todayEnergyKcal <= 0 {
            energyScore = 0
        } else {
            let ratio = Double(todayEnergyKcal) / Double(dailyEnergyGoal)
            // 1.0 = perfekt, je weiter weg, desto schlechter
            let diff = abs(ratio - 1.0)                      // 0 perfekt, >0 Abweichung
            let raw  = max(0.0, 1.0 - diff) * 100.0          // diff 0 → 100, diff 1 → 0
            energyScore = raw
        }

        // 2) Macro-Balance-Score (0–100)
        let macroScore: Double
        if totalMacrosToday <= 0 {
            macroScore = 0
        } else {
            // grobe Zielverteilung
            let idealCarbs   = 0.45
            let idealProtein = 0.25
            let idealFat     = 0.30

            let spread =
                abs(carbsShare   - idealCarbs) +
                abs(proteinShare - idealProtein) +
                abs(fatShare     - idealFat)

            // spread 0 → perfekt, ~1.5 → sehr schlecht
            let raw = max(0.0, 1.5 - spread) / 1.5 * 100.0
            macroScore = raw
        }

        // 3) Kombiniert: 60 % Energy, 40 % Makros
        let combined = energyScore * 0.6 + macroScore * 0.4
        let clamped  = max(0.0, min(combined, 100.0))

        return Int(clamped.rounded())
    }

    /// Baut einen kurzen Insight-Text aus Energy-Status + Macro-Schwerpunkt.
    private func buildInsightText() -> String {
        // Kein Data → früher Exit
        if todayEnergyKcal <= 0 && totalMacrosToday <= 0 {
            return "No nutrition data recorded yet today."
        }

        var parts: [String] = []

        // 1) Energy-Teil (bezogen auf Daily Calories)
        if todayEnergyKcal <= 0 {
            parts.append("No energy intake recorded yet today.")
        } else {
            let ratio = Double(todayEnergyKcal) / Double(dailyEnergyGoal)

            switch ratio {
            case ..<0.8:
                parts.append("You are currently below your daily energy goal.")
            case 0.8...1.1:
                parts.append("You are close to your daily energy goal.")
            default:
                parts.append("You are above your daily energy goal.")
            }
        }

        // 2) Macro-Schwerpunkt
        if totalMacrosToday > 0 {
            let c = carbsShare
            let p = proteinShare
            let f = fatShare

            if c >= p && c >= f {
                parts.append("Today is more carb-focused.")
            } else if p >= c && p >= f {
                parts.append("Today is protein-heavy, which can support recovery.")
            } else {
                parts.append("Fat intake is relatively high today.")
            }
        }

        return parts.joined(separator: " ")
    }
}
