//
//  HealthStore+MoveTimeV1.swift
//  GluVibProbe
//
//  Move Time V1
//  ------------------------------------------------------------
//  - Fetch-only
//  - Liest appleMoveTime aus HealthKit
//  - Schreibt rohe Tages-Zeitreihen in HealthStore Published Properties
//
//  ✅ Diese Datei liefert:
//  - Move Time (Minuten) = Alltagsbewegung / "Move Time"
//
//  ❌ Kein Bezug zu:
//  - Workouts (TrainingMinutes)
//  - Stand Time
//  - Exercise Time (appleExerciseTime)
//

import Foundation
import HealthKit

// ============================================================
// MARK: - Model (V1)
// ============================================================

struct DailyMoveTimeEntry: Identifiable {                                  // !!! NEW
    let id = UUID()                                                        // !!! NEW
    let date: Date                                                         // !!! NEW
    let minutes: Int                                                       // !!! NEW
}

// ============================================================
// MARK: - HealthStore + Move Time (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points)
    // ============================================================

    /// Today (since midnight) → writes into `todayMoveTimeMinutes`
    func fetchMoveTimeTodayV1() {                                          // !!! NEW
        if isPreview {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // ✅ FIX #2: Preview nutzt NICHT mehr previewDailyMovementSplit,
            // sondern die eigene Preview-Serie previewDailyMoveTime.
            let value = previewDailyMoveTime                               // !!! FIX
                .first(where: { calendar.isDate($0.date, inSameDayAs: today) })?
                .minutes ?? 0

            DispatchQueue.main.async {
                self.todayMoveTimeMinutes = value
            }
            return
        }

        guard let type = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) else { return }

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

    /// Last 90d → writes into `last90DaysMoveTime`
    func fetchLast90DaysMoveTimeV1() {                                     // !!! NEW
        fetchMoveTimeDailySeriesV1(last: 90) { [weak self] entries in       // !!! UPDATED (struktur)
            self?.last90DaysMoveTime = entries
        }
    }

    /// Monthly (last 5 months) → writes into `monthlyMoveTime`
    func fetchMonthlyMoveTimeV1() {                                        // !!! NEW
        fetchMonthlyMoveTimeSeriesV1 { [weak self] monthly in               // !!! UPDATED (struktur)
            self?.monthlyMoveTime = monthly
        }
    }

    /// Daily 365 → writes into `moveTimeDaily365`
    func fetchMoveTimeDaily365V1() {                                       // !!! NEW
        fetchMoveTimeDailySeriesV1(last: 365) { [weak self] entries in      // !!! UPDATED (struktur)
            self?.moveTimeDaily365 = entries
        }
    }

    // ============================================================
    // MARK: - Private Helpers (Series Fetch)
    // ============================================================

    /// Tägliche Move-Time Serie für die letzten `days` Tage (0–24 Uhr)
    private func fetchMoveTimeDailySeriesV1(                               // !!! NEW (struktur)
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

        // Preview
        if isPreview {
            let entries: [DailyMoveTimeEntry] = makePreviewDailyMoveTime(   // !!! NEW (struktur)
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

    /// Monthly aggregation (last 5 months)
    private func fetchMonthlyMoveTimeSeriesV1(                             // !!! NEW (struktur)
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

        // Preview
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

    private func makePreviewDailyMoveTime(                                // !!! NEW (struktur)
        startDate: Date,
        days: Int
    ) -> [DailyMoveTimeEntry] {

        let calendar = Calendar.current

        // ✅ Wenn echte Preview-Daten existieren, nutze sie (stabil)
        if !previewDailyMoveTime.isEmpty {                                 // !!! FIX
            return Array(previewDailyMoveTime.suffix(days))
                .sorted { $0.date < $1.date }
        }

        // Fallback: generiere Dummy-Daten
        let entries: [DailyMoveTimeEntry] = (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let value = Int.random(in: 0...120)
            return DailyMoveTimeEntry(date: date, minutes: value)
        }
        .sorted { $0.date < $1.date }

        return entries
    }
}
