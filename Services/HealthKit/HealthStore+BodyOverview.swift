//
//  HealthStore+BodyOverview.swift
//  GluVibProbe
//
//  Spezielle Helper für die BodyOverview:
//  - Tagesbasierte Sleep / Weight / BMI / Body Fat / Resting Heart Rate
//  - Trend-Helfer für Weight
//
//  WICHTIG:
//  - Nutzt deine bestehenden Daily-Funktionen (fetchSleepDaily, fetchWeightDaily, ...)
//  - Verändert die globale Datenlogik NICHT, sondern baut nur Convenience-Wrapper.
//

import Foundation
import HealthKit      // !!! NEW: für HKQuantityType / HKStatisticsQuery
extension HealthStore {

    // ============================================================
    // MARK: - Tagesbasierte Sleep (Minuten)
    // ============================================================

    /// Sleep (Minuten) für einen bestimmten Tag.
    /// Nutzt intern `fetchSleepDaily(last:)` → Single Source of Truth.
    /// Erwartet, dass `DailySleepEntry` mindestens `date` und `minutes` enthält.
    func fetchDailySleepMinutes(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchSleepDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)

                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.minutes ?? 0

                continuation.resume(returning: value)
            }
        }
    }

    // ============================================================
    // MARK: - Tagesbasierte Weight (kg, Rohwert)
    // ============================================================

    /// Weight (kg, Double-Rohwert) für einen bestimmten Tag.
    ///
    /// Ziel:
    /// - Für *alle* Tage den echten HealthKit-Rohwert mit Nachkommastellen nutzen
    ///   (nicht den alten Int-Transport aus `fetchWeightDaily`).
    func fetchDailyWeightKgRaw(for date: Date) async throws -> Double {

        // PREVIEW: weiter mit deinem bestehenden Preview-Cache arbeiten
        if isPreview {
            let calendar  = Calendar.current
            let targetDay = calendar.startOfDay(for: date)

            if let entry = previewDailyWeight.first(where: {
                calendar.isDate($0.date, inSameDayAs: targetDay)
            }) {
                // Preview bleibt bei Int-Transport, ist okay
                return Double(entry.steps)
            }
            return 0.0
        }

        // ECHTER HealthKit-Weg für reale Daten (Today, Yesterday, DayBefore, ...)
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return 0.0
        }

        let calendar   = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0.0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: weightType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let avgQuantity = stats?.averageQuantity() else {
                    continuation.resume(returning: 0.0)
                    return
                }

                // 👉 Hier kommt der echte Double-Wert aus HealthKit, z.B. 97.4 kg
                let kg = avgQuantity.doubleValue(
                    for: HKUnit.gramUnit(with: .kilo)
                )

                // KEINE Int-Konvertierung, KEIN .rounded() – wir geben den Rohwert weiter
                continuation.resume(returning: kg)
            }

            self.healthStore.execute(query)
        }
    }

    // ============================================================
    // MARK: - Tagesbasierte BMI
    // ============================================================

    /// BMI für einen bestimmten Tag.
    /// Nutzt intern `fetchBMIDaily(last:)`.
    func fetchDailyBMI(for date: Date) async throws -> Double {
        await withCheckedContinuation { continuation in
            self.fetchBMIDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)

                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.bmi ?? 0.0

                continuation.resume(returning: value)
            }
        }
    }

    // ============================================================
    // MARK: - Tagesbasierte Body Fat (%)
    // ============================================================

    /// Body Fat (%) für einen bestimmten Tag.
    /// Nutzt intern `fetchBodyFatDaily(last:)`.
    func fetchDailyBodyFatPercent(for date: Date) async throws -> Double {
        await withCheckedContinuation { continuation in
            self.fetchBodyFatDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)

                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.bodyFatPercent ?? 0.0

                continuation.resume(returning: value)
            }
        }
    }

    // ============================================================
    // MARK: - Tagesbasierte Resting Heart Rate (bpm)
    // ============================================================

    /// Resting Heart Rate (bpm) für einen bestimmten Tag.
    /// Nutzt intern `fetchRestingHeartRateDaily(last:)`.
    func fetchDailyRestingHeartRate(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchRestingHeartRateDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)

                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.restingHeartRate ?? 0

                continuation.resume(returning: value)
            }
        }
    }

    // ============================================================
    // MARK: - Weight-Trend für BodyOverview (letzte 90 Tage)
    // ============================================================

    /// Liefert die Weight-Dailies (letzte 90 Tage) für Trend-Berechnungen in der BodyOverview.
    ///
    /// Nutzt intern `fetchWeightDaily(last:)` und gibt die Array-Struktur
    /// unverändert zurück, damit das ViewModel frei entscheiden kann, wie viele Punkte
    /// (z. B. letzte 10 Mess-Tage) es im UI verwenden möchte.
    func fetchLast90DaysWeightTrend() async throws -> [DailyStepsEntry] {
        await withCheckedContinuation { continuation in
            self.fetchWeightDaily(last: 90) { entries in
                // Optional: sortieren nach Datum (falls nicht garantiert)
                let sorted = entries.sorted { $0.date < $1.date }
                continuation.resume(returning: sorted)
            }
        }
    }
}
