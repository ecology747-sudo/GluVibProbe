//
//  HealthStore+ExerciseMinutes.swift
//  GluVibProbe
//
//  Exercise Minutes-Logik ausgelagert aus HealthStore.swift
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - EXERCISE MINUTES (Apple Exercise Time)
    // ============================================================

    /// Lädt die Exercise Minutes für **heute** (seit Mitternacht) aus HealthKit.
    /// Ergebnis wird in Minuten als Int zurückgegeben.
    func fetchExerciseMinutesToday(                                   // !!! NEW
        completion: @escaping (Int) -> Void                           // !!! NEW
    ) {                                                               // !!! NEW
        // Typ für Apple Exercise Time (Bewegungsring "Trainingsminuten")
        guard let exerciseType = HKQuantityType.quantityType(         // !!! NEW
            forIdentifier: .appleExerciseTime                         // !!! NEW
        ) else {                                                      // !!! NEW
            completion(0)                                             // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        let calendar = Calendar.current                               // !!! NEW
        let now = Date()                                              // !!! NEW
        let startOfDay = calendar.startOfDay(for: now)                // !!! NEW

        // Alle Exercise-Samples seit Mitternacht bis jetzt
        let predicate = HKQuery.predicateForSamples(                  // !!! NEW
            withStart: startOfDay,                                    // !!! NEW
            end: now,                                                 // !!! NEW
            options: .strictStartDate                                 // !!! NEW
        )                                                             // !!! NEW

        let query = HKStatisticsQuery(                                // !!! NEW
            quantityType: exerciseType,                               // !!! NEW
            quantitySamplePredicate: predicate,                       // !!! NEW
            options: .cumulativeSum                                   // !!! NEW
        ) { _, result, _ in                                           // !!! NEW
            // HealthKit speichert Exercise Time als Zeit-Einheit.    // !!! NEW
            // Wir lesen sie als Minuten aus.                         // !!! NEW
            let minutes = result?.sumQuantity()?                      // !!! NEW
                .doubleValue(for: .minute()) ?? 0                     // !!! NEW

            DispatchQueue.main.async {                                // !!! NEW
                completion(Int(minutes.rounded()))                    // !!! NEW
            }                                                         // !!! NEW
        }                                                             // !!! NEW

        healthStore.execute(query)                                    // !!! NEW
    }                                                                 // !!! NEW

    /// Hilfsfunktion: tägliche Exercise Minutes für die letzten days Tage.
    private func fetchExerciseMinutesLastNDays(                       // !!! NEW
        days: Int,                                                    // !!! NEW
        completion: @escaping ([DailyExerciseMinutesEntry]) -> Void   // !!! NEW
    ) {                                                               // !!! NEW
        guard let exerciseType = HKQuantityType.quantityType(         // !!! NEW
            forIdentifier: .appleExerciseTime                         // !!! NEW
        ) else {                                                      // !!! NEW
            completion([])                                            // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        let calendar = Calendar.current                               // !!! NEW
        let now = Date()                                              // !!! NEW
        let todayStart = calendar.startOfDay(for: now)                // !!! NEW

        // Startdatum = (days - 1) Tage vor heute (inkl. heute)
        guard let startDate = calendar.date(                          // !!! NEW
            byAdding: .day,                                           // !!! NEW
            value: -(days - 1),                                       // !!! NEW
            to: todayStart                                            // !!! NEW
        ) else {                                                      // !!! NEW
            completion([])                                            // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        // Wenn wir im Preview-Modus sind → Fake-Daten generieren,
        // damit keine HealthKit-Abfragen im Preview laufen.
        if isPreview {                                                // !!! NEW
            let entries: [DailyExerciseMinutesEntry] = (0..<days)     // !!! NEW
                .compactMap { offset in                               // !!! NEW
                    guard let date = calendar.date(                   // !!! NEW
                        byAdding: .day,                               // !!! NEW
                        value: offset,                                // !!! NEW
                        to: startDate                                 // !!! NEW
                    ) else {                                          // !!! NEW
                        return nil                                    // !!! NEW
                    }                                                 // !!! NEW
                    // Beispiel: 10–60 Minuten Trainingszeit pro Tag  // !!! NEW
                    let value = Int.random(in: 10...60)               // !!! NEW
                    return DailyExerciseMinutesEntry(                 // !!! NEW
                        date: date,                                   // !!! NEW
                        minutes: value                                // !!! NEW
                    )                                                 // !!! NEW
                }                                                     // !!! NEW
                .sorted { $0.date < $1.date }                         // !!! NEW

            DispatchQueue.main.async {                                // !!! NEW
                completion(entries)                                   // !!! NEW
            }                                                         // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        let predicate = HKQuery.predicateForSamples(                  // !!! NEW
            withStart: startDate,                                     // !!! NEW
            end: now,                                                 // !!! NEW
            options: []                                               // !!! NEW
        )                                                             // !!! NEW

        var daily: [DailyExerciseMinutesEntry] = []                   // !!! NEW
        let interval = DateComponents(day: 1)                         // !!! NEW

        let query = HKStatisticsCollectionQuery(                      // !!! NEW
            quantityType: exerciseType,                               // !!! NEW
            quantitySamplePredicate: predicate,                       // !!! NEW
            options: .cumulativeSum,                                  // !!! NEW
            anchorDate: startDate,                                    // !!! NEW
            intervalComponents: interval                              // !!! NEW
        )                                                             // !!! NEW

        query.initialResultsHandler = { _, results, _ in              // !!! NEW
            results?.enumerateStatistics(from: startDate, to: now) {  // !!! NEW
                stats, _ in                                           // !!! NEW
                let minutes = stats.sumQuantity()?                    // !!! NEW
                    .doubleValue(for: .minute()) ?? 0                 // !!! NEW

                let entry = DailyExerciseMinutesEntry(                // !!! NEW
                    date: stats.startDate,                            // !!! NEW
                    minutes: Int(minutes.rounded())                   // !!! NEW
                )                                                     // !!! NEW
                daily.append(entry)                                   // !!! NEW
            }                                                         // !!! NEW

            let sorted = daily.sorted { $0.date < $1.date }           // !!! NEW

            DispatchQueue.main.async {                                // !!! NEW
                completion(sorted)                                    // !!! NEW
            }                                                         // !!! NEW
        }                                                             // !!! NEW

        healthStore.execute(query)                                    // !!! NEW
    }                                                                 // !!! NEW

    /// Öffentliche API: tägliche Exercise Minutes für die letzten days Tage.
    /// Wird später vom ViewModel genutzt (z. B. für Last-90-Days-Chart).
    func fetchExerciseMinutesDaily(                                   // !!! NEW
        last days: Int,                                               // !!! NEW
        completion: @escaping ([DailyExerciseMinutesEntry]) -> Void   // !!! NEW
    ) {                                                               // !!! NEW
        fetchExerciseMinutesLastNDays(days: days, completion: completion)
    }                                                                 // !!! NEW

    /// Convenience: direkt "letzte 90 Tage" laden.
    func fetchLast90DaysExerciseMinutes(                              // !!! NEW
        completion: @escaping ([DailyExerciseMinutesEntry]) -> Void   // !!! NEW
    ) {                                                               // !!! NEW
        fetchExerciseMinutesDaily(last: 90, completion: completion)   // !!! NEW
    }                                                                 // !!! NEW

    /// Aggregiert Exercise Minutes pro Monat für ein Monthly-Chart.
    func fetchMonthlyExerciseMinutes(                                 // !!! NEW
        completion: @escaping ([MonthlyMetricEntry]) -> Void          // !!! NEW
    ) {                                                               // !!! NEW
        guard let exerciseType = HKQuantityType.quantityType(         // !!! NEW
            forIdentifier: .appleExerciseTime                         // !!! NEW
        ) else {                                                      // !!! NEW
            completion([])                                            // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        let calendar = Calendar.current                               // !!! NEW
        let today = Date()                                            // !!! NEW
        let startOfToday = calendar.startOfDay(for: today)            // !!! NEW

        // Start = Anfang des Monats, 4 Monate zurück (insgesamt 5 Monate)
        guard let currentMonth = calendar.date(                       // !!! NEW
            from: calendar.dateComponents([.year, .month],            // !!! NEW
                                          from: startOfToday)         // !!! NEW
        ), let startDate = calendar.date(                             // !!! NEW
            byAdding: .month,                                         // !!! NEW
            value: -4,                                                // !!! NEW
            to: currentMonth                                          // !!! NEW
        ) else {                                                      // !!! NEW
            completion([])                                            // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        let predicate = HKQuery.predicateForSamples(                  // !!! NEW
            withStart: startDate,                                     // !!! NEW
            end: startOfToday,                                        // !!! NEW
            options: .strictStartDate                                 // !!! NEW
        )                                                             // !!! NEW

        let interval = DateComponents(month: 1)                       // !!! NEW

        // Für Previews können wir auf HealthKit verzichten
        if isPreview {                                                // !!! NEW
            let months = ["Jul", "Aug", "Sep", "Okt", "Nov"]          // !!! NEW
            let values = months.map { _ in                            // !!! NEW
                Int.random(in: 600...2_000)                           // !!! NEW
            }                                                         // !!! NEW

            let entries = zip(months, values).map { month, value in   // !!! NEW
                MonthlyMetricEntry(monthShort: month, value: value)   // !!! NEW
            }                                                         // !!! NEW

            DispatchQueue.main.async {                                // !!! NEW
                completion(entries)                                   // !!! NEW
            }                                                         // !!! NEW
            return                                                    // !!! NEW
        }                                                             // !!! NEW

        let query = HKStatisticsCollectionQuery(                      // !!! NEW
            quantityType: exerciseType,                               // !!! NEW
            quantitySamplePredicate: predicate,                       // !!! NEW
            options: .cumulativeSum,                                  // !!! NEW
            anchorDate: startDate,                                    // !!! NEW
            intervalComponents: interval                              // !!! NEW
        )                                                             // !!! NEW

        query.initialResultsHandler = { _, results, _ in              // !!! NEW
            guard let results = results else {                        // !!! NEW
                DispatchQueue.main.async {                            // !!! NEW
                    completion([])                                    // !!! NEW
                }                                                     // !!! NEW
                return                                                // !!! NEW
            }                                                         // !!! NEW

            var temp: [MonthlyMetricEntry] = []                       // !!! NEW

            results.enumerateStatistics(from: startDate,              // !!! NEW
                                        to: startOfToday) {           // !!! NEW
                stats, _ in                                           // !!! NEW
                let minutes = stats.sumQuantity()?                    // !!! NEW
                    .doubleValue(for: .minute()) ?? 0                 // !!! NEW
                let monthShort = stats.startDate                      // !!! NEW
                    .formatted(.dateTime.month(.abbreviated))         // !!! NEW

                temp.append(                                          // !!! NEW
                    MonthlyMetricEntry(                               // !!! NEW
                        monthShort: monthShort,                       // !!! NEW
                        value: Int(minutes.rounded())                 // !!! NEW
                    )                                                 // !!! NEW
                )                                                     // !!! NEW
            }                                                         // !!! NEW

            DispatchQueue.main.async {                                // !!! NEW
                completion(temp)                                      // !!! NEW
            }                                                         // !!! NEW
        }                                                             // !!! NEW

        healthStore.execute(query)                                    // !!! NEW
    }                                                                 // !!! NEW
}
