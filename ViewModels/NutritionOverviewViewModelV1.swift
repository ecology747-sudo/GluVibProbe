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
//  - 🟨 UPDATED: Sugar integriert (Targets + Day Values + Goal Percent) — ohne Pie-Share (Sugar ist Teil von Carbs)
//  - 🟨 UPDATED: Energy Balance 7D window output (oldest → newest), built in VM (Steps/Weight pattern)
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
    @Published var todaySugarGrams: Int = 0
    @Published var todayProteinGrams: Int = 0
    @Published var todayFatGrams: Int = 0

    @Published var targetCarbsGrams: Int = 0
    @Published var targetSugarGrams: Int = 0
    @Published var targetProteinGrams: Int = 0
    @Published var targetFatGrams: Int = 0

    @Published var carbsGoalPercent: Int = 0
    @Published var sugarGoalPercent: Int = 0
    @Published var proteinGoalPercent: Int = 0
    @Published var fatGoalPercent: Int = 0

    // --- Macro shares (Pie)  (NOTE: Sugar bewusst NICHT im Pie)
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

    // 🟨 UPDATED: Energy Balance 7D (SSoT window; oldest → newest; ends at selected day)
    @Published var last7DaysEnergyBalance: [EnergyBalanceTrendPointV1] = [] // 🟨 UPDATED

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

        // --- Carbs live + history

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

        // --- Sugar live + history

        healthStore.$todaySugarGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$sugarDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        // --- Protein live + history

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

        // --- Fat live + history

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

        // --- Resting Energy (Burned)

        healthStore.$todayRestingEnergyKcal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$last90DaysRestingEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        // -------------------------
        // Targets (SettingsModel)
        // -------------------------

        settings.$dailyCarbs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Int) in self?.scheduleRemap() }
            .store(in: &cancellables)

        settings.$dailySugar
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
        await healthStore.refreshNutrition(.pullToRefresh)
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
        targetSugarGrams = max(0, settings.dailySugar)
        targetProteinGrams = max(0, settings.dailyProtein)
        targetFatGrams = max(0, settings.dailyFat)

        // ---------------------------------------------------------
        // 2) Values (live for Today; cached for past days)
        // ---------------------------------------------------------
        if selectedDayOffset == 0 {

            todayCarbsGrams = max(0, healthStore.todayCarbsGrams)
            todaySugarGrams = max(0, healthStore.todaySugarGrams)
            todayProteinGrams = max(0, healthStore.todayProteinGrams)
            todayFatGrams = max(0, healthStore.todayFatGrams)

            todayNutritionEnergyKcal = max(0, healthStore.todayNutritionEnergyKcal)
            todayActiveEnergyKcal = max(0, healthStore.todayActiveEnergy)

            restingEnergyKcal = max(0, healthStore.todayRestingEnergyKcal)

        } else {

            todayCarbsGrams = max(0, valueForDay(
                from: healthStore.carbsDaily365,
                date: date,
                dateKey: \.date,
                value: { $0.grams },
                calendar: calendar
            ))

            todaySugarGrams = max(0, valueForDay(
                from: healthStore.sugarDaily365,
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

            restingEnergyKcal = max(0, valueForDay(
                from: healthStore.last90DaysRestingEnergy,
                date: date,
                dateKey: \.date,
                value: { $0.restingEnergyKcal },
                calendar: calendar
            ))
        }

        // ---------------------------------------------------------
        // 🟨 UPDATED: 2b) Energy Balance 7D window (ends at selected day)
        // ---------------------------------------------------------
        last7DaysEnergyBalance = buildLast7DaysEnergyBalance(endingAt: date) // 🟨 UPDATED

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

            // 🟨 UPDATED: Sugar percent deterministic (engine doesn't know Sugar)
            sugarGoalPercent = percent(value: todaySugarGrams, target: targetSugarGrams)

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
        sugarGoalPercent = percent(value: todaySugarGrams, target: targetSugarGrams)
        proteinGoalPercent = percent(value: todayProteinGrams, target: targetProteinGrams)
        fatGoalPercent = percent(value: todayFatGrams, target: targetFatGrams)

        // Pie uses only macros (Sugar excluded by design)
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

    // 🟨 UPDATED: 7D window builder (oldest → newest), ends at selected day
    private func buildLast7DaysEnergyBalance(endingAt endDate: Date) -> [EnergyBalanceTrendPointV1] { // 🟨 UPDATED

        let cal = Calendar.current
        let endDay = cal.startOfDay(for: endDate)

        // 7 calendar days: endDay-6 ... endDay
        let days: [Date] = (0..<7).compactMap { i in
            cal.date(byAdding: .day, value: -(6 - i), to: endDay)
        }

        return days.map { day in

            let intake: Int
            let active: Int
            let resting: Int

            if cal.isDate(day, inSameDayAs: cal.startOfDay(for: Date())) {
                // Today: use live KPIs (0 is valid)
                intake = max(0, healthStore.todayNutritionEnergyKcal)
                active = max(0, healthStore.todayActiveEnergy)
                resting = max(0, healthStore.todayRestingEnergyKcal)
            } else {
                // Past days: use SSoT series (no guessing, no fetching)
                intake = max(0, valueForDay(
                    from: healthStore.nutritionEnergyDaily365,
                    date: day,
                    dateKey: \.date,
                    value: { $0.energyKcal },
                    calendar: cal
                ))

                active = max(0, valueForDay(
                    from: healthStore.last90DaysActiveEnergy,
                    date: day,
                    dateKey: \.date,
                    value: { $0.activeEnergy },
                    calendar: cal
                ))

                resting = max(0, valueForDay(
                    from: healthStore.last90DaysRestingEnergy,
                    date: day,
                    dateKey: \.date,
                    value: { $0.restingEnergyKcal },
                    calendar: cal
                ))
            }

            // balance semantics for diverging chart:
            // positive = surplus (intake - burned), negative = deficit
            let burned = active + resting
            let balance = intake - burned

            return EnergyBalanceTrendPointV1(
                date: day,
                balanceKcal: balance,
                hasData: true
            )
        }
    }
}
