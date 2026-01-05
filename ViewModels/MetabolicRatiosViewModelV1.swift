//
//  MetabolicRatiosViewModelV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Ratios / Insulin DailyStats (Flow-Check)
//  - Rolling im ViewModel (UI-nahe)
//  - Mapping-only: SSOT bleibt HealthStore daily arrays
//

import Foundation
import Combine

@MainActor
final class MetabolicRatiosViewModelV1: ObservableObject {

    // MARK: - Dependencies (SSOT)

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published (for View)

    @Published private(set) var last14DaysRows: [Row] = []

    // Rolling (7/14/30/90)
    @Published private(set) var avgBolus7: Double = 0
    @Published private(set) var avgBolus14: Double = 0
    @Published private(set) var avgBolus30: Double = 0
    @Published private(set) var avgBolus90: Double = 0

    @Published private(set) var avgBasal7: Double = 0
    @Published private(set) var avgBasal14: Double = 0
    @Published private(set) var avgBasal30: Double = 0
    @Published private(set) var avgBasal90: Double = 0

    @Published private(set) var avgBolusBasalRatio7: Double = 0
    @Published private(set) var avgBolusBasalRatio14: Double = 0
    @Published private(set) var avgBolusBasalRatio30: Double = 0
    @Published private(set) var avgBolusBasalRatio90: Double = 0

    @Published private(set) var avgCarbBolusRatio7: Double = 0
    @Published private(set) var avgCarbBolusRatio14: Double = 0
    @Published private(set) var avgCarbBolusRatio30: Double = 0
    @Published private(set) var avgCarbBolusRatio90: Double = 0

    // Latest (last day)
    @Published private(set) var latestBolus: Double = 0
    @Published private(set) var latestBasal: Double = 0
    @Published private(set) var latestBolusBasalRatio: Double = 0
    @Published private(set) var latestCarbBolusRatio: Double = 0

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        bind()
        recompute()
    }

    // MARK: - Binding

    private func bind() {
        Publishers.CombineLatest4(
            healthStore.$dailyBolus90,
            healthStore.$dailyBasal90,
            healthStore.$dailyBolusBasalRatio90,
            healthStore.$dailyCarbBolusRatio90
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.recompute()
        }
        .store(in: &cancellables)
    }

    // MARK: - Recompute (Rolling + Rows)

    private func recompute() {
        let bolus = healthStore.dailyBolus90.sorted { $0.date < $1.date }
        let basal = healthStore.dailyBasal90.sorted { $0.date < $1.date }
        let bb    = healthStore.dailyBolusBasalRatio90.sorted { $0.date < $1.date }
        let cb    = healthStore.dailyCarbBolusRatio90.sorted { $0.date < $1.date }

        // Latest values (last element)
        latestBolus = bolus.last?.bolusUnits ?? 0
        latestBasal = basal.last?.basalUnits ?? 0
        latestBolusBasalRatio = bb.last?.ratio ?? 0
        latestCarbBolusRatio = cb.last?.gramsPerUnit ?? 0

        // Rolling (note: ratios use filterZero=true because 0 often means "not computable")
        avgBolus7  = averageLast(bolus.map(\.bolusUnits), days: 7,  filterZero: false)
        avgBolus14 = averageLast(bolus.map(\.bolusUnits), days: 14, filterZero: false)
        avgBolus30 = averageLast(bolus.map(\.bolusUnits), days: 30, filterZero: false)
        avgBolus90 = averageLast(bolus.map(\.bolusUnits), days: 90, filterZero: false)

        avgBasal7  = averageLast(basal.map(\.basalUnits), days: 7,  filterZero: false)
        avgBasal14 = averageLast(basal.map(\.basalUnits), days: 14, filterZero: false)
        avgBasal30 = averageLast(basal.map(\.basalUnits), days: 30, filterZero: false)
        avgBasal90 = averageLast(basal.map(\.basalUnits), days: 90, filterZero: false)

        avgBolusBasalRatio7  = averageLast(bb.map(\.ratio), days: 7,  filterZero: true)
        avgBolusBasalRatio14 = averageLast(bb.map(\.ratio), days: 14, filterZero: true)
        avgBolusBasalRatio30 = averageLast(bb.map(\.ratio), days: 30, filterZero: true)
        avgBolusBasalRatio90 = averageLast(bb.map(\.ratio), days: 90, filterZero: true)

        avgCarbBolusRatio7  = averageLast(cb.map(\.gramsPerUnit), days: 7,  filterZero: true)
        avgCarbBolusRatio14 = averageLast(cb.map(\.gramsPerUnit), days: 14, filterZero: true)
        avgCarbBolusRatio30 = averageLast(cb.map(\.gramsPerUnit), days: 30, filterZero: true)
        avgCarbBolusRatio90 = averageLast(cb.map(\.gramsPerUnit), days: 90, filterZero: true)

        // Rows: show last 14 days combined (for quick sanity check)
        last14DaysRows = buildLastDaysRows(
            days: 14,
            bolus: bolus,
            basal: basal,
            bb: bb,
            cb: cb
        )
    }

    private func averageLast(_ values: [Double], days: Int, filterZero: Bool) -> Double {
        guard days > 0 else { return 0 }
        let slice = Array(values.suffix(days))
        let cleaned = filterZero ? slice.filter { $0 > 0 } : slice
        guard !cleaned.isEmpty else { return 0 }
        let sum = cleaned.reduce(0, +)
        return sum / Double(cleaned.count)
    }

    private func buildLastDaysRows(
        days: Int,
        bolus: [DailyBolusEntry],
        basal: [DailyBasalEntry],
        bb: [DailyBolusBasalRatioEntry],
        cb: [DailyCarbBolusRatioEntry]
    ) -> [Row] {
        let calendar = Calendar.current

        var bolusByDay: [Date: Double] = [:]
        bolus.forEach { bolusByDay[calendar.startOfDay(for: $0.date)] = $0.bolusUnits }

        var basalByDay: [Date: Double] = [:]
        basal.forEach { basalByDay[calendar.startOfDay(for: $0.date)] = $0.basalUnits }

        var bbByDay: [Date: Double] = [:]
        bb.forEach { bbByDay[calendar.startOfDay(for: $0.date)] = $0.ratio }

        var cbByDay: [Date: Double] = [:]
        cb.forEach { cbByDay[calendar.startOfDay(for: $0.date)] = $0.gramsPerUnit }

        // Use last available day from bolus/basal (fallback: today)
        let lastDate = (bolus.last?.date ?? basal.last?.date ?? Date())
        let endDay = calendar.startOfDay(for: lastDate)

        var rows: [Row] = []
        rows.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else { continue }

            rows.append(
                Row(
                    id: UUID(),
                    date: day,
                    bolusUnits: bolusByDay[day] ?? 0,
                    basalUnits: basalByDay[day] ?? 0,
                    bolusBasalRatio: bbByDay[day] ?? 0,
                    carbBolusRatio: cbByDay[day] ?? 0
                )
            )
        }

        return rows
    }
}

// MARK: - Row Model (UI helper)

extension MetabolicRatiosViewModelV1 {
    struct Row: Identifiable {
        let id: UUID
        let date: Date
        let bolusUnits: Double
        let basalUnits: Double
        let bolusBasalRatio: Double
        let carbBolusRatio: Double
    }
}

// MARK: - Formatting Helpers (keine SSOT, nur Anzeige)

extension MetabolicRatiosViewModelV1 {

    var formattedLatestBolus: String { format(latestBolus, decimals: 1, suffix: " IU") }
    var formattedLatestBasal: String { format(latestBasal, decimals: 1, suffix: " IU") }

    var formattedLatestBolusBasalRatio: String { format(latestBolusBasalRatio, decimals: 2, suffix: "") }
    var formattedLatestCarbBolusRatio: String { format(latestCarbBolusRatio, decimals: 1, suffix: " g/IU") }

    func format(_ value: Double, decimals: Int, suffix: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        let s = f.string(from: NSNumber(value: value)) ?? "0"
        return s + suffix
    }
}
