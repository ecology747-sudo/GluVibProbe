//
//  HealthStore+MoveTimeV1.swift
//  GluVibProbe
//
//  Domain: Activity / Move Time
//  Screen Type: HealthStore Metric Extension V1
//
//  Purpose
//  - Owns the read-only Apple Health move-time fetch pipeline for Move Time V1.
//  - Publishes today, last-90-days, monthly and 365-day move-time data into HealthStore.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT Published Move Time Values) → ViewModels → Views
//
//  Key Connections
//  - MoveTimeViewModelV1
//  - ActivityOverviewViewModelV1
//
//  Important
//  - This file is fetch-only.
//  - No read-probe lives in this file yet.
//  - Therefore there is no 7-day probe/auth-heuristic bug here.
//  - Move Time is strictly based on appleMoveTime and has no relation to
//    workout minutes, stand time or exercise time.
//

import Foundation
import HealthKit
import OSLog

// ============================================================
// MARK: - Model
// ============================================================

struct DailyMoveTimeEntry: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}

// ============================================================
// MARK: - HealthStore + Move Time
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Today / 90d / Monthly / 365)
    // ============================================================

    func fetchMoveTimeTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let value = previewDailyMoveTime // 🟨 UPDATED
                .first(where: { calendar.isDate($0.date, inSameDayAs: today) })?
                .minutes ?? 0

            DispatchQueue.main.async {
                self.todayMoveTimeMinutes = value
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) else {
            DispatchQueue.main.async {
                self.todayMoveTimeMinutes = 0
            }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let minutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0

            DispatchQueue.main.async {
                self.todayMoveTimeMinutes = Int(minutes.rounded())
            }
        }

        healthStore.execute(query)
    }

    func fetchLast90DaysMoveTimeV1() {
        fetchMoveTimeDailySeriesV1(last: 90) { [weak self] entries in
            self?.last90DaysMoveTime = entries
        }
    }

    func fetchMonthlyMoveTimeV1() {
        fetchMonthlyMoveTimeSeriesV1 { [weak self] monthly in
            self?.monthlyMoveTime = monthly
        }
    }

    func fetchMoveTimeDaily365V1() {
        fetchMoveTimeDailySeriesV1(last: 365) { [weak self] entries in
            self?.moveTimeDaily365 = entries
        }
    }

    // ============================================================
    // MARK: - Private Helpers (Daily Series / Monthly)
    // ============================================================

    private func fetchMoveTimeDailySeriesV1(
        last days: Int,
        assign: @escaping ([DailyMoveTimeEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        if isPreview {
            let entries = makePreviewDailyMoveTime(
                startDate: startDate,
                days: days
            )

            DispatchQueue.main.async { assign(entries) }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var daily: [DailyMoveTimeEntry] = []

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                daily.append(
                    DailyMoveTimeEntry(
                        date: stats.startDate,
                        minutes: Int(value.rounded())
                    )
                )
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    private func fetchMonthlyMoveTimeSeriesV1(
        assign: @escaping ([MonthlyMetricEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: startOfToday)
            ),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        if isPreview {
            let months = ["Jul", "Aug", "Sep", "Okt", "Nov"]
            let values = months.map { _ in Int.random(in: 300...2_000) }
            let entries = zip(months, values).map { month, value in
                MonthlyMetricEntry(monthShort: month, value: value)
            }

            DispatchQueue.main.async { assign(entries) }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: startOfToday,
            options: .strictStartDate
        )

        let interval = DateComponents(month: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { assign([]) }
                return
            }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))
                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: Int(minutes.rounded())
                    )
                )
            }

            DispatchQueue.main.async {
                assign(temp)
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Preview Helpers
    // ============================================================

    private func makePreviewDailyMoveTime(
        startDate: Date,
        days: Int
    ) -> [DailyMoveTimeEntry] {
        let calendar = Calendar.current

        if !previewDailyMoveTime.isEmpty { // 🟨 UPDATED
            return Array(previewDailyMoveTime.suffix(days))
                .sorted { $0.date < $1.date }
        }

        let entries: [DailyMoveTimeEntry] = (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let value = Int.random(in: 0...120)
            return DailyMoveTimeEntry(date: date, minutes: value)
        }
        .sorted { $0.date < $1.date }

        return entries
    }
}
