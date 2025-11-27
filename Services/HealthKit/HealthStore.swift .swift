//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore: ObservableObject {

    // Singleton-Instanz für die App
    static let shared = HealthStore()

    private let healthStore = HKHealthStore()
    private let isPreview: Bool

    // Standard-Init für die App (HealthKit aktiv)
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    // MARK: - Published Values für SwiftUI

    /// Schritte heute
    @Published var todaySteps: Int = 0

    /// Tägliche Schritte der letzten 90 Tage (für aktuellen Chart)
    @Published var last90Days: [DailyStepsEntry] = []

    /// Monatliche Schritt-Summen (letzte 5 Monate inkl. aktuellem Monat)
    @Published var monthlySteps: [MonthlyMetricEntry] = []
    
    // Nur für Xcode-Previews: vordefinierte Tageswerte (bis 365 Tage)
    private var previewDailySteps: [DailyStepsEntry] = []

    // MARK: - Permission Request

    func requestAuthorization() {
        // Im Preview KEIN HealthKit-Aufruf → Demo-Daten bleiben erhalten
        if isPreview {
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        healthStore.requestAuthorization(
            toShare: [],
            read: [stepType]
        ) { success, error in
            if success {
                // Schritte nach erfolgreicher Auth laden
                self.fetchStepsToday()
                self.fetchLast90Days()
                self.fetchMonthlySteps()
            } else {
                print("HealthKit Auth fehlgeschlagen:", error?.localizedDescription ?? "unbekannt")
            }
        }
    }

    // MARK: - Heute: Schritte

    func fetchStepsToday() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in

            let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0

            DispatchQueue.main.async {
                self.todaySteps = Int(value)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Helper: Letzte N Tage (tägliche Buckets, zeitzonensicher)

    private func fetchLastNDays(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyStepsEntry]) -> Void
    ) {
        let calendar = Calendar.current

        // Aktueller Zeitpunkt (jetzt)
        let now = Date()
        // Heute, 00:00 lokale Zeit
        let todayStart = calendar.startOfDay(for: now)

        // Start vor (days - 1) Tagen, ebenfalls 00:00
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return
        }

        // Alle Samples von startDate bis JETZT
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        var daily: [DailyStepsEntry] = []
        let interval = DateComponents(day: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            results?.enumerateStatistics(from: startDate, to: now) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0

                daily.append(
                    DailyStepsEntry(
                        date: stats.startDate, // 00:00 dieses Tages
                        steps: Int(value)      // Summe bis zum Ende des Buckets (heute = bis jetzt)
                    )
                )
            }

            DispatchQueue.main.async {
                assign(daily.sorted { $0.date < $1.date })
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Generic Steps: Letzte N Tage (öffentlich für ViewModels)

    // MARK: - Generic Steps: Letzte N Tage (öffentlich für ViewModels)

    /// Liefert tägliche Schrittwerte für die letzten `days` Tage.
    /// In der echten App → HealthKit-Abfrage.
    /// In der Preview → benutzt `previewDailySteps`.
    func fetchStepsDaily(
        last days: Int,
        assign: @escaping ([DailyStepsEntry]) -> Void
    ) {
        // 🔸 Xcode-Preview: benutze vorbereitete Demo-Daten
        if isPreview {
            let base = previewDailySteps

            let count = min(days, base.count)
            let slice = count > 0 ? Array(base.suffix(count)) : []

            DispatchQueue.main.async {
                assign(slice)
            }
            return
        }

        // 🔸 Echte App: HealthKit-Abfrage
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        fetchLastNDays(
            quantityType: stepType,
            unit: .count(),
            days: days,
            assign: assign
        )
    }

    // MARK: - Letzte 90 Tage (täglich) – Schritte (Komfort-Wrapper für aktuellen Chart)

    func fetchLast90Days() {
        fetchStepsDaily(last: 90) { [weak self] entries in
            self?.last90Days = entries
        }
    }

    // MARK: - Monatliche Schritte (letzte 5 Monate inkl. aktuellem Monat)

    func fetchMonthlySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // sauberer Monatsanfang
        guard let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: startOfToday)
        ) else { return }

        // Start vor 4 Monaten
        guard let startDate = calendar.date(
            byAdding: .month, value: -4, to: startOfCurrentMonth
        ) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: startOfToday,
            options: .strictStartDate
        )

        let interval = DateComponents(month: 1)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            guard let results else { return }

            var temp: [MonthlyMetricEntry] = []

            results.enumerateStatistics(from: startDate, to: startOfToday) { stats, _ in
                let value = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let monthShort = stats.startDate.formatted(.dateTime.month(.abbreviated))

                temp.append(
                    MonthlyMetricEntry(
                        monthShort: monthShort,
                        value: Int(value)
                    )
                )
            }

            DispatchQueue.main.async {
                self.monthlySteps = temp
            }
        }

        healthStore.execute(query)
    }
}

// MARK: - Preview Store (Demo-Daten, KEIN HealthKit)

extension HealthStore {
    static func preview() -> HealthStore {
        let store = HealthStore(isPreview: true)

        // Schritte (Demo)
        store.todaySteps = 8_532

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Demo 365 days – Basis für alle Durchschnitte
        store.previewDailySteps = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailyStepsEntry(date: d, steps: Int.random(in: 3_000...12_000))
        }.sorted { $0.date < $1.date }

        // Demo 90 days – Schritte (kann aus previewDailySteps kommen, muss aber nicht)
        store.last90Days = Array(store.previewDailySteps.suffix(90))

        // Demo monthly data – Schritte
        store.monthlySteps = [
            MonthlyMetricEntry(monthShort: "Jul", value: 140_000),
            MonthlyMetricEntry(monthShort: "Aug", value: 152_000),
            MonthlyMetricEntry(monthShort: "Sep", value: 165_000),
            MonthlyMetricEntry(monthShort: "Okt", value: 158_000),
            MonthlyMetricEntry(monthShort: "Nov", value: 171_000)
        ]

        return store
    }
}
