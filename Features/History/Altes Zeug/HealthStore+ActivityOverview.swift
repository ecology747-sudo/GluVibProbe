//
//  HealthStore+ActivityOverview.swift
//  GluVibProbe
//
//  Spezielle Helper für die ActivityOverview:
//  - Tageswerte für Exercise Minutes / Active Energy (für Today / Yesterday / DayBefore)
//  - 7-Tage-Durchschnitt für Exercise Minutes
//  - 7-Tage-Durchschnitt für Active Energy
//  - Letzte Workouts für "Last Exercise"
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - Tageswerte für ActivityOverview (wie BodyOverview)   // !!! NEW
    // ============================================================

    /// Liefert die Exercise-Minuten (appleExerciseTime) für einen
    /// bestimmten Kalendertag. Wird von der ActivityOverview genutzt,
    /// um Today / Yesterday / DayBefore sauber zu befüllen.
    ///
    /// Annahme:
    /// - `last90DaysExerciseMinutes` ist ein bestehendes Cache-Array,
    ///   das beim App-Start / Refresh mit Tageswerten befüllt wird
    ///   (analog zu BodyOverview).
    func exerciseMinutes(for date: Date) -> Int {                   // !!! NEW
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        guard let entry = last90DaysExerciseMinutes.first(where: { entry in
            calendar.isDate(entry.date, inSameDayAs: targetDay)
        }) else {
            return 0
        }

        return entry.minutes
    }

    /// Liefert die Active Energy (kcal) für einen bestimmten Kalendertag.
    /// Basis ist das bestehende Tages-Array `last90DaysActiveEnergy`,
    /// das du bereits in der Activity-Domain nutzt.
    func activeEnergyKcal(for date: Date) -> Int {                  // !!! NEW
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        guard let entry = last90DaysActiveEnergy.first(where: { entry in
            calendar.isDate(entry.date, inSameDayAs: targetDay)
        }) else {
            return 0
        }

        return entry.activeEnergy
    }

    // ============================================================
    // MARK: - 7-Tage-Durchschnitt (CACHE-BASED, no HealthKit query) // !!! NEW
    // ============================================================

    /// 7-Tage-Ø Exercise Minutes aus dem Cache `last90DaysExerciseMinutes`
    /// - KEIN HealthKit Query
    /// - Leere Tage zählen als 0
    func sevenDayAverageExerciseMinutesFromCache(endingOn date: Date) -> Int {     // !!! NEW
        let calendar = Calendar.current
        let today = Date()
        let endDay = calendar.startOfDay(for: min(date, today))

        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else {
            return 0
        }

        var sum = 0
        var dayCount = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            sum += exerciseMinutes(for: day)  // nutzt Helper oben
            dayCount += 1
        }

        guard dayCount > 0 else { return 0 }
        return Int((Double(sum) / Double(dayCount)).rounded())
    }

    /// 7-Tage-Ø Active Energy (kcal) aus dem Cache `last90DaysActiveEnergy`
    /// - KEIN HealthKit Query
    /// - Leere Tage zählen als 0
    func sevenDayAverageActiveEnergyKcalFromCache(endingOn date: Date) -> Int {    // !!! NEW
        let calendar = Calendar.current
        let today = Date()
        let endDay = calendar.startOfDay(for: min(date, today))

        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else {
            return 0
        }

        var sum = 0
        var dayCount = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            sum += activeEnergyKcal(for: day) // nutzt Helper oben
            dayCount += 1
        }

        guard dayCount > 0 else { return 0 }
        return Int((Double(sum) / Double(dayCount)).rounded())
    }

    // ============================================================
    // MARK: - 7-Tage-Durchschnitt (HealthKit Query)  (optional)
    // ============================================================

    /// 7-Tage-Durchschnitt der Exercise Minutes (Minuten),
    /// endend am übergebenen Datum (max. heute).
    ///
    /// - Hinweis: Wenn das Datum in der Zukunft liegt, wird bis „heute“
    ///   ausgewertet. Leere Tage zählen mit 0 Minuten in den Durchschnitt.
    func fetchSevenDayAverageExerciseMinutes(endingOn date: Date) async -> Int {
        await withCheckedContinuation { continuation in

            guard let exerciseType = HKQuantityType.quantityType(
                forIdentifier: .appleExerciseTime
            ) else {
                continuation.resume(returning: 0)
                return
            }

            let calendar = Calendar.current
            let today = Date()
            let endDay = min(date, today)

            let endOfDay = calendar.date(
                byAdding: DateComponents(day: 1, second: -1),
                to: calendar.startOfDay(for: endDay)
            ) ?? endDay

            guard let startDay = calendar.date(
                byAdding: .day,
                value: -6,
                to: calendar.startOfDay(for: endDay)
            ) else {
                continuation.resume(returning: 0)
                return
            }

            let predicate = HKQuery.predicateForSamples(
                withStart: startDay,
                end: endOfDay,
                options: []
            )

            let interval = DateComponents(day: 1)

            var totalMinutes: Double = 0
            var dayCount: Int = 0

            let query = HKStatisticsCollectionQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDay,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: 0)
                    return
                }

                results.enumerateStatistics(from: startDay, to: endOfDay) { stats, _ in
                    let minutes = stats.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                    totalMinutes += minutes
                    dayCount += 1
                }

                let avg = dayCount > 0
                    ? Int((totalMinutes / Double(dayCount)).rounded())
                    : 0

                continuation.resume(returning: avg)
            }

            healthStore.execute(query)
        }
    }

    /// 7-Tage-Durchschnitt der Active Energy (kcal),
    /// endend am übergebenen Datum (max. heute).
    ///
    /// Nutzt deine bestehende Daily-Logik:
    ///   fetchActiveEnergyDaily(last:)
    func fetchSevenDayAverageActiveEnergy(endingOn date: Date) async -> Int {
        await withCheckedContinuation { continuation in

            self.fetchActiveEnergyDaily(last: 30) { entries in
                let calendar = Calendar.current
                let today = Date()
                let endDay = calendar.startOfDay(for: min(date, today))

                guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else {
                    continuation.resume(returning: 0)
                    return
                }

                let filtered = entries.filter { entry in
                    let day = calendar.startOfDay(for: entry.date)
                    return day >= startDay && day <= endDay
                }

                guard !filtered.isEmpty else {
                    continuation.resume(returning: 0)
                    return
                }

                let sum = filtered.reduce(0) { partial, entry in
                    partial + entry.activeEnergy
                }

                let avg = sum / filtered.count
                continuation.resume(returning: avg)
            }
        }
    }

    // ============================================================
    // MARK: - Letzte Workouts für "Last Exercise"
    // ============================================================

    /// Liefert die letzten `limit` Workouts aus HealthKit,
    /// sortiert nach Startdatum (neueste zuerst).
    func fetchRecentWorkouts(limit: Int) async -> [HKWorkout] {
        if isPreview {
            return []
        }

        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()

            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: false
            )

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in

                if let error = error {
                    print("⚠️ fetchRecentWorkouts error:", error.localizedDescription)
                    continuation.resume(returning: [])
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            self.healthStore.execute(query)
        }
    }
}
