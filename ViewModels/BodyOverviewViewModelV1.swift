//
//  BodyOverviewViewModelV1.swift
//  GluVibProbe
//
//  V1 CLEAN: Body Overview View Model (1:1 Datenflow wie ActivityOverviewViewModelV1)
//

import Foundation
import SwiftUI
import Combine

struct BodyWeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date

    private let weightKgOptional: Double?
    let hasSample: Bool

    var weightKg: Double { max(0.0, weightKgOptional ?? 0.0) }
    var weightKgOrNil: Double? { weightKgOptional }

    init(date: Date, weightKg: Double?, hasSample: Bool) {
        self.date = date
        self.weightKgOptional = weightKg
        self.hasSample = hasSample
    }
}

@MainActor
final class BodyOverviewViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Dependencies (SSoT)
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Remap Coalescing (wie Activity)
    // ============================================================

    private var remapTask: Task<Void, Never>? = nil
    private var remapToken: Int = 0

    // ============================================================
    // MARK: - Day Selection (Pager)
    // ============================================================

    /// 0 = Today, -1 = Yesterday, -2 = DayBeforeYesterday
    @Published var selectedDayOffset: Int = 0

    var selectedDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: selectedDayOffset, to: today) ?? today
    }

    // ============================================================
    // MARK: - Published Outputs (für BodyOverviewViewV1)
    // ============================================================

    @Published var todayWeightKg: Double? = nil
    @Published var targetWeightKg: Double = 0.0
    @Published var weightDeltaKg: Double = 0.0
    @Published var weightTrend: [BodyWeightTrendPoint] = []

    @Published var lastNightSleepMinutes: Int = 0
    @Published var sleepGoalMinutes: Int = 0
    @Published var sleepGoalCompletion: Double = 0.0

    @Published var restingHeartRateBpm: Int = 0
    @Published var hrvMs: Int = 0

    @Published var bmi: Double = 0.0
    @Published var bodyFatPercent: Double = 0.0

    @Published var bodyInsightText: String = ""

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindStores()
        syncInitialState()
    }

    // ============================================================
    // MARK: - Bindings (SSoT) → nur triggern
    // ============================================================

    private func bindStores() {

        healthStore.$todaySleepMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayRestingHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayBodyFatPercent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayWeightKgRaw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$sleepDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        healthStore.$restingHeartRateDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        healthStore.$bmiDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        healthStore.$bodyFatDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        healthStore.$weightDaily365Raw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: [DailyWeightEntry]) in
                self?.scheduleRemap()
            }
            .store(in: &cancellables)

        settings.$dailySleepGoalMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        settings.$targetWeightKg
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)

        settings.$weightUnit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRemap() }
            .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Remap Scheduling (Coalescing + Token)
    // ============================================================

    private func scheduleRemap() {
        remapToken += 1
        let token = remapToken

        remapTask?.cancel()
        remapTask = Task { @MainActor in
            await Task.yield()
            guard token == self.remapToken else { return }
            self.refreshForSelectedDay()
        }
    }

    private func syncInitialState() {
        selectedDayOffset = 0
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Day Selection API (Pager)
    // ============================================================

    func applySelectedDayOffset(_ offset: Int) async {
        selectedDayOffset = offset
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Public API (Refresh)
    // ============================================================

    func refresh() async {
        guard selectedDayOffset == 0 else { return }
        await healthStore.refreshBody(.pullToRefresh)
        refreshForSelectedDay()
    }

    func refreshOnNavigation() async {
        guard selectedDayOffset == 0 else {
            refreshForSelectedDay()
            return
        }

        await healthStore.refreshBody(.navigation)
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Core Mapping (EIN Writer)
    // ============================================================

    private func refreshForSelectedDay() {

        let calendar = Calendar.current
        let date = selectedDate

        sleepGoalMinutes = settings.dailySleepGoalMinutes
        targetWeightKg = Double(settings.targetWeightKg)

        if selectedDayOffset == 0 {
            lastNightSleepMinutes = max(0, healthStore.todaySleepMinutes)
        } else {
            lastNightSleepMinutes = max(0, sleepMinutesFromCache(for: date, calendar: calendar))
        }

        if sleepGoalMinutes > 0 {
            sleepGoalCompletion = Double(lastNightSleepMinutes) / Double(sleepGoalMinutes)
        } else {
            sleepGoalCompletion = 0.0
        }

        if selectedDayOffset == 0 {
            restingHeartRateBpm = max(0, healthStore.todayRestingHeartRate)
        } else {
            restingHeartRateBpm = max(0, restingHRFromCacheForwardFill(endingOn: date, calendar: calendar))
        }

        hrvMs = 0

        if selectedDayOffset == 0 {
            bmi = max(0.0, healthStore.todayBMI)
        } else {
            bmi = max(0.0, bmiFromCacheForwardFill(endingOn: date, calendar: calendar))
        }

        if selectedDayOffset == 0 {
            bodyFatPercent = max(0.0, healthStore.todayBodyFatPercent)
        } else {
            bodyFatPercent = max(0.0, bodyFatFromCacheForwardFill(endingOn: date, calendar: calendar))
        }

        if selectedDayOffset == 0 {
            let raw = max(0.0, healthStore.todayWeightKgRaw)
            todayWeightKg = (raw > 0) ? raw : nil
        } else {
            let raw = weightKgFromCacheForwardFill(endingOn: date, calendar: calendar)
            todayWeightKg = (raw > 0) ? raw : nil
        }

        if let current = todayWeightKg, targetWeightKg > 0 {
            weightDeltaKg = current - targetWeightKg
        } else {
            weightDeltaKg = 0.0
        }

        weightTrend = buildLastSevenDaysWeightTrendForDisplayedDay(
            selectedDayOffset: selectedDayOffset,
            calendar: calendar
        )

        if selectedDayOffset == 0 {
            bodyInsightText = makeBodyInsightText()
        } else {
            bodyInsightText = ""
        }
    }

    // ============================================================
    // MARK: - Cache Readers
    // ============================================================

    private func endOfDayExclusive(for date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }

    private func sleepMinutesFromCache(for date: Date, calendar: Calendar) -> Int {
        healthStore.sleepDaily365
            .first(where: { calendar.isDate($0.date, inSameDayAs: date) })?
            .minutes ?? 0
    }

    private func weightKgFromCacheForwardFill(endingOn endDate: Date, calendar: Calendar) -> Double {
        let eod = endOfDayExclusive(for: endDate, calendar: calendar)

        let lastKnown = healthStore.weightDaily365Raw
            .filter { $0.date < eod }
            .sorted { $0.date < $1.date }
            .last?
            .kg ?? 0.0

        return max(0.0, lastKnown)
    }

    private func buildLastSevenDaysWeightTrendForDisplayedDay(
        selectedDayOffset: Int,
        calendar: Calendar
    ) -> [BodyWeightTrendPoint] {

        let todayStart = calendar.startOfDay(for: Date())

        let endOffset = selectedDayOffset - 1
        let endDayStart = calendar.date(byAdding: .day, value: endOffset, to: todayStart) ?? todayStart

        guard let startDayStart = calendar.date(byAdding: .day, value: -6, to: endDayStart) else { return [] }

        let samples = healthStore.weightDaily365Raw.sorted { $0.date < $1.date }

        var measuredByDay: [Date: Double] = [:]
        measuredByDay.reserveCapacity(min(samples.count, 365))

        for sample in samples {
            let day = calendar.startOfDay(for: sample.date)
            let value = max(0.0, sample.kg)
            if value > 0 {
                measuredByDay[day] = value
            }
        }

        var result: [BodyWeightTrendPoint] = []
        result.reserveCapacity(7)

        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: startDayStart) else { continue }
            let normalizedDay = calendar.startOfDay(for: day)

            if let measured = measuredByDay[normalizedDay], measured > 0 {
                result.append(BodyWeightTrendPoint(date: normalizedDay, weightKg: measured, hasSample: true))
            } else {
                result.append(BodyWeightTrendPoint(date: normalizedDay, weightKg: nil, hasSample: false))
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    private func restingHRFromCacheForwardFill(endingOn endDate: Date, calendar: Calendar) -> Int {
        let eod = endOfDayExclusive(for: endDate, calendar: calendar)

        guard let entry = healthStore.restingHeartRateDaily365
            .filter({ $0.date < eod })
            .sorted(by: { $0.date < $1.date })
            .last
        else { return 0 }

        return extractInt(entry, keys: ["bpm", "value", "heartRate", "restingHeartRate"])
    }

    private func bmiFromCacheForwardFill(endingOn endDate: Date, calendar: Calendar) -> Double {
        let eod = endOfDayExclusive(for: endDate, calendar: calendar)

        let lastKnown = healthStore.bmiDaily365
            .filter { $0.date < eod }
            .sorted { $0.date < $1.date }
            .last

        guard let entry = lastKnown else { return 0.0 }
        return max(0.0, extractDouble(entry, keys: ["bmi"]))
    }

    private func bodyFatFromCacheForwardFill(endingOn endDate: Date, calendar: Calendar) -> Double {
        let eod = endOfDayExclusive(for: endDate, calendar: calendar)

        let lastKnown = healthStore.bodyFatDaily365
            .filter { $0.date < eod }
            .sorted { $0.date < $1.date }
            .last

        guard let entry = lastKnown else { return 0.0 }
        return max(0.0, extractDouble(entry, keys: ["bodyFatPercent"]))
    }

    // ============================================================
    // MARK: - Mirror helpers
    // ============================================================

    private func extractInt<T>(_ entry: T, keys: [String]) -> Int {
        let mirror = Mirror(reflecting: entry)
        for key in keys {
            if let value = mirror.children.first(where: { $0.label == key })?.value {
                if let intValue = value as? Int { return max(0, intValue) }
                if let doubleValue = value as? Double { return max(0, Int(doubleValue.rounded())) }
                if let floatValue = value as? Float { return max(0, Int(floatValue.rounded())) }
            }
        }
        return 0
    }

    private func extractDouble<T>(_ entry: T, keys: [String]) -> Double {
        let mirror = Mirror(reflecting: entry)
        for key in keys {
            if let value = mirror.children.first(where: { $0.label == key })?.value {
                if let doubleValue = value as? Double { return max(0.0, doubleValue) }
                if let intValue = value as? Int { return max(0.0, Double(intValue)) }
                if let floatValue = value as? Float { return max(0.0, Double(floatValue)) }
            }
        }
        return 0.0
    }

    // ============================================================
    // MARK: - Formatting helpers
    // ============================================================

    func formattedWeight(_ value: Double?) -> String {
        guard let value else { return "–" }
        return settings.weightUnit.formatted(fromKg: value, fractionDigits: 1)
    }

    func formattedWeight(_ value: Double) -> String {
        settings.weightUnit.formatted(fromKg: value, fractionDigits: 1)
    }

    func formattedDeltaKg(_ deltaKg: Double) -> String {
        let unit = settings.weightUnit

        if deltaKg == 0 {
            return "±\(unit.formattedNumber(fromKg: 0, fractionDigits: 1)) \(unit.label)"
        }

        let sign = deltaKg > 0 ? "+" : "−"
        let absString = unit.formattedNumber(fromKg: abs(deltaKg), fractionDigits: 1)
        return "\(sign)\(absString) \(unit.label)"
    }

    func deltaColor(for delta: Double) -> Color {
        if delta > 0 { return .red }
        if delta < 0 { return Color.Glu.successGreen }
        return Color.Glu.primaryBlue
    }

    func formattedSleep(minutes: Int) -> String { // 🟨 UPDATED
        let hours = minutes / 60
        let mins = minutes % 60

        switch (hours, mins) {
        case (0, let m):
            return String.localizedStringWithFormat(L10n.BodyOverviewFormat.minutesOnly, Int64(m))
        case (let h, 0):
            return String.localizedStringWithFormat(L10n.BodyOverviewFormat.hoursOnly, Int64(h))
        default:
            return String.localizedStringWithFormat(
                L10n.BodyOverviewFormat.hoursMinutes,
                Int64(hours),
                Int64(mins)
            )
        }
    }

    func bmiCategoryText(for bmi: Double) -> String { // 🟨 UPDATED
        switch bmi {
        case ..<18.5:
            return L10n.BodyOverviewBMI.underweight
        case 18.5..<25:
            return L10n.BodyOverviewBMI.normalRange
        case 25..<30:
            return L10n.BodyOverviewBMI.overweight
        default:
            return L10n.BodyOverviewBMI.obesityRange
        }
    }

    // ============================================================
    // MARK: - Trend Arrow
    // ============================================================

    func trendArrowSymbol() -> String {

        let measured = weightTrend
            .filter { $0.hasSample }
            .compactMap { point -> Double? in point.weightKgOrNil }
        guard measured.count >= 2 else { return "arrow.right" }

        let last = measured.last ?? 0.0
        let previous = measured.dropLast()
        let slice = previous.suffix(3)
        guard !slice.isEmpty else { return "arrow.right" }

        let avgPrev = slice.reduce(0.0, +) / Double(slice.count)
        let diff = last - avgPrev
        let threshold: Double = 0.3

        if diff > threshold { return "arrow.up.right" }
        if diff < -threshold { return "arrow.down.right" }
        return "arrow.right"
    }

    func trendArrowColor() -> Color {

        let measured = weightTrend
            .filter { $0.hasSample }
            .compactMap { point -> Double? in point.weightKgOrNil }
        guard measured.count >= 2 else { return Color.Glu.primaryBlue }

        let last = measured.last ?? 0.0
        let previous = measured.dropLast()
        let slice = previous.suffix(3)
        guard !slice.isEmpty else { return Color.Glu.primaryBlue }

        let avgPrev = slice.reduce(0.0, +) / Double(slice.count)
        let diff = last - avgPrev
        return deltaColor(for: diff)
    }

    // ============================================================
    // MARK: - Insight helper (V1)
    // ============================================================

    private func makeBodyInsightText() -> String {
        let input = BodyInsightInput(
            weightTrend: weightTrend,
            lastNightSleepMinutes: lastNightSleepMinutes,
            sleepGoalMinutes: sleepGoalMinutes,
            bmi: bmi,
            bodyFatPercent: bodyFatPercent,
            restingHeartRateBpm: restingHeartRateBpm
        )
        return BodyInsightEngine().makeInsight(for: input)
    }
}
