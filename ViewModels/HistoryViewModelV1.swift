//
//  HistoryViewModelV1.swift
//  GluVibProbe
//
//  HISTORY — ViewModel V1 (SSoT → UI Events)
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

    private func bind() {
        cancellables.removeAll()
        guard let healthStore else { return }

        let settings = SettingsModel.shared

        Publishers.MergeMany(
            // HealthStore publishes
            healthStore.$carbEvents3Days.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$bolusEvents3Days.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$basalEvents3Days.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$cgmSamples3Days.map { _ in () }.eraseToAnyPublisher(),

            healthStore.$mainChartCacheV1.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$recentWorkouts.map { _ in () }.eraseToAnyPublisher(),
            healthStore.$recentWeightSamplesForHistoryV1.map { _ in () }.eraseToAnyPublisher(),

            // Settings changes should instantly rebuild History UI strings + filtering
            settings.$glucoseUnit.map { _ in () }.eraseToAnyPublisher(),
            settings.$distanceUnit.map { _ in () }.eraseToAnyPublisher(),
            settings.$weightUnit.map { _ in () }.eraseToAnyPublisher(),
            settings.$hasCGM.map { _ in () }.eraseToAnyPublisher(),                 // ✅ NEW
            settings.$isInsulinTreated.map { _ in () }.eraseToAnyPublisher()        // ✅ NEW
        )
        .debounce(for: .milliseconds(60), scheduler: DispatchQueue.main)
        .sink { [weak self] in
            self?.rebuild()
        }
        .store(in: &cancellables)
    }

    private func rebuild() {
        guard let healthStore else {
            events = []
            return
        }

        var out: [HistoryListEvent] = []
        let settings = SettingsModel.shared

        let showCGM = settings.hasCGM
        let showInsulin = settings.isInsulinTreated

        for dayOffset in stride(from: 0, through: -9, by: -1) {

            let profile = resolveMainChartProfile(healthStore: healthStore, dayOffset: dayOffset)

            // ------------------------------------------------------------
            // Body: Weight (Quelle: HealthStore.recentWeightSamplesForHistoryV1)
            // ------------------------------------------------------------

            let weights = weightsForDayOffset(healthStore: healthStore, dayOffset)

            for w in weights {
                let ts = w.timestamp
                let detail = settings.weightUnit.formatted(fromKg: w.kg, fractionDigits: 1)

                // Weight never shows glucose
                let markers: [HistoryEventRowCardModel.GlucoseMarker] = []

                out.append(
                    HistoryListEvent(
                        timestamp: ts,
                        cardModel: .init(
                            domain: .body,
                            titleText: "Weight",
                            detailText: detail,
                            timeText: formatTime(ts),
                            glucoseMarkers: markers,
                            contextHint: nil
                        ),
                        metricRoute: .weight,
                        overviewRoute: .bodyOverview
                    )
                )
            }

            // ------------------------------------------------------------
            // Workouts (Quelle: healthStore.recentWorkouts)
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
                let title = w.workoutActivityType.simpleName

                let markers: [HistoryEventRowCardModel.GlucoseMarker]
                if showCGM, let profile {
                    markers = glucoseMarkersForActivity(samples: profile.cgm, start: start, end: end)
                } else {
                    markers = []   // ✅ NO CGM → no glucose row
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
                            contextHint: nil
                        ),
                        metricRoute: .workoutMinutes,
                        overviewRoute: .activityOverview
                    )
                )
            }

            guard let profile else { continue }

            // ------------------------------------------------------------
            // Nutrition: Carbs (always allowed; glucose row only if CGM)
            // ------------------------------------------------------------

            for e in profile.carbs {
                let gramsInt = Int(max(0, e.grams).rounded())
                let detail = "\(gramsInt) g"

                let markers: [HistoryEventRowCardModel.GlucoseMarker]
                if showCGM {
                    markers = glucoseMarkersForPointEvent(samples: profile.cgm, timestamp: e.timestamp)
                } else {
                    markers = []   // ✅ NO CGM → no glucose row
                }

                out.append(
                    HistoryListEvent(
                        timestamp: e.timestamp,
                        cardModel: .init(
                            domain: .nutrition,
                            titleText: "Carbs",
                            detailText: detail,
                            timeText: formatTime(e.timestamp),
                            glucoseMarkers: markers,
                            contextHint: nil
                        ),
                        metricRoute: .carbs,
                        overviewRoute: .nutritionOverview
                    )
                )
            }

            // ------------------------------------------------------------
            // Metabolic: Bolus/Basal (only if insulin-treated)
            // ------------------------------------------------------------

            if showInsulin {

                // Bolus
                for b in profile.bolus {
                    let units = max(0, b.units)
                    let detail = String(format: "%.1f U", units)

                    let markers: [HistoryEventRowCardModel.GlucoseMarker]
                    if showCGM {
                        markers = glucoseMarkersForPointEvent(samples: profile.cgm, timestamp: b.timestamp)
                    } else {
                        markers = []   // ✅ NO CGM → no glucose row
                    }

                    out.append(
                        HistoryListEvent(
                            timestamp: b.timestamp,
                            cardModel: .init(
                                domain: .metabolic,
                                titleText: "Bolus",
                                detailText: detail,
                                timeText: formatTime(b.timestamp),
                                glucoseMarkers: markers,
                                contextHint: nil
                            ),
                            metricRoute: .bolus,
                            overviewRoute: .metabolicPremiumOverview
                        )
                    )
                }

                // Basal (never shows glucose row)
                for b in profile.basal {
                    let units = max(0, b.units)
                    let detail = String(format: "%.1f U", units)

                    out.append(
                        HistoryListEvent(
                            timestamp: b.timestamp,
                            cardModel: .init(
                                domain: .metabolic,
                                titleText: "Basal",
                                detailText: detail,
                                timeText: formatTime(b.timestamp),
                                glucoseMarkers: [],
                                contextHint: nil
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
    // MARK: - Weight helpers (10 days window)
    // ============================================================

    private func weightsForDayOffset(
        healthStore: HealthStore,
        _ dayOffset: Int
    ) -> [WeightSamplePointV1] {

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

        return healthStore.recentWeightSamplesForHistoryV1
            .filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // ============================================================
    // MARK: - MainChart Cache Resolve (0...-9)
    // ============================================================

    private func resolveMainChartProfile(
        healthStore: HealthStore,
        dayOffset: Int
    ) -> MainChartDayProfileV1? {

        if let cached = healthStore.cachedMainChartProfileV1(dayOffset: dayOffset) {
            return cached
        }

        if [0, -1, -2].contains(dayOffset) {
            healthStore.rebuildMainChartCacheFromRaw3DaysV1()
            return healthStore.cachedMainChartProfileV1(dayOffset: dayOffset)
        }

        return nil
    }

    // ============================================================
    // MARK: - Workouts helpers (10 days window)
    // ============================================================

    private func workoutsForDayOffset(
        healthStore: HealthStore,
        _ dayOffset: Int
    ) -> [HKWorkout] {

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

        return healthStore.recentWorkouts
            .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            .sorted { $0.startDate > $1.startDate }
    }

    // ============================================================
    // MARK: - Glucose Marker Helpers
    // ============================================================

    private func glucoseMarkersForPointEvent(
        samples: [CGMSamplePoint],
        timestamp: Date
    ) -> [HistoryEventRowCardModel.GlucoseMarker] {

        guard let s = glucoseValueNear(samples: samples, timestamp) else { return [] }

        let p30 = glucoseValueNear(samples: samples, timestamp.addingTimeInterval(30 * 60))
        let p60 = glucoseValueNear(samples: samples, timestamp.addingTimeInterval(60 * 60))

        var out: [HistoryEventRowCardModel.GlucoseMarker] = []
        out.append(.init(kind: .start, valueText: glucoseDisplayText(mgdlInt: s)))

        if let p30 { out.append(.init(kind: .plus30, valueText: glucoseDisplayText(mgdlInt: p30))) }
        if let p60 { out.append(.init(kind: .plus60, valueText: glucoseDisplayText(mgdlInt: p60))) }

        return out
    }

    private func glucoseMarkersForActivity(
        samples: [CGMSamplePoint],
        start: Date,
        end: Date
    ) -> [HistoryEventRowCardModel.GlucoseMarker] {

        guard let s = glucoseValueNear(samples: samples, start) else { return [] }

        let ePlus30 = glucoseValueNear(samples: samples, end.addingTimeInterval(30 * 60))
        let ePlus60 = glucoseValueNear(samples: samples, end.addingTimeInterval(60 * 60))

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

    private func glucoseValueNear(
        samples: [CGMSamplePoint],
        _ ts: Date
    ) -> Int? {

        guard !samples.isEmpty else { return nil }

        let maxDelta: TimeInterval = 10 * 60
        var best: (delta: TimeInterval, value: Double)? = nil

        for s in samples {
            let d = abs(s.timestamp.timeIntervalSince(ts))
            guard d <= maxDelta else { continue }

            if let b = best {
                if d < b.delta { best = (d, s.glucoseMgdl) }
            } else {
                best = (d, s.glucoseMgdl)
            }
        }

        guard let v = best?.value else { return nil }
        return Int(v.rounded())
    }

    // ============================================================
    // MARK: - Formatting
    // ============================================================

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
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
    var simpleName: String {
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .highIntensityIntervalTraining: return "HIIT"
        case .functionalStrengthTraining: return "Functional Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .coreTraining: return "Core Training"
        case .elliptical: return "Elliptical"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .martialArts: return "Martial Arts"
        default: return "Workout"
        }
    }
}
