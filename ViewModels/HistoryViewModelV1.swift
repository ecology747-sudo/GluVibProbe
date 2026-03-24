//
//  HistoryViewModelV1.swift
//  GluVibProbe
//
//  HISTORY — ViewModel V1 (SSoT → UI Events)
//  - 10-day window (today + 9 back)
//  - History Events are independent from MainChartCache (Carbs/Bolus/Basal/Weight/Workouts)
//

import Foundation
import Combine
import HealthKit

@MainActor
final class HistoryViewModelV1: ObservableObject {

    @Published private(set) var events: [HistoryListEvent] = []

    private var healthStore: HealthStore?
    private var cancellables: Set<AnyCancellable> = []

    init() { }

    func attach(to store: HealthStore) {
        guard healthStore !== store else { return }
        healthStore = store
        bind()
        rebuild()
    }

    func rebuildNow() {
        rebuild()
    }

    func refresh(_ context: HealthStore.RefreshContext = .pullToRefresh) async {
        guard let healthStore else {
            events = []
            return
        }

        if healthStore.isPreview {
            rebuild()
            return
        }

        await healthStore.refreshHistory(context)
        rebuild()
    }

    // ============================================================
    // MARK: - Bind (SSoT publishers → rebuild)
    // ============================================================

    private func bind() {
        cancellables.removeAll()
        guard let healthStore else { return }

        let settings = SettingsModel.shared

        Publishers.MergeMany(
            healthStore.$carbEventsHistoryWindowV1.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$bolusEventsHistoryWindowV1.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$basalEventsHistoryWindowV1.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$cgmSamplesHistoryWindowV1.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$recentWorkouts.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$recentWeightSamplesForHistoryV1.map { _ in () }.eraseToAnyPublisher(),
            settings.$glucoseUnit.map { _ in () }.eraseToAnyPublisher(),
            settings.$distanceUnit.map { _ in () }.eraseToAnyPublisher(),
            settings.$weightUnit.map { _ in () }.eraseToAnyPublisher(),
            settings.$hasCGM.map { _ in () }.eraseToAnyPublisher(),
            settings.$isInsulinTreated.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(60), scheduler: DispatchQueue.main)
        .sink { [weak self] in
            self?.rebuild()
        }
        .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Rebuild (10-day loop)
    // ============================================================

    private func rebuild() {
        guard let healthStore else {
            events = []
            return
        }

        var out: [HistoryListEvent] = []
        let settings = SettingsModel.shared

        let showCGM = settings.hasCGM
        let showInsulin = settings.isInsulinTreated

        let cgmIndex = CGMIndex(samples: healthStore.cgmSamplesHistoryWindowV1, maxDeltaMinutes: 20)

        for dayOffset in stride(from: 0, through: -9, by: -1) {

            // ------------------------------------------------------------
            // Body: Weight
            // ------------------------------------------------------------

            let weights = weightsForDayOffset(healthStore: healthStore, dayOffset)

            for w in weights {
                let ts = w.timestamp
                let detail = settings.weightUnit.formatted(fromKg: w.kg, fractionDigits: 1)

                out.append(
                    HistoryListEvent(
                        timestamp: ts,
                        cardModel: .init(
                            domain: .body,
                            titleText: L10n.History.Event.weight,
                            detailText: detail,
                            timeText: formatTime(ts),
                            glucoseMarkers: [],
                            contextHint: nil,
                            semanticKind: .weight
                        ),
                        metricRoute: .weight,
                        overviewRoute: .bodyOverview
                    )
                )
            }

            // ------------------------------------------------------------
            // Workouts
            // ------------------------------------------------------------

            let workouts = workoutsForDayOffset(healthStore: healthStore, dayOffset)

            for w in workouts {
                let start = w.startDate
                let end = w.endDate

                let durationMinutes = max(0, Int(w.duration / 60.0))

                var parts: [String] = []
                parts.append("\(durationMinutes) min")

                if let kcal = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()), kcal > 0 {
                    parts.append("\(Int(kcal.rounded())) kcal")
                }

                if let km = w.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)), km > 0 {
                    parts.append(settings.distanceUnit.formattedAdaptive(fromKm: km))
                }

                let detail = parts.joined(separator: " · ")
                let title = w.workoutActivityType.localizedHistoryName
                let workoutSymbol = WorkoutBadgeHelper.symbolName(for: title)

                let markers: [HistoryEventRowCardModel.GlucoseMarker]
                if showCGM {
                    let computed = glucoseMarkersForActivity(index: cgmIndex, start: start, end: end)
                    markers = computed.isEmpty ? placeholderCGMMarker(forEventTimestamp: start) : computed
                } else {
                    markers = []
                }

                out.append(
                    HistoryListEvent(
                        timestamp: start,
                        cardModel: .init(
                            domain: .activity,
                            titleText: title,
                            detailText: detail,
                            timeText: formatTime(start),
                            glucoseMarkers: markers,
                            contextHint: nil,
                            glucoseRowTitleText: markers.isEmpty ? nil : localizedGlucoseRowTitle(), // 🟨 UPDATED
                            semanticKind: .activityWorkout(symbol: workoutSymbol)
                        ),
                        metricRoute: .workoutMinutes,
                        overviewRoute: .activityOverview
                    )
                )
            }

            // ------------------------------------------------------------
            // Nutrition: Carbs
            // ------------------------------------------------------------

            let carbEvents = carbEventsForDayOffset(healthStore: healthStore, dayOffset)
            let clusteredCarbEvents = clusterNutritionEventsV1(carbEvents, windowMinutes: 10)

            for e in clusteredCarbEvents {
                let gramsInt = Int(max(0, e.grams).rounded())
                let detail = "\(gramsInt) g"

                let markers: [HistoryEventRowCardModel.GlucoseMarker]
                if showCGM {
                    let computed = glucoseMarkersForPointEvent(index: cgmIndex, timestamp: e.timestamp)
                    markers = computed.isEmpty ? placeholderCGMMarker(forEventTimestamp: e.timestamp) : computed
                } else {
                    markers = []
                }

                out.append(
                    HistoryListEvent(
                        timestamp: e.timestamp,
                        cardModel: .init(
                            domain: .nutrition,
                            titleText: L10n.History.Event.carbs,
                            detailText: detail,
                            timeText: formatTime(e.timestamp),
                            glucoseMarkers: markers,
                            contextHint: nil,
                            glucoseRowTitleText: markers.isEmpty ? nil : localizedGlucoseRowTitle(), // 🟨 UPDATED
                            semanticKind: .carbs
                        ),
                        metricRoute: .carbs,
                        overviewRoute: .nutritionOverview
                    )
                )
            }

            // ------------------------------------------------------------
            // Metabolic: Bolus/Basal
            // ------------------------------------------------------------

            if showInsulin {

                let bolus = bolusEventsForDayOffset(healthStore: healthStore, dayOffset)
                for b in bolus {
                    let units = max(0, b.units)
                    let detail = L10n.History.Format.insulinValue(units) // 🟨 UPDATED

                    let markers: [HistoryEventRowCardModel.GlucoseMarker]
                    if showCGM {
                        let computed = glucoseMarkersForPointEvent(index: cgmIndex, timestamp: b.timestamp)
                        markers = computed.isEmpty ? placeholderCGMMarker(forEventTimestamp: b.timestamp) : computed
                    } else {
                        markers = []
                    }

                    out.append(
                        HistoryListEvent(
                            timestamp: b.timestamp,
                            cardModel: .init(
                                domain: .metabolic,
                                titleText: L10n.History.Event.bolus,
                                detailText: detail,
                                timeText: formatTime(b.timestamp),
                                glucoseMarkers: markers,
                                contextHint: nil,
                                glucoseRowTitleText: markers.isEmpty ? nil : localizedGlucoseRowTitle(), // 🟨 UPDATED
                                semanticKind: .bolus
                            ),
                            metricRoute: .bolus,
                            overviewRoute: .metabolicPremiumOverview
                        )
                    )
                }

                let basal = basalEventsForDayOffset(healthStore: healthStore, dayOffset)
                for b in basal {
                    let units = max(0, b.units)
                    let detail = L10n.History.Format.insulinValue(units) // 🟨 UPDATED

                    out.append(
                        HistoryListEvent(
                            timestamp: b.timestamp,
                            cardModel: .init(
                                domain: .metabolic,
                                titleText: L10n.History.Event.basal,
                                detailText: detail,
                                timeText: formatTime(b.timestamp),
                                glucoseMarkers: [],
                                contextHint: nil,
                                semanticKind: .basal
                            ),
                            metricRoute: .basal,
                            overviewRoute: .metabolicPremiumOverview
                        )
                    )
                }
            }
        }

        out.sort { $0.timestamp > $1.timestamp }
        self.events = out
    }

    // ============================================================
    // MARK: - Carbs helpers (History Window, 10 days)
    // ============================================================

    private func carbEventsForDayOffset(healthStore: HealthStore, _ dayOffset: Int) -> [NutritionEvent] {
        let (dayStart, dayEnd) = dayBounds(dayOffset: dayOffset)
        return healthStore.carbEventsHistoryWindowV1
            .filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func bolusEventsForDayOffset(healthStore: HealthStore, _ dayOffset: Int) -> [InsulinBolusEvent] {
        let (dayStart, dayEnd) = dayBounds(dayOffset: dayOffset)
        return healthStore.bolusEventsHistoryWindowV1
            .filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func basalEventsForDayOffset(healthStore: HealthStore, _ dayOffset: Int) -> [InsulinBasalEvent] {
        let (dayStart, dayEnd) = dayBounds(dayOffset: dayOffset)
        return healthStore.basalEventsHistoryWindowV1
            .filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // ============================================================
    // MARK: - Nutrition Cluster Helper (Meal Window)
    // ============================================================

    private func clusterNutritionEventsV1(
        _ events: [NutritionEvent],
        windowMinutes: Int
    ) -> [NutritionEvent] {
        guard !events.isEmpty else { return [] }

        let window: TimeInterval = TimeInterval(max(1, windowMinutes) * 60)

        var result: [NutritionEvent] = []
        result.reserveCapacity(events.count)

        var currentKind: NutritionEventKind? = nil
        var currentStart: Date? = nil
        var lastTime: Date? = nil
        var sum: Double = 0

        func flushIfNeeded() {
            guard let kind = currentKind, let start = currentStart else { return }
            guard sum > 0 else { return }

            result.append(
                NutritionEvent(
                    id: UUID(),
                    timestamp: start,
                    grams: sum,
                    kind: kind
                )
            )
        }

        for e in events {
            if currentKind == nil {
                currentKind = e.kind
                currentStart = e.timestamp
                lastTime = e.timestamp
                sum = max(0, e.grams)
                continue
            }

            let sameKind = (e.kind == currentKind)
            let closeEnough = (lastTime.map { e.timestamp.timeIntervalSince($0) <= window } ?? false)

            if sameKind && closeEnough {
                sum += max(0, e.grams)
                lastTime = e.timestamp
            } else {
                flushIfNeeded()
                currentKind = e.kind
                currentStart = e.timestamp
                lastTime = e.timestamp
                sum = max(0, e.grams)
            }
        }

        flushIfNeeded()
        return result.sorted { $0.timestamp > $1.timestamp }
    }

    // ============================================================
    // MARK: - Placeholder marker (Pending vs No Data)
    // ============================================================

    private func placeholderCGMMarker(forEventTimestamp ts: Date) -> [HistoryEventRowCardModel.GlucoseMarker] {
        let pendingWindow: TimeInterval = (3 * 3600) + 60
        let isPending = Date().timeIntervalSince(ts) <= pendingWindow
        let text = isPending ? L10n.History.Event.cgmPending : L10n.History.Event.noCGMData

        return [
            HistoryEventRowCardModel.GlucoseMarker(
                kind: .noData,
                valueText: text
            )
        ]
    }

    // ============================================================
    // MARK: - Weight helpers (10 days window)
    // ============================================================

    private func weightsForDayOffset(
        healthStore: HealthStore,
        _ dayOffset: Int
    ) -> [WeightSamplePointV1] {

        let (dayStart, dayEnd) = dayBounds(dayOffset: dayOffset)

        return healthStore.recentWeightSamplesForHistoryV1
            .filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // ============================================================
    // MARK: - Workouts helpers (10 days window)
    // ============================================================

    private func workoutsForDayOffset(
        healthStore: HealthStore,
        _ dayOffset: Int
    ) -> [HKWorkout] {

        let (dayStart, dayEnd) = dayBounds(dayOffset: dayOffset)

        return healthStore.recentWorkouts
            .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            .sorted { $0.startDate > $1.startDate }
    }

    // ============================================================
    // MARK: - Day Bounds (0...-9)
    // ============================================================

    private func dayBounds(dayOffset: Int) -> (Date, Date) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        return (dayStart, dayEnd)
    }

    // ============================================================
    // MARK: - CGM Index (fast nearest lookup)
    // ============================================================

    private struct CGMIndex {
        let times: [TimeInterval]
        let values: [Double]
        let maxDelta: TimeInterval

        init(samples: [CGMSamplePoint], maxDeltaMinutes: Double = 10) {
            self.maxDelta = max(1, maxDeltaMinutes) * 60.0
            let sorted = samples.sorted { $0.timestamp < $1.timestamp }
            self.times = sorted.map { $0.timestamp.timeIntervalSince1970 }
            self.values = sorted.map { $0.glucoseMgdl }
        }

        func nearestValue(at date: Date) -> Int? {
            guard !times.isEmpty else { return nil }

            let t = date.timeIntervalSince1970
            let i = lowerBound(times, t)

            var bestDelta = TimeInterval.greatestFiniteMagnitude
            var bestValue: Double? = nil

            if i < times.count {
                let d = abs(times[i] - t)
                if d < bestDelta { bestDelta = d; bestValue = values[i] }
            }
            if i > 0 {
                let d = abs(times[i - 1] - t)
                if d < bestDelta { bestDelta = d; bestValue = values[i - 1] }
            }

            guard bestDelta <= maxDelta, let v = bestValue else { return nil }
            return Int(v.rounded())
        }

        private func lowerBound(_ a: [TimeInterval], _ x: TimeInterval) -> Int {
            var l = 0
            var r = a.count
            while l < r {
                let m = (l + r) >> 1
                if a[m] < x { l = m + 1 } else { r = m }
            }
            return l
        }
    }

    // ============================================================
    // MARK: - Glucose Marker Helpers (indexed)
    // ============================================================

    private func glucoseMarkersForPointEvent(
        index: CGMIndex,
        timestamp: Date
    ) -> [HistoryEventRowCardModel.GlucoseMarker] {

        guard let s = index.nearestValue(at: timestamp) else { return [] }

        let p30 = index.nearestValue(at: timestamp.addingTimeInterval(30 * 60))
        let p60 = index.nearestValue(at: timestamp.addingTimeInterval(60 * 60))

        var out: [HistoryEventRowCardModel.GlucoseMarker] = []
        out.append(.init(kind: .start, valueText: glucoseDisplayText(mgdlInt: s)))

        if let p30 { out.append(.init(kind: .plus30, valueText: glucoseDisplayText(mgdlInt: p30))) }
        if let p60 { out.append(.init(kind: .plus60, valueText: glucoseDisplayText(mgdlInt: p60))) }

        return out
    }

    private func glucoseMarkersForActivity(
        index: CGMIndex,
        start: Date,
        end: Date
    ) -> [HistoryEventRowCardModel.GlucoseMarker] {

        guard let s = index.nearestValue(at: start) else { return [] }

        let ePlus30 = index.nearestValue(at: end.addingTimeInterval(30 * 60))
        let ePlus60 = index.nearestValue(at: end.addingTimeInterval(60 * 60))

        var out: [HistoryEventRowCardModel.GlucoseMarker] = []
        out.append(.init(kind: .start, valueText: glucoseDisplayText(mgdlInt: s)))

        if let ePlus30 { out.append(.init(kind: .plus30AfterEnd, valueText: glucoseDisplayText(mgdlInt: ePlus30))) }
        if let ePlus60 { out.append(.init(kind: .plus60AfterEnd, valueText: glucoseDisplayText(mgdlInt: ePlus60))) }

        return out
    }

    private func glucoseDisplayText(mgdlInt: Int) -> String {
        let settings = SettingsModel.shared
        let unit = settings.glucoseUnit
        let digits = (unit == .mmolL) ? 1 : 0
        return unit.formattedNumber(fromMgdl: Double(mgdlInt), fractionDigits: digits)
    }

    // ============================================================
    // MARK: - Formatting
    // ============================================================

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }

    private func localizedGlucoseRowTitle() -> String { // 🟨 UPDATED
        let settings = SettingsModel.shared
        let unitText = settings.glucoseUnit == .mmolL ? "mmol/L" : "mg/dL"
        return L10n.History.Glucose.rowTitle(unit: unitText)
    }
}

// ============================================================
// MARK: - History Models
// ============================================================

struct HistoryListEvent: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date

    let cardModel: HistoryEventRowCardModel
    let metricRoute: HistoryMetricRoute
    let overviewRoute: HistoryOverviewRoute
}

enum HistoryMetricRoute: Hashable {
    case workoutMinutes
    case carbs
    case bolus
    case basal
    case weight
}

enum HistoryOverviewRoute: Hashable {
    case activityOverview
    case bodyOverview
    case nutritionOverview
    case metabolicPremiumOverview
}

private extension HKWorkoutActivityType {
    var localizedHistoryName: String {
        switch self {
        case .walking: return L10n.History.Workout.walking
        case .running: return L10n.History.Workout.running
        case .cycling: return L10n.History.Workout.cycling
        case .highIntensityIntervalTraining: return L10n.History.Workout.hiit
        case .functionalStrengthTraining: return L10n.History.Workout.functionalTraining
        case .traditionalStrengthTraining: return L10n.History.Workout.strengthTraining
        case .yoga: return L10n.History.Workout.yoga
        case .pilates: return L10n.History.Workout.pilates
        case .coreTraining: return L10n.History.Workout.coreTraining
        case .elliptical: return L10n.History.Workout.elliptical
        case .swimming: return L10n.History.Workout.swimming
        case .rowing: return L10n.History.Workout.rowing
        case .hiking: return L10n.History.Workout.hiking
        case .dance: return L10n.History.Workout.dance
        case .martialArts: return L10n.History.Workout.martialArts
        default: return L10n.History.Workout.default
        }
    }
}
