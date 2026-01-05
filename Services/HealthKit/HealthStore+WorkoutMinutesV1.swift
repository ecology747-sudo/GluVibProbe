//
//  HealthStore+WorkoutMinutesV1.swift
//  GluVibProbe
//
//  Workout Minutes V1
//  ------------------------------------------------------------
//  - Fetch-only
//  - Liest NUR HKWorkout.duration (Minuten)
//  - SSoT: HealthStore Published Properties
//
//  ✅ Metric: "Workout Minutes"
//  ✅ Quelle: HKWorkout
//
//  ❌ Kein Bezug zu:
//  - Bewegungsminuten / Trainingsminuten (Apple Health UI)
//  - appleMoveTime / appleStandTime / appleExerciseTime
//

import Foundation
import HealthKit

// ============================================================
// MARK: - Model (V1)
// ============================================================

struct DailyWorkoutMinutesEntry: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}

// ============================================================
// MARK: - HealthStore + Workout Minutes (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Points)
    // ============================================================

    /// Today (since midnight) → writes into `todayWorkoutMinutes`
    func fetchWorkoutMinutesTodayV1() {
        if isPreview {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            let value = previewDailyWorkoutMinutes
                .first(where: { calendar.isDate($0.date, inSameDayAs: today) })?
                .minutes ?? 0

            DispatchQueue.main.async { self.todayWorkoutMinutes = value }
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

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            guard let self else { return }
            let workouts = (samples as? [HKWorkout]) ?? []
            let minutes = workouts.reduce(0) { $0 + Int(($1.duration / 60.0).rounded()) }

            DispatchQueue.main.async {
                self.todayWorkoutMinutes = max(0, minutes)
            }
        }

        healthStore.execute(query)
    }

    /// Last 90d → writes into `last90DaysWorkoutMinutes`
    func fetchLast90DaysWorkoutMinutesV1() {
        fetchWorkoutMinutesDailySeriesV1(last: 90) { [weak self] entries in
            self?.last90DaysWorkoutMinutes = entries
        }
    }

    /// Monthly (last 5 months) → writes into `monthlyWorkoutMinutes`
    func fetchMonthlyWorkoutMinutesV1() {
        fetchMonthlyWorkoutMinutesSeriesV1 { [weak self] monthly in
            self?.monthlyWorkoutMinutes = monthly
        }
    }

    /// Daily 365 → writes into `workoutMinutesDaily365`
    func fetchWorkoutMinutesDaily365V1() {
        fetchWorkoutMinutesDailySeriesV1(last: 365) { [weak self] entries in
            self?.workoutMinutesDaily365 = entries
        }
    }

    // ============================================================
    // MARK: - NEW: Metabolic MainChart Activity Overlay (RAW3DAYS)
    // ============================================================

    /// RAW3DAYS (Today/Yesterday/DayBefore) → writes into `activityEvents3Days`
    ///
    /// Zweck:
    /// - MainChart benötigt Start/Ende (Balken)
    /// - Quelle: HKWorkout.startDate / endDate
    ///
    /// Output:
    /// - activityEvents3Days: [ActivityOverlayEvent]  (aus MetabolicRawModelsV1.swift)
    func fetchActivityEvents3DaysV1() { // NEW
        if isPreview {
            let cal = Calendar.current
            let now = Date()
            let todayStart = cal.startOfDay(for: now)

            // simple preview: 2 workouts today, 1 yesterday
            let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

            let mock: [ActivityOverlayEvent] = [
                .init(id: UUID(), start: cal.date(byAdding: .hour, value: 7, to: todayStart) ?? now,
                      end: cal.date(byAdding: .hour, value: 8, to: todayStart) ?? now, kind: .workout),
                .init(id: UUID(), start: cal.date(byAdding: .hour, value: 18, to: todayStart) ?? now,
                      end: cal.date(byAdding: .hour, value: 19, to: todayStart) ?? now, kind: .workout),
                .init(id: UUID(), start: cal.date(byAdding: .hour, value: 12, to: yesterdayStart) ?? now,
                      end: cal.date(byAdding: .hour, value: 13, to: yesterdayStart) ?? now, kind: .workout)
            ]

            DispatchQueue.main.async { self.activityEvents3Days = mock.sorted { $0.start < $1.start } }
            return
        }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)

        // Start = DayBefore 00:00 (also 2 Tage zurück, inkl. heute => 3 Kalendertage)
        let dayBeforeStart = cal.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart

        let predicate = HKQuery.predicateForSamples(withStart: dayBeforeStart, end: now, options: [])

        let sort = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        ]

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let workouts = (samples as? [HKWorkout]) ?? []

            let mapped: [ActivityOverlayEvent] = workouts.map { w in
                ActivityOverlayEvent(
                    id: UUID(),
                    start: w.startDate,
                    end: w.endDate,
                    kind: .workout
                )
            }

            DispatchQueue.main.async {
                self.activityEvents3Days = mapped.sorted { $0.start < $1.start }
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Private Helpers (Daily Series)
    // ============================================================

    private func fetchWorkoutMinutesDailySeriesV1(
        last days: Int,
        assign: @escaping ([DailyWorkoutMinutesEntry]) -> Void
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
            let entries = makePreviewDailyWorkoutMinutes(startDate: startDate, days: days)
            DispatchQueue.main.async { assign(entries) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            let workouts = (samples as? [HKWorkout]) ?? []
            var bucket: [Date: Int] = [:]

            for w in workouts {
                let day = calendar.startOfDay(for: w.startDate)
                let m = Int((w.duration / 60.0).rounded())
                bucket[day, default: 0] += max(0, m)
            }

            var result: [DailyWorkoutMinutesEntry] = []
            result.reserveCapacity(days)

            for offset in 0..<days {
                guard let d = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
                let day = calendar.startOfDay(for: d)
                result.append(.init(date: day, minutes: bucket[day] ?? 0))
            }

            DispatchQueue.main.async {
                assign(result.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Private Helpers (Monthly)
    // ============================================================

    private func fetchMonthlyWorkoutMinutesSeriesV1(
        assign: @escaping ([MonthlyMetricEntry]) -> Void
    ) {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        guard
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfToday)),
            let startDate = calendar.date(byAdding: .month, value: -4, to: currentMonth)
        else {
            DispatchQueue.main.async { assign([]) }
            return
        }

        // Preview
        if isPreview {
            let months = ["Jul", "Aug", "Sep", "Okt", "Nov"]
            let values = months.map { _ in Int.random(in: 0...1_200) }
            let entries = zip(months, values).map { MonthlyMetricEntry(monthShort: $0.0, value: $0.1) }
            DispatchQueue.main.async { assign(entries) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: startOfToday, options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in

            let workouts = (samples as? [HKWorkout]) ?? []
            var bucket: [Date: Int] = [:]

            for w in workouts {
                let comps = calendar.dateComponents([.year, .month], from: w.startDate)
                guard let monthAnchor = calendar.date(from: comps) else { continue }
                let m = Int((w.duration / 60.0).rounded())
                bucket[monthAnchor, default: 0] += max(0, m)
            }

            var monthly: [MonthlyMetricEntry] = []
            monthly.reserveCapacity(5)

            for i in 0...4 {
                guard let d = calendar.date(byAdding: .month, value: i, to: startDate) else { continue }
                let monthAnchor = calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? d
                let label = monthAnchor.formatted(.dateTime.month(.abbreviated))
                monthly.append(.init(monthShort: label, value: bucket[monthAnchor] ?? 0))
            }

            DispatchQueue.main.async { assign(monthly) }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Preview Helpers
    // ============================================================

    private func makePreviewDailyWorkoutMinutes(
        startDate: Date,
        days: Int
    ) -> [DailyWorkoutMinutesEntry] {

        let calendar = Calendar.current

        if !previewDailyWorkoutMinutes.isEmpty {
            return Array(previewDailyWorkoutMinutes.suffix(days))
                .sorted { $0.date < $1.date }
        }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return DailyWorkoutMinutesEntry(
                date: calendar.startOfDay(for: date),
                minutes: Int.random(in: 0...80)
            )
        }
        .sorted { $0.date < $1.date }
    }
}
