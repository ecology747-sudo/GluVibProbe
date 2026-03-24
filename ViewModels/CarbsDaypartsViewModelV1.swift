//
//  CarbsDaypartsViewModelV1.swift
//  GluVibProbe
//
//  Nutrition — Carb Split ViewModel (V1)
//  - NO fetch in ViewModel
//  - SSoT: HealthStore
//  - Provides:
//    - period averages for chart
//    - today + yesterday daypart grams (for time-based UI logic in the View)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class CarbsDaypartsViewModelV1: ObservableObject {

    @Published var periodAverages: [CarbsDaypartPeriodAverageEntryV1] = []

    @Published var todayMorningGrams: Int = 0
    @Published var todayAfternoonGrams: Int = 0
    @Published var todayNightGrams: Int = 0

    @Published var yesterdayMorningGrams: Int = 0
    @Published var yesterdayAfternoonGrams: Int = 0
    @Published var yesterdayNightGrams: Int = 0

    @Published var carbsReadAuthIssueV1: Bool = false // 🟨 UPDATED

    private let healthStore: HealthStore
    private let settings: SettingsModel // 🟨 UPDATED
    private var cancellables = Set<AnyCancellable>()

    private var dailyDayparts90: [DailyCarbsByDaypartEntryV1] = []

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared // 🟨 UPDATED
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindHealthStore()
        syncFromStores()
        recomputeTodayAndYesterday()
    }

    private func bindHealthStore() {

        healthStore.$carbsDaypartsPeriodAveragesV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.periodAverages = $0 }
            .store(in: &cancellables)

        healthStore.$carbsDaypartsDaily90V1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.dailyDayparts90 = $0
                self?.recomputeTodayAndYesterday()
            }
            .store(in: &cancellables)

        healthStore.$carbsReadAuthIssueV1 // 🟨 UPDATED
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.carbsReadAuthIssueV1 = $0
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        periodAverages = healthStore.carbsDaypartsPeriodAveragesV1
        dailyDayparts90 = healthStore.carbsDaypartsDaily90V1
        carbsReadAuthIssueV1 = healthStore.carbsReadAuthIssueV1 // 🟨 UPDATED
    }

    private func entry(for day: Date) -> DailyCarbsByDaypartEntryV1? {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        return dailyDayparts90.first(where: { cal.isDate($0.date, inSameDayAs: dayStart) })
    }

    private func recomputeTodayAndYesterday() {

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        let todayEntry = entry(for: todayStart)
        let yesterdayEntry = entry(for: yesterdayStart)

        todayMorningGrams = max(0, todayEntry?.morningGrams ?? 0)
        todayAfternoonGrams = max(0, todayEntry?.afternoonGrams ?? 0)
        todayNightGrams = max(0, todayEntry?.nightGrams ?? 0)

        yesterdayMorningGrams = max(0, yesterdayEntry?.morningGrams ?? 0)
        yesterdayAfternoonGrams = max(0, yesterdayEntry?.afternoonGrams ?? 0)
        yesterdayNightGrams = max(0, yesterdayEntry?.nightGrams ?? 0)
    }

    // ============================================================
    // MARK: - Goldstandard Availability / Hint Logic
    // ============================================================

    private var hasTodayDatapoint: Bool { // 🟨 UPDATED
        entry(for: Date()) != nil
    }

    private var hasAnyHistoryPositive: Bool { // 🟨 UPDATED
        dailyDayparts90.contains {
            $0.morningGrams > 0 || $0.afternoonGrams > 0 || $0.nightGrams > 0
        }
    }

    var todayInfoText: String? { // 🟨 UPDATED

        if settings.showPermissionWarnings && carbsReadAuthIssueV1 {
            return L10n.CarbsDayparts.hintNoDataOrPermission
        }

        if hasTodayDatapoint {
            return nil
        }

        if !hasAnyHistoryPositive {
            return L10n.CarbsDayparts.hintNoDataOrPermission
        }

        return L10n.CarbsDayparts.hintNoToday
    }
}
