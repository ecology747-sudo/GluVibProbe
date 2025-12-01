//
//  HealthStore+Sleep.swift
//  GluVibProbe
//
//  Sleep-Logik ausgelagert aus HealthStore.swift
//

import Foundation
import HealthKit

extension HealthStore {

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    /// Schneidet ein Sample auf das Fenster [windowStart, windowEnd) zu
    private func clampedDuration(
        for sample: HKCategorySample,
        windowStart: Date,
        windowEnd: Date
    ) -> TimeInterval {
        let start = max(sample.startDate, windowStart)
        let end   = min(sample.endDate, windowEnd)
        guard end > start else { return 0 }
        return end.timeIntervalSince(start)
    }

    /// Filtert alle Nicht-Wach-Samples
    private func nonAwakeSamples(from samples: [HKSample]?) -> [HKCategorySample] {
        let all = samples as? [HKCategorySample] ?? []
        return all.filter { $0.value != HKCategoryValueSleepAnalysis.awake.rawValue }
    }

    // ============================================================
    // MARK: - Schlaf heute (komplette letzte Nacht)
    // ============================================================

    /// "Sleep Today" ≈ Apple: Nacht von ca. 18:00 (Vortag) bis 18:00 (heute),
    /// nur Schlafphasen, keine Wach-Phasen.
    func fetchSleepToday() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar   = Calendar.current
        let now        = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Fenster: 18:00 Vortag bis jetzt (max. 18:00 heute)
        guard
            let windowStart = calendar.date(byAdding: .hour, value: -6, to: todayStart)
        else { return }

        let windowEnd = now   // wir schneiden später ggf. auf das Fenster zu

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: []
        )

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let relevant = self.nonAwakeSamples(from: samples)

            let totalSeconds = relevant.reduce(0.0) { acc, sample in
                acc + self.clampedDuration(for: sample,
                                           windowStart: windowStart,
                                           windowEnd: windowEnd)
            }

            DispatchQueue.main.async {
                self.todaySleepMinutes = Int(totalSeconds / 60.0)
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Sleep N Tage (18–18 Fenster pro Tag)
    // ============================================================

    func fetchSleepDaily(
        last days: Int,
        assign: @escaping ([DailySleepEntry]) -> Void
    ) {
        // Preview bleibt wie gehabt
        if isPreview {
            let slice = Array(previewDailySleep.suffix(days))
            DispatchQueue.main.async { assign(slice) }
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar   = Calendar.current
        let now        = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Ältester Tag (Aufwach-Tag) im gewünschten Zeitraum
        guard let firstDay = calendar.date(byAdding: .day, value: -days + 1, to: todayStart) else { return }
        // Gesamtfenster für die Query: ab 18:00 des Vortags vom ersten Tag
        guard let queryStart = calendar.date(byAdding: .hour, value: -6, to: firstDay) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: now,
            options: []
        )

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let relevant = self.nonAwakeSamples(from: samples)

            var entries: [DailySleepEntry] = []

            // Wir bauen für jeden Tag ein eigenes 18–18-Fenster
            for offset in 0..<days {
                guard let dayStart = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }

                guard
                    let windowStart = calendar.date(byAdding: .hour, value: -6, to: dayStart),
                    let rawWindowEnd = calendar.date(byAdding: .hour, value: 18, to: dayStart)
                else { continue }

                let windowEnd = min(rawWindowEnd, now)

                let seconds = relevant.reduce(0.0) { acc, sample in
                    acc + self.clampedDuration(for: sample,
                                               windowStart: windowStart,
                                               windowEnd: windowEnd)
                }

                let minutes = Int(seconds / 60.0)
                entries.append(DailySleepEntry(date: dayStart, minutes: minutes))
            }

            // Sortiert nach Datum (sicherheitshalber)
            let sorted = entries.sorted { $0.date < $1.date }

            DispatchQueue.main.async {
                assign(sorted)
            }
        }

        healthStore.execute(query)
    }

    // ============================================================
    // MARK: - Wrapper für Charts
    // ============================================================

    func fetchLast90DaysSleep() {
        fetchSleepDaily(last: 90) { [weak self] entries in
            self?.last90DaysSleep = entries
        }
    }

    func fetchMonthlySleep() {
        fetchSleepDaily(last: 150) { [weak self] entries in
            guard let self else { return }

            let calendar = Calendar.current
            var perMonth: [DateComponents: Int] = [:]

            for day in entries {
                let comps = calendar.dateComponents([.year, .month], from: day.date)
                perMonth[comps, default: 0] += day.minutes
            }

            let sorted = perMonth.keys.sorted {
                let l = calendar.date(from: $0) ?? .distantPast
                let r = calendar.date(from: $1) ?? .distantPast
                return l < r
            }

            let result = sorted.map { comps in
                let date = calendar.date(from: comps) ?? Date()
                let monthShort = date.formatted(.dateTime.month(.abbreviated))
                return MonthlyMetricEntry(monthShort: monthShort, value: perMonth[comps] ?? 0)
            }

            DispatchQueue.main.async { self.monthlySleep = result }
        }
    }
}
