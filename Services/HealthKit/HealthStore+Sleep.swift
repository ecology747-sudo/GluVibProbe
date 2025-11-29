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
    // MARK: - SLEEP (Minuten)
    // ============================================================

    // Heute
    func fetchSleepToday() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let all = samples as? [HKCategorySample] ?? []

            let seconds = all.reduce(0.0) { acc, sample in
                acc + sample.endDate.timeIntervalSince(sample.startDate)
            }

            DispatchQueue.main.async {
                self.todaySleepMinutes = Int(seconds / 60.0)
            }
        }

        healthStore.execute(query)
    }

    // Sleep N Tage
    func fetchSleepDaily(
        last days: Int,
        assign: @escaping ([DailySleepEntry]) -> Void
    ) {
        if isPreview {
            let slice = Array(previewDailySleep.suffix(days))
            DispatchQueue.main.async { assign(slice) }
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { _, samples, _ in
            let all = samples as? [HKCategorySample] ?? []
            let calendar = Calendar.current

            var bucket: [Date: TimeInterval] = [:]

            for s in all {
                var current = s.startDate
                let end = s.endDate

                while current < end {
                    let dayStart = calendar.startOfDay(for: current)
                    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

                    let segmentEnd = min(end, nextDay)
                    let duration = segmentEnd.timeIntervalSince(current)

                    bucket[dayStart, default: 0] += duration
                    current = segmentEnd
                }
            }

            let entries: [DailySleepEntry] = bucket.map { (day, seconds) in
                DailySleepEntry(date: day, minutes: Int(seconds / 60.0))
            }
            .sorted { $0.date < $1.date }

            DispatchQueue.main.async { assign(entries) }
        }

        healthStore.execute(query)
    }

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
