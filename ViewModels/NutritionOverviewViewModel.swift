//
//  NutritionOverviewViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für die Nutrition-Overview (Header, Macro-Bars, Macro-Distribution,
//  Daily Energy Balance, Insight)
//

import Foundation
import Combine
import SwiftUI    // für Color in scoreColor

@MainActor
final class NutritionOverviewViewModel: ObservableObject {

    // MARK: - Published Output (tagesbezogene Rohwerte)

    @Published var todayCarbsGrams: Int   = 0
    @Published var todayProteinGrams: Int = 0
    @Published var todayFatGrams: Int     = 0
    @Published var todayEnergyKcal: Int   = 0            // Nutrition Energy (intake)

    /// Trend-Daten für den Mini-Energy-Chart (z. B. letzte 14 Tage)
    @Published var energyTrendData: [(day: Int, energy: Int)] = []

    /// 0–100 Nutrition-Score für den aktuell ausgewählten Tag
    @Published var nutritionScore: Int = 0

    /// Kurztext-Insight
    @Published var insightText: String = ""

    // MARK: - Energy-Balance-spezifische Werte

    /// Aktive Energie (kcal) für den aktuell ausgewählten Tag
    @Published var todayActiveEnergyKcal: Int = 0

    /// Ruheenergie (kcal) – dynamisch berechnet über RestingEnergyHelper
    @Published var restingEnergyKcal: Int = 0

    // MARK: - Day Selection (Today / Yesterday / DayBefore)

    /// 0 = Today, -1 = Yesterday, -2 = DayBefore
    /// (Kann später für mehr Tage erweitert werden.)
    @Published var selectedDayOffset: Int = 0

    /// Das konkrete Datum, das aktuell in der Overview angezeigt wird
    var selectedDate: Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: selectedDayOffset, to: base) ?? base
    }

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()
    private let weightViewModel: WeightViewModel
    private let insightEngine = NutritionInsightEngine()
    private let scoreEngine = NutritionScoreEngine()

    // MARK: - Init

    init(
        healthStore: HealthStore,
        settings: SettingsModel,
        weightViewModel: WeightViewModel
    ) {
        self.healthStore = healthStore
        self.settings = settings
        self.weightViewModel = weightViewModel

        updateRestingEnergy()
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

    // MARK: - Score Color (für den Score-Button im Header)

    var scoreColor: Color {
        switch nutritionScore {
        case 0...33:
            return Color.red
        case 34...66:
            return Color.yellow
        default:
            return Color.green
        }
    }

    // MARK: - Loading (HealthKit-Abfrage)

    func refresh() async {
        // Ziel-Datum für die Abfrage (Today / Yesterday / DayBefore)
        let targetDate = selectedDate

        do {
            // Datumsbasierte HealthStore-Methoden
            async let carbs   = try healthStore.fetchDailyCarbs(for: targetDate)
            async let protein = try healthStore.fetchDailyProtein(for: targetDate)
            async let fat     = try healthStore.fetchDailyFat(for: targetDate)
            async let energy  = try healthStore.fetchDailyNutritionEnergy(for: targetDate)
            async let trend   = try healthStore.fetchLast14DaysEnergy()
            async let active  = try healthStore.fetchDailyActiveEnergy(for: targetDate)

            let (c, p, f, e, t, a) = try await (carbs, protein, fat, energy, trend, active)

            todayCarbsGrams   = c
            todayProteinGrams = p
            todayFatGrams     = f
            todayEnergyKcal   = e
            energyTrendData   = t
            todayActiveEnergyKcal = a

            // Resting Energy neu berechnen
            updateRestingEnergy()

            // Abgeleitete Werte aktualisieren (Score + Insight)
            recalculateDerivedValues()

        } catch {
            print("NutritionOverviewViewModel.refresh error:", error.localizedDescription)
        }
    }

    // MARK: - Derived Values (Score + Insight)

    private func recalculateDerivedValues() {

        // 1) DayContext aus selectedDayOffset ableiten
        let dayContext: DayContext
        switch selectedDayOffset {
        case 0:
            dayContext = .today
        case -1:
            dayContext = .yesterday
        case -2:
            dayContext = .dayBefore
        default:
            dayContext = .dayBefore
        }

        // 2) nowForContext bestimmen:
        //    – Heute: echte aktuelle Uhrzeit
        //    – Vergangenheit: 23:00 Uhr des jeweiligen Tages
        let nowForContext: Date
        let calendar = Calendar.current

        switch dayContext {
        case .today:
            nowForContext = Date()
        case .yesterday, .dayBefore:
            let base = selectedDate
            nowForContext = calendar.date(
                bySettingHour: 23,
                minute: 0,
                second: 0,
                of: base
            ) ?? base
        }

        // 3) Score neu bestimmen (für den aktuell ausgewählten Tag)
        nutritionScore = calculateNutritionScore(nowForContext: nowForContext)

        // 4) Input für die Insight-Engine bauen
        let input = NutritionInsightInput(
            todayEnergyKcal: todayEnergyKcal,
            todayActiveEnergyKcal: todayActiveEnergyKcal,
            restingEnergyKcal: restingEnergyKcal,
            todayCarbsGrams: todayCarbsGrams,
            todayProteinGrams: todayProteinGrams,
            todayFatGrams: todayFatGrams,
            energyBalanceKcal: energyBalanceKcal,
            carbsShare: carbsShare,
            proteinShare: proteinShare,
            fatShare: fatShare,
            nutritionScore: nutritionScore,
            dailyEnergyGoal: dailyEnergyGoal,
            targetCarbsGrams: targetCarbsGrams,
            targetProteinGrams: targetProteinGrams,
            targetFatGrams: targetFatGrams,
            now: nowForContext,
            dayContext: dayContext
        )

        // 5) Insight-Text von der Engine holen
        insightText = insightEngine.makeInsight(for: input)
    }

    /// Berechnet den täglichen Nutrition-Score (0–100) über die NutritionScoreEngine.
    private func calculateNutritionScore(nowForContext: Date) -> Int {
        let input = NutritionScoreInput(
            todayEnergyKcal: todayEnergyKcal,
            dailyEnergyGoal: dailyEnergyGoal,
            todayCarbsGrams: todayCarbsGrams,
            todayProteinGrams: todayProteinGrams,
            todayFatGrams: todayFatGrams,
            carbsShare: carbsShare,
            proteinShare: proteinShare,
            fatShare: fatShare,
            totalMacrosToday: totalMacrosToday,
            now: nowForContext
        )

        return scoreEngine.makeScore(from: input)
    }

    // MARK: - Resting Energy Berechnung

    /// Berechnet die aktuelle Resting Energy (BMR) auf Basis der Settings (Mifflin–St Jeor)
    /// und schreibt sie in `restingEnergyKcal`. Aktuell ohne Weight-Override, nur Settings.weightKg.
    private func updateRestingEnergy() {
        let bmr = RestingEnergyHelper.restingEnergyFromSettings(settings)
        restingEnergyKcal = Int(bmr.rounded())
    }
}
