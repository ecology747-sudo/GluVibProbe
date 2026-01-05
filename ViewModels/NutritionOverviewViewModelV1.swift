//
//  NutritionOverviewViewModelV1.swift
//  GluVibProbe
//
//  V1 CLEAN: Nutrition Overview View Model
//  - Single Source of Truth: HealthStore (Settings nur Goals/Units)
//  - Publisher dürfen nur triggern (scheduleRemap), niemals Outputs direkt setzen
//  - Exakt EIN Writer: refreshForSelectedDay()
//  - Pull-to-Refresh nur für TODAY
//  - ✅ WICHTIG: KEINE Insight-Berechnung für Yesterday/DayBefore (wie Activity)
//  - ✅ ABER: Percent/Shares/Energy-UI MUSS für alle Tage berechnet werden (sonst 0%/leere Ringe)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class NutritionOverviewViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Dependencies (SSoT)
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Engines (stateless)
    // ============================================================

    private let insightEngine = NutritionInsightEngineV1()

    // ============================================================
    // MARK: - Remap Coalescing
    // ============================================================

    private var remapTask: Task<Void, Never>? = nil
    private var remapToken: Int = 0

    // ============================================================
    // MARK: - Day Selection (Pager)
    // ============================================================

    /// 0 = Today, -1 = Yesterday, -2 = DayBeforeYesterday
    @Published var selectedDayOffset: Int = 0

    var selectedDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: selectedDayOffset, to: today) ?? today
    }

    // ============================================================
    // MARK: - Published Output (für NutritionOverviewViewV1)
    // ============================================================

    // --- Score (TODAY only meaningful)
    @Published var nutritionScore: Int = 0
    @Published var scoreColor: Color = Color.Glu.nutritionDomain

    // --- Macro Targets + Today/Past-Day Values
    @Published var todayCarbsGrams: Int = 0
    @Published var todayProteinGrams: Int = 0
    @Published var todayFatGrams: Int = 0

    @Published var targetCarbsGrams: Int = 0
    @Published var targetProteinGrams: Int = 0
    @Published var targetFatGrams: Int = 0

    @Published var carbsGoalPercent: Int = 0
    @Published var proteinGoalPercent: Int = 0
    @Published var fatGoalPercent: Int = 0

    // --- Macro shares (Pie)
    @Published var carbsShare: Double = 0
    @Published var proteinShare: Double = 0
    @Published var fatShare: Double = 0

    // --- Energy ring / cards
    @Published var todayNutritionEnergyKcal: Int = 0
    @Published var todayActiveEnergyKcal: Int = 0

    @Published var restingEnergyKcal: Int = 0

    @Published var isEnergyRemaining: Bool = true
    @Published var energyProgress: Double = 0
    @Published var formattedEnergyBalanceValue: String = "0"
    @Published var energyBalanceLabelText: String = "kcal remaining"

    @Published var formattedNutritionEnergyKcal: String = "0 kcal"
    @Published var formattedActiveEnergyKcal: String = "0 kcal"
    @Published var formattedRestingEnergyKcal: String = "0 kcal"

    // --- Insight (TODAY only)
    @Published var insightText: String = ""

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindStores()
        syncInitialState()
    }

    // ============================================================
    // MARK: - Bindings (Publisher dürfen nur triggern)
    // ============================================================

    private func bindStores() {

        // --- Macros live + history

        healthStore.$todayCarbsGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$carbsDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        healthStore.$todayProteinGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$proteinDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        healthStore.$todayFatGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$fatDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        // --- Nutrition Energy (Intake)

        healthStore.$todayNutritionEnergyKcal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$nutritionEnergyDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        // --- Active Energy (Burned)

        healthStore.$todayActiveEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$last90DaysActiveEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        // --- Resting Energy (Burned) - TODAY live (trigger-only)
        healthStore.$todayRestingEnergyKcal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        // !!! NEW: Resting Energy History trigger-only (needed for Yesterday/DayBefore)
        healthStore.$last90DaysRestingEnergy                                               // !!! NEW
            .receive(on: DispatchQueue.main)                                                // !!! NEW
            .sink { [weak self] _ in self?.scheduleRemap() }                                // !!! NEW
            .store(in: &cancellables)                                                       // !!! NEW

        // -------------------------
        // Targets (SettingsModel)
        // -------------------------

        settings.$dailyCarbs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in self?.scheduleRemap() }
            .store(in: &cancellables)

        settings.$dailyProtein
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in self?.scheduleRemap() }
            .store(in: &cancellables)

        settings.$dailyFat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in self?.scheduleRemap() }
            .store(in: &cancellables)

        settings.$dailyCalories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in self?.scheduleRemap() }
            .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Remap Scheduling
    // ============================================================

    private func scheduleRemap() {
        remapToken += 1
        let token = remapToken

        remapTask?.cancel()
        remapTask = Task { @MainActor in
            await Task.yield()
            guard token == self.remapToken else { return }
            self.refreshForSelectedDay()
        }
    }

    // ============================================================
    // MARK: - Initial Sync
    // ============================================================

    private func syncInitialState() {
        selectedDayOffset = 0
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Day Selection API (Pager)
    // ============================================================

    func applySelectedDayOffset(_ offset: Int) async {
        selectedDayOffset = offset
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Public API (Overview Refresh)
    // ============================================================

    func refresh() async {
        // !!! UPDATED: Pull-to-Refresh darf auch Past Days aktualisieren,
        // damit nachträgliche Einträge (heute erfasst, für gestern datiert) sichtbar werden.
        await healthStore.refreshNutrition(.pullToRefresh)     // !!! UPDATED
        refreshForSelectedDay()
    }

    func refreshOnNavigation() async {
        guard selectedDayOffset == 0 else {
            refreshForSelectedDay()
            return
        }
        await healthStore.refreshNutrition(.navigation)
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Core Mapping (EIN Writer)
    // ============================================================

    private func refreshForSelectedDay() {

        let date = selectedDate
        let calendar = Calendar.current

        // ---------------------------------------------------------
        // 1) Targets
        // ---------------------------------------------------------
        targetCarbsGrams = max(0, settings.dailyCarbs)
        targetProteinGrams = max(0, settings.dailyProtein)
        targetFatGrams = max(0, settings.dailyFat)

        // ---------------------------------------------------------
        // 2) Values (live for Today; cached for past days)
        // ---------------------------------------------------------
        if selectedDayOffset == 0 {

            todayCarbsGrams = max(0, healthStore.todayCarbsGrams)
            todayProteinGrams = max(0, healthStore.todayProteinGrams)
            todayFatGrams = max(0, healthStore.todayFatGrams)

            todayNutritionEnergyKcal = max(0, healthStore.todayNutritionEnergyKcal)
            todayActiveEnergyKcal = max(0, healthStore.todayActiveEnergy)

            restingEnergyKcal = max(0, healthStore.todayRestingEnergyKcal)               // !!! UPDATED

        } else {

            todayCarbsGrams = max(0, valueForDay(
                from: healthStore.carbsDaily365,
                date: date,
                dateKey: \.date,
                value: { $0.grams },
                calendar: calendar
            ))

            todayProteinGrams = max(0, valueForDay(
                from: healthStore.proteinDaily365,
                date: date,
                dateKey: \.date,
                value: { $0.grams },
                calendar: calendar
            ))

            todayFatGrams = max(0, valueForDay(
                from: healthStore.fatDaily365,
                date: date,
                dateKey: \.date,
                value: { $0.grams },
                calendar: calendar
            ))

            todayNutritionEnergyKcal = max(0, valueForDay(
                from: healthStore.nutritionEnergyDaily365,
                date: date,
                dateKey: \.date,
                value: { $0.energyKcal },
                calendar: calendar
            ))

            todayActiveEnergyKcal = max(0, valueForDay(
                from: healthStore.last90DaysActiveEnergy,
                date: date,
                dateKey: \.date,
                value: { $0.activeEnergy },
                calendar: calendar
            ))

            // !!! UPDATED: Past-Day RestingEnergy aus History (nicht 0)
            restingEnergyKcal = max(0, valueForDay(                                     // !!! UPDATED
                from: healthStore.last90DaysRestingEnergy,                               // !!! UPDATED
                date: date,                                                              // !!! UPDATED
                dateKey: \.date,                                                         // !!! UPDATED
                value: { $0.restingEnergyKcal },                                         // !!! UPDATED
                calendar: calendar                                                       // !!! UPDATED
            ))                                                                            // !!! UPDATED
        }

        // ---------------------------------------------------------
        // 3) UI-Derivations (✅ für ALLE Tage)
        // ---------------------------------------------------------
        applyDerivedUIValues()

        // ---------------------------------------------------------
        // 4) Insight Engine (✅ NUR TODAY)
        // ---------------------------------------------------------
        if selectedDayOffset == 0 {

            let input = NutritionInsightEngineV1.Input(
                isToday: true,
                carbsGrams: todayCarbsGrams,
                proteinGrams: todayProteinGrams,
                fatGrams: todayFatGrams,
                targetCarbsGrams: targetCarbsGrams,
                targetProteinGrams: targetProteinGrams,
                targetFatGrams: targetFatGrams,
                nutritionEnergyKcal: todayNutritionEnergyKcal,
                activeEnergyKcal: todayActiveEnergyKcal,
                restingEnergyKcal: restingEnergyKcal
            )

            let out = insightEngine.evaluate(input)

            nutritionScore = out.score
            scoreColor = out.scoreColor
            insightText = out.insightText

            carbsGoalPercent = out.carbsGoalPercent
            proteinGoalPercent = out.proteinGoalPercent
            fatGoalPercent = out.fatGoalPercent

            carbsShare = out.carbsShare
            proteinShare = out.proteinShare
            fatShare = out.fatShare

            isEnergyRemaining = out.isEnergyRemaining
            energyProgress = out.energyProgress
            formattedEnergyBalanceValue = out.formattedEnergyBalanceValue
            energyBalanceLabelText = out.energyBalanceLabelText

        } else {
            insightText = ""
            nutritionScore = 0
            scoreColor = Color.Glu.nutritionDomain
        }

        // ---------------------------------------------------------
        // 5) Formatted strings (Anzeige-only)
        // ---------------------------------------------------------
        formattedNutritionEnergyKcal = "\(todayNutritionEnergyKcal) kcal"
        formattedActiveEnergyKcal = "\(todayActiveEnergyKcal) kcal"
        formattedRestingEnergyKcal = "\(restingEnergyKcal) kcal"
    }

    // ============================================================
    // MARK: - Derived UI Values (no Insight Engine)
    // ============================================================

    private func applyDerivedUIValues() {

        carbsGoalPercent = percent(value: todayCarbsGrams, target: targetCarbsGrams)
        proteinGoalPercent = percent(value: todayProteinGrams, target: targetProteinGrams)
        fatGoalPercent = percent(value: todayFatGrams, target: targetFatGrams)

        let total = max(0, todayCarbsGrams) + max(0, todayProteinGrams) + max(0, todayFatGrams)
        if total > 0 {
            carbsShare = Double(todayCarbsGrams) / Double(total)
            proteinShare = Double(todayProteinGrams) / Double(total)
            fatShare = Double(todayFatGrams) / Double(total)
        } else {
            carbsShare = 0
            proteinShare = 0
            fatShare = 0
        }

        let burned = max(0, todayActiveEnergyKcal) + max(0, restingEnergyKcal)
        let intake = max(0, todayNutritionEnergyKcal)

        let diff = burned - intake
        isEnergyRemaining = diff >= 0

        let absDiff = abs(diff)
        formattedEnergyBalanceValue = "\(absDiff)"
        energyBalanceLabelText = isEnergyRemaining ? "kcal remaining" : "kcal over"

        let maxSide = max(burned, intake, 1)
        let minSide = min(burned, intake)
        energyProgress = min(max(Double(minSide) / Double(maxSide), 0), 1)
    }

    private func percent(value: Int, target: Int) -> Int {
        guard target > 0 else { return 0 }
        let raw = (Double(max(0, value)) / Double(target)) * 100.0
        return Int(raw.rounded())
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func valueForDay<T>(
        from values: [T],
        date: Date,
        dateKey: KeyPath<T, Date>,
        value: (T) -> Int,
        calendar: Calendar = .current
    ) -> Int {
        values.first(where: { calendar.isDate($0[keyPath: dateKey], inSameDayAs: date) })
            .map(value) ?? 0
    }
}
