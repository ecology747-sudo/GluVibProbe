//
//  HealthStore+MovementSplitV1.swift
//  GluVibProbe
//
//  V1: Movement Split (kein UI-Fetch, alles in HealthStore Published Values)
//  - todayMoveMinutes / todaySedentaryMinutes / todaySleepSplitMinutes
//  - movementSplitDaily365 (365er Reihe für Charts + Averages)
//
//  Regeln:
//  - Tage werden strikt im Fenster 0–24 Uhr lokaler Zeit berechnet
//  - Sleep wird über sleepAnalysis Samples berechnet und in die Kalendertage gesplittet
//  - Active = PRIORITÄT appleStandTime, Fallback: Exercise, Fallback: Workout
//  - Sedentary = minutesSoFar(today) bzw. 1440(past days) - Sleep - Active
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Movement Split (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public V1 API (Entry Points)
    // ============================================================

    func fetchMovementSplitTodayV1() {
        fetchMovementSplitDaily365V1(last: 1, completion: nil)
    }

    // ✅ UPDATED: optional completion, damit Bootstrap "awaiten" kann
    func fetchMovementSplitDaily365V1(
        last days: Int = 365,
        completion: (() -> Void)? = nil
    ) {

        // MARK: - Date Context (shared)

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // ---------------------------------------
        // MARK: - Preview
        // ---------------------------------------

        if isPreview {
            let slice = Array(previewDailyMovementSplit.suffix(days))
            DispatchQueue.main.async {

                self.movementSplitDaily365 = slice

                if let today = slice.last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
                    self.todayMoveMinutes = today.activeMinutes
                    self.todaySleepSplitMinutes = today.sleepMorningMinutes + today.sleepEveningMinutes

                    let minutesSoFar = Int(now.timeIntervalSince(todayStart) / 60.0)
                    self.todaySedentaryMinutes = max(
                        0,
                        minutesSoFar - self.todaySleepSplitMinutes - self.todayMoveMinutes
                    )

                    // !!! NEW: Preview Source (default = standTime, damit kein Hinweis erscheint)
                    self.movementSplitActiveSourceTodayV1 = (today.activeMinutes > 0 ? .standTime : .none) // !!! NEW
                } else {
                    self.todayMoveMinutes = 0
                    self.todaySleepSplitMinutes = 0
                    self.todaySedentaryMinutes = 0
                    self.movementSplitActiveSourceTodayV1 = .none                                          // !!! NEW
                }

                completion?()
            }
            return
        }

        // ---------------------------------------
        // MARK: - Orchestration (Sleep -> Stand -> Exercise -> Workout -> Merge)
        // ---------------------------------------

        fetchSleepSplitDailyV1(last: days) { [weak self] sleepPerDay in
            guard let self else { return }

            self.fetchStandMinutesDailyV1(last: days) { standPerDay in

                // ✅ MoveTime wird NICHT mehr für Active verwendet.
                self.fetchExerciseMinutesDailyV1(last: days) { exercisePerDay in

                    self.fetchWorkoutMinutesDailyV1(last: days) { workoutPerDay in

                        var out: [DailyMovementSplitEntry] = []
                        out.reserveCapacity(days)

                        // !!! NEW: Today Source merken (für UX-Hinweis / ViewModel)
                        var todaySource: MovementSplitActiveSourceTodayV1 = .none                          // !!! NEW

                        for offset in stride(from: days - 1, through: 0, by: -1) {
                            guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                            let dayKey = calendar.startOfDay(for: date)

                            let sleep = sleepPerDay[dayKey] ?? (morning: 0, evening: 0, total: 0)
                            let stand = standPerDay[dayKey] ?? 0
                            let ex    = exercisePerDay[dayKey] ?? 0
                            let wo    = workoutPerDay[dayKey] ?? 0

                            // ✅ ACTIVE PRIORITY (verbindlich, genau EINE Quelle)
                            let active: Int
                            let source: MovementSplitActiveSourceTodayV1                                     // !!! NEW

                            if stand > 0 {
                                active = stand
                                source = .standTime                                                         // !!! NEW
                            } else if ex > 0 {
                                active = ex
                                source = .exerciseMinutes                                                    // !!! NEW
                            } else if wo > 0 {
                                active = wo
                                source = .workoutMinutes                                                     // !!! NEW
                            } else {
                                active = 0
                                source = .none                                                              // !!! NEW
                            }

                            // ✅ Sedentary Logik UNVERÄNDERT (Restwert)
                            let isToday = calendar.isDate(dayKey, inSameDayAs: todayStart)
                            let minutesWindow = isToday ? Int(now.timeIntervalSince(todayStart) / 60.0) : 1440
                            let sedentary = max(0, minutesWindow - sleep.total - active)

                            out.append(
                                DailyMovementSplitEntry(
                                    date: date,
                                    sleepMorningMinutes: sleep.morning,
                                    sleepEveningMinutes: sleep.evening,
                                    sedentaryMinutes: sedentary,
                                    activeMinutes: active
                                )
                            )

                            // !!! NEW: Nur für TODAY merken (UX-Hinweis)
                            if isToday {                                                                     // !!! NEW
                                todaySource = source                                                         // !!! NEW
                            }                                                                                // !!! NEW
                        }

                        DispatchQueue.main.async {
                            self.movementSplitDaily365 = out

                            if let today = out.last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
                                self.todayMoveMinutes = today.activeMinutes
                                self.todaySleepSplitMinutes = today.sleepMorningMinutes + today.sleepEveningMinutes

                                let minutesSoFar = Int(now.timeIntervalSince(todayStart) / 60.0)
                                self.todaySedentaryMinutes = max(
                                    0,
                                    minutesSoFar - self.todaySleepSplitMinutes - self.todayMoveMinutes
                                )

                                // !!! NEW: Active Source Today publishen
                                self.movementSplitActiveSourceTodayV1 = todaySource                          // !!! NEW
                            } else {
                                self.todayMoveMinutes = 0
                                self.todaySleepSplitMinutes = 0
                                self.todaySedentaryMinutes = 0

                                // !!! NEW: fallback
                                self.movementSplitActiveSourceTodayV1 = .none                                // !!! NEW
                            }

                            completion?()
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // MARK: - Sleep Split (HealthKit)  ✅ UNVERÄNDERT
    // ============================================================

    private func fetchSleepSplitDailyV1(
        last days: Int,
        completion: @escaping ([Date: (morning: Int, evening: Int, total: Int)]) -> Void
    ) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        var result: [Date: (morning: Int, evening: Int, total: Int)] = [:]

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                DispatchQueue.main.async { completion(result) }
                return
            }

            for sample in samples {
                if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue { continue }

                let sampleStart = max(sample.startDate, startDate)
                let sampleEnd   = min(sample.endDate, now)
                if sampleEnd <= sampleStart { continue }

                var current = sampleStart

                while current < sampleEnd {
                    let dayStart = calendar.startOfDay(for: current)
                    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

                    let segmentEnd = min(sampleEnd, dayEnd)
                    if segmentEnd <= current { break }

                    let segmentMinutes = Int(segmentEnd.timeIntervalSince(current) / 60.0)

                    let morningStart = dayStart
                    let morningEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart)!

                    let eveningStart = calendar.date(byAdding: .hour, value: 18, to: dayStart)!
                    let eveningEnd = dayEnd

                    var addMorning = 0
                    var addEvening = 0

                    let mStart = max(current, morningStart)
                    let mEnd   = min(segmentEnd, morningEnd)
                    if mEnd > mStart { addMorning = Int(mEnd.timeIntervalSince(mStart) / 60.0) }

                    let eStart = max(current, eveningStart)
                    let eEnd   = min(segmentEnd, eveningEnd)
                    if eEnd > eStart { addEvening = Int(eEnd.timeIntervalSince(eStart) / 60.0) }

                    var entry = result[dayStart] ?? (morning: 0, evening: 0, total: 0)
                    entry.morning += addMorning
                    entry.evening += addEvening
                    entry.total   += segmentMinutes
                    result[dayStart] = entry

                    current = segmentEnd
                }
            }

            DispatchQueue.main.async { completion(result) }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Stand Time (appleStandTime) PRIORITY ✅ UNVERÄNDERT
    // ============================================================

    private func fetchStandMinutesDailyV1(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else {
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var values: [Date: Int] = [:]

        let query = HKStatisticsCollectionQuery(
            quantityType: standType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { completion(values) }
                return
            }

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let day = calendar.startOfDay(for: stats.startDate)
                values[day] = Int(minutes.rounded())
            }

            DispatchQueue.main.async { completion(values) }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Exercise Time (appleExerciseTime) Priority #2 ✅ UNVERÄNDERT
    // ============================================================

    private func fetchExerciseMinutesDailyV1(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard let exType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let interval = DateComponents(day: 1)

        var values: [Date: Int] = [:]

        let query = HKStatisticsCollectionQuery(
            quantityType: exType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { completion(values) }
                return
            }

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let day = calendar.startOfDay(for: stats.startDate)
                values[day] = Int(minutes.rounded())
            }

            DispatchQueue.main.async { completion(values) }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Workout Minutes (HKWorkout) Priority #3  // !!! NEW
    // ============================================================

    private func fetchWorkoutMinutesDailyV1(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        var values: [Date: Int] = [:]

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                DispatchQueue.main.async { completion(values) }
                return
            }

            for w in workouts {
                // Workout kann über Mitternacht gehen → wir splitten strikt 0–24h wie bei Sleep.
                let workoutStart = max(w.startDate, startDate)
                let workoutEnd   = min(w.endDate, now)
                if workoutEnd <= workoutStart { continue }

                var current = workoutStart
                while current < workoutEnd {
                    let dayStart = calendar.startOfDay(for: current)
                    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

                    let segmentEnd = min(workoutEnd, dayEnd)
                    if segmentEnd <= current { break }

                    let minutes = Int(segmentEnd.timeIntervalSince(current) / 60.0)
                    values[dayStart, default: 0] += max(0, minutes)

                    current = segmentEnd
                }
            }

            DispatchQueue.main.async { completion(values) }
        }

        healthStore.execute(query)
    }
}
