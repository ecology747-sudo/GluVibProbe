//
//  NutritionEnergyViewModelV1.swift
//  GluVibProbe
//
//  V1: Nutrition Energy ViewModel
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore
//  - Targets aus SettingsModel
//  - V1 kompatibel
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class NutritionEnergyViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayKcal: Int = 0
    @Published var dailyCaloriesGoalInt: Int = 0

    @Published var todayRestingEnergyKcal: Int = 0
    @Published var todayActiveEnergyKcal: Int = 0

    @Published var last90DaysData: [DailyNutritionEnergyEntry] = []
    @Published var monthlyData: [MonthlyMetricEntry] = []
    @Published var daily365: [DailyNutritionEnergyEntry] = []

    @Published var nutritionEnergyReadAuthIssueV1: Bool = false // 🟨 NEW

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindHealthStore()
        bindSettings()
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings (SSoT → ViewModel)
    // ============================================================

    private func bindHealthStore() {

        healthStore.$todayNutritionEnergyKcal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayKcal = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysNutritionEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysData = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyNutritionEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyData = $0 }
            .store(in: &cancellables)

        healthStore.$nutritionEnergyDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.daily365 = $0 }
            .store(in: &cancellables)

        healthStore.$todayRestingEnergyKcal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayRestingEnergyKcal = $0 }
            .store(in: &cancellables)

        healthStore.$todayActiveEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayActiveEnergyKcal = $0 }
            .store(in: &cancellables)

        healthStore.$nutritionEnergyReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.nutritionEnergyReadAuthIssueV1 = $0 } // 🟨 NEW
            .store(in: &cancellables)
    }

    private func bindSettings() {

        settings.$dailyCalories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyCaloriesGoalInt = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayKcal = healthStore.todayNutritionEnergyKcal
        last90DaysData = healthStore.last90DaysNutritionEnergy
        monthlyData = healthStore.monthlyNutritionEnergy
        daily365 = healthStore.nutritionEnergyDaily365
        dailyCaloriesGoalInt = settings.dailyCalories

        todayRestingEnergyKcal = healthStore.todayRestingEnergyKcal
        todayActiveEnergyKcal = healthStore.todayActiveEnergy
        nutritionEnergyReadAuthIssueV1 = healthStore.nutritionEnergyReadAuthIssueV1 // 🟨 NEW
    }

    // ============================================================
    // MARK: - Availability (Today)
    // ============================================================

    private var hasTodayDatapoint: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let in90 = last90DaysData.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        let in365 = daily365.contains {
            calendar.isDate($0.date, inSameDayAs: today)
        }

        return in90 || in365
    }

    private var hasTodayPositiveIntake: Bool {
        todayKcal > 0
    }

    // ============================================================
    // MARK: - KPI Formatting (Goldstandard Nutrition)
    // ============================================================

    var formattedTodayKcal: String {
        guard hasTodayDatapoint || hasTodayPositiveIntake else { return "–" } // 🟨 UPDATED
        return "\(formattedNumber(todayKcal)) kcal"
    }

    var formattedDailyCaloriesGoal: String {
        "\(formattedNumber(dailyCaloriesGoalInt)) kcal"
    }

    var kpiDeltaText: String {
        guard hasTodayDatapoint || hasTodayPositiveIntake else { return "–" } // 🟨 UPDATED
        let diff = todayKcal - dailyCaloriesGoalInt
        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        return "\(sign) \(formattedNumber(abs(diff))) kcal"
    }

    var kpiDeltaColor: Color {
        guard hasTodayDatapoint || hasTodayPositiveIntake else { return Color.Glu.primaryBlue } // 🟨 UPDATED
        let diff = todayKcal - dailyCaloriesGoalInt
        if diff > 0 { return .red }
        if diff < 0 { return Color.Glu.successGreen }
        return Color.Glu.primaryBlue
    }

    // ============================================================
    // MARK: - Info Hint (Today) — Goldstandard Nutrition
    // ============================================================

    var todayInfoText: String? { // 🟨 UPDATED

        if settings.showPermissionWarnings && nutritionEnergyReadAuthIssueV1 {
            return L10n.NutritionEnergy.hintNoDataOrPermission
        }

        if hasTodayDatapoint || hasTodayPositiveIntake {
            return nil
        }

        let hasAnyHistoryPositive =
            last90DaysData.contains { $0.energyKcal > 0 } ||
            daily365.contains { $0.energyKcal > 0 }

        if !hasAnyHistoryPositive {
            return L10n.NutritionEnergy.hintNoDataOrPermission
        }

        return L10n.NutritionEnergy.hintNoToday
    }

    // ------------------------------------------------------------
    // MARK: - Burned (Active + Resting) — Anzeige-only
    // ------------------------------------------------------------

    var totalBurnedTodayKcal: Int {
        max(0, todayActiveEnergyKcal + todayRestingEnergyKcal)
    }

    var formattedTotalBurnedTodayKcal: String {
        "\(formattedNumber(totalBurnedTodayKcal)) kcal"
    }

    var formattedTodayActiveEnergyKcal: String {
        "\(formattedNumber(todayActiveEnergyKcal)) kcal"
    }

    var formattedTodayRestingEnergyKcal: String {
        "\(formattedNumber(todayRestingEnergyKcal)) kcal"
    }

    // ============================================================
    // MARK: - Period Averages
    // ============================================================

    var periodAverages: [PeriodAverageEntry] { // 🟨 UPDATED
        [
            .init(label: L10n.Common.period7d, days: 7, value: averageKcal(last: 7)),
            .init(label: L10n.Common.period14d, days: 14, value: averageKcal(last: 14)),
            .init(label: L10n.Common.period30d, days: 30, value: averageKcal(last: 30)),
            .init(label: L10n.Common.period90d, days: 90, value: averageKcal(last: 90)),
            .init(label: L10n.Common.period180d, days: 180, value: averageKcal(last: 180)),
            .init(label: L10n.Common.period365d, days: 365, value: averageKcal(last: 365))
        ]
    }

    private func averageKcal(last days: Int) -> Int {
        let source = daily365.isEmpty ? last90DaysData : daily365
        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = source.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= startDate && d <= endDate && $0.energyKcal > 0
        }

        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.energyKcal } / filtered.count
    }

    // ============================================================
    // MARK: - Chart Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(last90DaysData.map { Double($0.energyKcal) }, for: .energyDaily)
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .energyDaily)
    }

    var monthlyScale: MetricScaleResult {
        MetricScaleHelper.scale(monthlyData.map { Double($0.value) }, for: .energyMonthly)
    }

    // ============================================================
    // MARK: - Formatter
    // ============================================================

    private func formattedNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
