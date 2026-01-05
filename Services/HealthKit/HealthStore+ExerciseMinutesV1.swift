//
//  HealthStore+ExerciseTimeV1.swift
//  GluVibProbe
//
//  Exercise Time (Exercise Minutes) V1
//  ------------------------------------------------------------
//  - Fetch-only
//  - Liest appleExerciseTime aus HealthKit
//  - Schreibt rohe Tages-Zeitreihen (365 Tage) in HealthStore
//
//  ⚠️ WICHTIG:
//  - Intern wird activeTimeDaily365 bewusst BEIBEHALTEN
//    um keine bestehenden Consumer (Charts / VMs / Bootstrap)
//    zu brechen.
//  - Eine vollständige Umbenennung auf exerciseTimeDaily365
//    erfolgt später kontrolliert in EINEM Refactor-Schritt.
//
//  ❌ KEIN Bezug zu:
//  - appleMoveTime
//  - appleStandTime
//  - MovementSplit (eigene Aggregation!)
//
//  ✅ Diese Datei liefert NUR:
//  - Reine Trainings-/Übungsminuten (Exercise Time)
//

import Foundation
import HealthKit

// ============================================================
// MARK: - HealthStore + Exercise Time (V1)
// ============================================================

extension HealthStore {

    // ============================================================
    // MARK: - Public API (Entry Point)
//  ============================================================

    /// Lädt Exercise Minutes (appleExerciseTime) für die letzten 365 Tage
    /// und schreibt sie in die bestehende Property `activeTimeDaily365`.
    ///
    /// ⚠️ Naming-Hinweis:
    /// - Funktion heißt bewusst *ExerciseTime*
    /// - Property bleibt vorerst *activeTimeDaily365*
    ///   (Refactor folgt später)
    ///
    func fetchExerciseTimeDaily365V1() {

        // --------------------------------------------------------
        // MARK: - Preview Support
        // --------------------------------------------------------

        if isPreview {
            let slice = Array(previewDailyExerciseMinutes.suffix(365))
            DispatchQueue.main.async {
                self.activeTimeDaily365 = slice
            }
            return
        }

        // --------------------------------------------------------
        // MARK: - HealthKit Type
        // --------------------------------------------------------

        guard let type = HKQuantityType.quantityType(
            forIdentifier: .appleExerciseTime
        ) else {
            return
        }

        // --------------------------------------------------------
        // MARK: - Fetch + Assign
        // --------------------------------------------------------

        fetchDailyExerciseMinutesSeriesV1(
            quantityType: type,
            unit: .minute(),
            days: 365
        ) { [weak self] entries in
            self?.activeTimeDaily365 = entries
        }
    }

    // ============================================================
    // MARK: - Private Helpers (V1 only)
//  ============================================================

    /// Generischer Tages-Aggregator für Exercise Minutes
    /// - Aggregiert strikt nach Kalendertagen (0–24 Uhr)
    /// - Keine Interpretation / kein Fallback / keine Logik
    ///
    private func fetchDailyExerciseMinutesSeriesV1(
        quantityType: HKQuantityType,
        unit: HKUnit,
        days: Int,
        assign: @escaping ([DailyExerciseMinutesEntry]) -> Void
    ) {

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: todayStart
        ) else {
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: []
        )

        var daily: [DailyExerciseMinutesEntry] = []
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
                    DailyExerciseMinutesEntry(
                        date: stats.startDate,
                        minutes: Int(value.rounded())
                    )
                )
            }

            DispatchQueue.main.async {
                assign(
                    daily.sorted { $0.date < $1.date }
                )
            }
        }

        healthStore.execute(query)
    }
}
