//
//  HealthStore+MovementSplit.swift
//  GluVibProbe
//
//  Movement-Split-Logik (Sleep / Active / Sedentary) auf Tagesbasis.
//  Sleep-Split (Morning / Evening) wird hier direkt aus HealthKit
//  (sleepAnalysis-Samples) berechnet – NICHT über HealthStore+Sleep.
//
//  Active-Minuten:
//  - Preview:    previewDailyExerciseMinutes
//  - Live:       bevorzugt appleMoveTime (Move Time),
//                Fallback auf appleExerciseTime (Exercise Minutes).   // !!! NEW
//

import Foundation
import HealthKit

// MARK: - Movement Split

extension HealthStore {

    /// Liefert Movement-Split-Daten (SleepMorning / SleepEvening / Active / Sedentary)
    /// pro Tag für die letzten `days` Tage inklusive heute.
    ///
    /// Preview:
    /// - Sleep  → previewDailySleep (approx. Split)
    /// - Active → previewDailyExerciseMinutes
    ///
    /// Live:
    /// - Sleep  → exakte Sleep-Samples (HKCategoryType.sleepAnalysis)
    ///            aufgeteilt in Morning (00–12h) und Evening (18–24h)
    /// - Active → bevorzugt appleMoveTime (Move Time),
    ///            Fallback: appleExerciseTime (Exercise Minutes)       // !!! UPDATED
    /// - Sedentary = 1440 - totalSleep - Active
    func fetchMovementSplitDaily(
        last days: Int,
        completion: @escaping ([DailyMovementSplitEntry]) -> Void
    ) {
        // ✅ FIX: harte Absicherung gegen days <= 0 (sonst Trap bei reserveCapacity/stride)
        guard days > 0 else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // ... ab hier bleibt dein Code unverändert

        // ---------------------------------------
        // PREVIEW-ZWEIG
        // ---------------------------------------
        if isPreview {
            let sleepSource  = previewDailySleep
            let activeSource = previewDailyExerciseMinutes

            var result: [DailyMovementSplitEntry] = []
            result.reserveCapacity(days)

            for offset in stride(from: days - 1, through: 0, by: -1) {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

                let totalSleepMinutes: Int = {
                    if let entry = sleepSource.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                        return entry.minutes
                    } else {
                        return 0
                    }
                }()

                // Approximate-Split im Preview: max. 8h Morning, Rest Evening
                let (sleepMorning, sleepEvening) = splitSleepApprox(totalMinutes: totalSleepMinutes)

                let activeMinutesForDay: Int = {
                    if let entry = activeSource.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                        return entry.minutes
                    } else {
                        return 0
                    }
                }()

                let totalMinutes = 1440
                let sedentary = max(0, totalMinutes - totalSleepMinutes - activeMinutesForDay)

                result.append(
                    DailyMovementSplitEntry(
                        date: date,
                        sleepMorningMinutes: sleepMorning,
                        sleepEveningMinutes: sleepEvening,
                        sedentaryMinutes: sedentary,
                        activeMinutes: activeMinutesForDay
                    )
                )
            }

            DispatchQueue.main.async {
                completion(result)
            }
            return
        }

        // ---------------------------------------
        // LIVE-ZWEIG (HealthKit)
        // ---------------------------------------

        // 1) Sleep-Split (Morning / Evening) pro Tag holen
        fetchSleepSplitDaily(last: days) { [weak self] sleepPerDay in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            // 2) Move Time (Active) pro Tag holen
            self.fetchMoveTimeDaily(last: days) { movePerDay in          // !!! NEW

                // 3) Exercise Minutes pro Tag holen (Fallback)          // !!! NEW
                self.fetchExerciseMinutesDaily(last: days) { exercisePerDay in  // !!! NEW
                    let calendar = Calendar.current
                    var result: [DailyMovementSplitEntry] = []
                    result.reserveCapacity(days)

                    for offset in stride(from: days - 1, through: 0, by: -1) {
                        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                        let dayKey = calendar.startOfDay(for: date)

                        let sleepInfo = sleepPerDay[dayKey] ?? (morning: 0, evening: 0, total: 0)
                        let sleepMorning = sleepInfo.morning
                        let sleepEvening = sleepInfo.evening
                        let totalSleep   = sleepInfo.total

                        let moveMinutes      = movePerDay[dayKey] ?? 0             // !!! NEW
                        let exerciseMinutes  = exercisePerDay[dayKey] ?? 0         // !!! NEW

                        // Bevorzugt MoveTime; wenn 0, nutze Exercise Minutes        // !!! NEW
                        let activeMinutesForDay =
                            moveMinutes > 0 ? moveMinutes : exerciseMinutes        // !!! NEW

                        let totalMinutes = 1440
                        let sedentary = max(0, totalMinutes - totalSleep - activeMinutesForDay)

                        result.append(
                            DailyMovementSplitEntry(
                                date: date,
                                sleepMorningMinutes: sleepMorning,
                                sleepEveningMinutes: sleepEvening,
                                sedentaryMinutes: sedentary,
                                activeMinutes: activeMinutesForDay
                            )
                        )
                    }

                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
        }
    }

    // MARK: - Sleep-Split Helper (HealthKit-Samples)

    /// Holt Sleep-Samples (sleepAnalysis) und berechnet pro Tag:
    /// - morningMinutes: Schlafanteil im Fenster [00:00, 12:00)
    /// - eveningMinutes: Schlafanteil im Fenster [18:00, 24:00)
    /// - totalMinutes:   gesamter Schlaf 0–24h
    private func fetchSleepSplitDaily(
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
                DispatchQueue.main.async {
                    completion(result)
                }
                return
            }

            for sample in samples {

                // Nur Schlafphasen zählen (nicht "awake").
                if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                    continue
                }

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

                    // Zeitfenster für Morning / Evening
                    let morningStart = dayStart
                    let morningEnd   = calendar.date(byAdding: .hour, value: 12, to: dayStart)! // 00–12h

                    let eveningStart = calendar.date(byAdding: .hour, value: 18, to: dayStart)! // 18–24h
                    let eveningEnd   = dayEnd

                    var addMorning = 0
                    var addEvening = 0

                    // Überschneidung mit Morning-Fenster
                    let morningSegmentStart = max(current, morningStart)
                    let morningSegmentEnd   = min(segmentEnd, morningEnd)
                    if morningSegmentEnd > morningSegmentStart {
                        addMorning = Int(morningSegmentEnd.timeIntervalSince(morningSegmentStart) / 60.0)
                    }

                    // Überschneidung mit Evening-Fenster
                    let eveningSegmentStart = max(current, eveningStart)
                    let eveningSegmentEnd   = min(segmentEnd, eveningEnd)
                    if eveningSegmentEnd > eveningSegmentStart {
                        addEvening = Int(eveningSegmentEnd.timeIntervalSince(eveningSegmentStart) / 60.0)
                    }

                    var dayEntry = result[dayStart] ?? (morning: 0, evening: 0, total: 0)
                    dayEntry.morning += addMorning
                    dayEntry.evening += addEvening
                    dayEntry.total   += segmentMinutes
                    result[dayStart] = dayEntry

                    current = segmentEnd
                }
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Approx-Split für Preview

    /// einfache Aufteilung für Preview-Daten:
    /// - bis zu 8 h → Morning
    /// - Rest → Evening
    private func splitSleepApprox(totalMinutes: Int) -> (morning: Int, evening: Int) {
        guard totalMinutes > 0 else {
            return (0, 0)
        }

        let maxMorning = 8 * 60
        let morning = min(totalMinutes, maxMorning)
        let evening = max(0, totalMinutes - morning)
        return (morning, evening)
    }

    // MARK: - Move Time Helper (appleMoveTime)

    /// Holt Apple Move Time (Minuten) pro Tag für die letzten `days` Tage.
    /// Ergebnis ist ein Dictionary: startOfDay(Date) → Minuten.
    private func fetchMoveTimeDaily(
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard let moveType = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) else {
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

        var valuesPerDay: [Date: Int] = [:]

        let query = HKStatisticsCollectionQuery(
            quantityType: moveType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { completion(valuesPerDay) }
                return
            }

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let day = calendar.startOfDay(for: stats.startDate)
                valuesPerDay[day] = Int(minutes.rounded())
            }

            DispatchQueue.main.async {
                completion(valuesPerDay)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Exercise Minutes Helper (appleExerciseTime)          // !!! NEW

    /// Holt Apple Exercise Time (Trainingsminuten) pro Tag
    /// für die letzten `days` Tage.
    /// Ergebnis ist ein Dictionary: startOfDay(Date) → Minuten.
    private func fetchExerciseMinutesDaily(                             // !!! NEW
        last days: Int,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard let exerciseType = HKQuantityType.quantityType(
            forIdentifier: .appleExerciseTime
        ) else {
            completion([:])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: todayStart
        ) else {
            completion([:])
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )
        let interval = DateComponents(day: 1)

        var valuesPerDay: [Date: Int] = [:]

        let query = HKStatisticsCollectionQuery(
            quantityType: exerciseType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else {
                DispatchQueue.main.async { completion(valuesPerDay) }
                return
            }

            results.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                let day = calendar.startOfDay(for: stats.startDate)
                valuesPerDay[day] = Int(minutes.rounded())
            }

            DispatchQueue.main.async {
                completion(valuesPerDay)
            }
        }

        healthStore.execute(query)
    }
}
