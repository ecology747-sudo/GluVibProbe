//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore: ObservableObject {

    // ============================================================
    // MARK: - Singleton / Core
    // ============================================================

    static let shared = HealthStore()

    let healthStore = HKHealthStore()
    let isPreview: Bool

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    // ============================================================
    // MARK: - Published Values für SwiftUI
    // ============================================================

    // -------------------------
    // 🔶 STEPS
    // -------------------------
    @Published var todaySteps: Int = 0
    @Published var last90Days: [DailyStepsEntry] = []
    @Published var monthlySteps: [MonthlyMetricEntry] = []
    @Published var stepsDaily365: [DailyStepsEntry] = []

    // -------------------------
    // 🔶 ACTIVITY ENERGY (kcal)
    // -------------------------
    @Published var todayActiveEnergy: Int = 0
    @Published var last90DaysActiveEnergy: [ActivityEnergyEntry] = []
    @Published var monthlyActiveEnergy: [MonthlyMetricEntry] = []
    @Published var activeEnergyDaily365: [ActivityEnergyEntry] = []

    // -------------------------
    // 🟠 RESTING ENERGY (kcal) — Basal Energy Burned
    // -------------------------
    @Published var todayRestingEnergyKcal: Int = 0
    @Published var last90DaysRestingEnergy: [RestingEnergyEntry] = []
    @Published var monthlyRestingEnergy: [MonthlyMetricEntry] = []
    @Published var restingEnergyDaily365: [DailyRestingEnergyEntry] = []

    // -------------------------
    // 🟣 EXERCISE MINUTES (min)
    // -------------------------
    @Published var todayExerciseMinutes: Int = 0
    @Published var last90DaysExerciseMinutes: [DailyExerciseMinutesEntry] = []
    @Published var monthlyExerciseMinutes: [MonthlyMetricEntry] = []
    @Published var activeTimeDaily365: [DailyExerciseMinutesEntry] = []

    // -------------------------
    // 🔵 MOVE TIME (min)
    // -------------------------
    @Published var todayMoveTimeMinutes: Int = 0
    @Published var last90DaysMoveTime: [DailyMoveTimeEntry] = []
    @Published var monthlyMoveTime: [MonthlyMetricEntry] = []
    @Published var moveTimeDaily365: [DailyMoveTimeEntry] = []

    // -------------------------
    // 🟣 WORKOUT MINUTES (min)
    // -------------------------
    @Published var todayWorkoutMinutes: Int = 0
    @Published var last90DaysWorkoutMinutes: [DailyWorkoutMinutesEntry] = []
    @Published var monthlyWorkoutMinutes: [MonthlyMetricEntry] = []
    @Published var workoutMinutesDaily365: [DailyWorkoutMinutesEntry] = []

    // ============================================================
    // MARK: - Recent Workouts (Overview / History helper)
    // ============================================================

    @Published var recentWorkouts: [HKWorkout] = []
    @Published var recentWorkoutsOverview: [HKWorkout] = []

    // -------------------------
    // 🟠 MOVEMENT SPLIT (min)
    // -------------------------
    @Published var todayMoveMinutes: Int = 0
    @Published var todaySedentaryMinutes: Int = 0
    @Published var todaySleepSplitMinutes: Int = 0

    @Published var movementSplitDaily30: [DailyMovementSplitEntry] = []
    @Published var movementSplitDaily365: [DailyMovementSplitEntry] = []

    enum MovementSplitActiveSourceTodayV1: String {
        case standTime
        case exerciseMinutes
        case workoutMinutes
        case none
    }

    @Published var movementSplitActiveSourceTodayV1: MovementSplitActiveSourceTodayV1 = .none

    // =====================================================
    // MARK: - Activity Overview Outputs (SSoT)
    // =====================================================

    @Published var avg7dExerciseMinutesEndingToday: Int = 0
    @Published var avg7dActiveEnergyKcalEndingToday: Int = 0

    // -------------------------
    // 🔵 SLEEP (Minuten)
    // -------------------------
    @Published var todaySleepMinutes: Int = 0
    @Published var last90DaysSleep: [DailySleepEntry] = []
    @Published var monthlySleep: [MonthlyMetricEntry] = []
    @Published var sleepDaily365: [DailySleepEntry] = []

    @Published var last90DaysSleepSessionsEndingDay: [DailySleepEntry] = []
    @Published var sleepDaily365SessionsEndingDay: [DailySleepEntry] = []

    // -------------------------
    // 🟠 WEIGHT (kg) — V1
    // -------------------------
    @Published var todayWeightKgRaw: Double = 0
    @Published var last90DaysWeight: [DailyWeightEntry] = []
    @Published var monthlyWeight: [MonthlyMetricEntry] = []
    @Published var weightDaily365Raw: [DailyWeightEntry] = []
    @Published var recentWeightSamplesForHistoryV1: [WeightSamplePointV1] = []   // ✅ NEW

    // -------------------------
    // ❤️ RESTING HEART RATE (bpm)
    // -------------------------
    @Published var todayRestingHeartRate: Int = 0
    @Published var last90DaysRestingHeartRate: [RestingHeartRateEntry] = []
    @Published var monthlyRestingHeartRate: [MonthlyMetricEntry] = []
    @Published var restingHeartRateDaily365: [RestingHeartRateEntry] = []

    // -------------------------
    // 🧍‍♂️ BODY FAT (%)
    // -------------------------
    @Published var todayBodyFatPercent: Double = 0
    @Published var last90DaysBodyFat: [BodyFatEntry] = []
    @Published var monthlyBodyFat: [MonthlyMetricEntry] = []
    @Published var bodyFatDaily365: [BodyFatEntry] = []

    // -------------------------
    // 📊 BMI
    // -------------------------
    @Published var todayBMI: Double = 0
    @Published var last90DaysBMI: [BMIEntry] = []
    @Published var monthlyBMI: [MonthlyMetricEntry] = []
    @Published var bmiDaily365: [BMIEntry] = []

    // -------------------------
    // 🟢 CARBS (g)
    // -------------------------
    @Published var todayCarbsGrams: Int = 0
    @Published var last90DaysCarbs: [DailyCarbsEntry] = []
    @Published var monthlyCarbs: [MonthlyMetricEntry] = []
    @Published var carbsDaily365: [DailyCarbsEntry] = []

    // -------------------------
    // 🧬 PROTEIN (g)
    // -------------------------
    @Published var todayProteinGrams: Int = 0
    @Published var last90DaysProtein: [DailyProteinEntry] = []
    @Published var monthlyProtein: [MonthlyMetricEntry] = []
    @Published var proteinDaily365: [DailyProteinEntry] = []

    // -------------------------
    // 🧈 FAT (g)
    // -------------------------
    @Published var todayFatGrams: Int = 0
    @Published var last90DaysFat: [DailyFatEntry] = []
    @Published var monthlyFat: [MonthlyMetricEntry] = []
    @Published var fatDaily365: [DailyFatEntry] = []

    // -------------------------
    // 🍽️ NUTRITION ENERGY (kcal)
    // -------------------------
    @Published var todayNutritionEnergyKcal: Int = 0
    @Published var last90DaysNutritionEnergy: [DailyNutritionEnergyEntry] = []
    @Published var monthlyNutritionEnergy: [MonthlyMetricEntry] = []
    @Published var nutritionEnergyDaily365: [DailyNutritionEnergyEntry] = []

    // ============================================================
    // MARK: - 🧠 METABOLIC DOMAIN (V1) — Published State (SSoT)
    // ============================================================

    @Published var dailyRange90: [DailyRangeEntry] = []

    @Published var rangeTodaySummary: RangePeriodSummaryEntry? = nil
    @Published var range7dSummary: RangePeriodSummaryEntry? = nil
    @Published var range14dSummary: RangePeriodSummaryEntry? = nil
    @Published var range30dSummary: RangePeriodSummaryEntry? = nil
    @Published var range90dSummary: RangePeriodSummaryEntry? = nil

    @Published var cgmSamples3Days: [CGMSamplePoint] = []
    @Published var bolusEvents3Days: [InsulinBolusEvent] = []
    @Published var basalEvents3Days: [InsulinBasalEvent] = []

    @Published var carbEvents3Days: [NutritionEvent] = []
    @Published var proteinEvents3Days: [NutritionEvent] = []

    @Published var activityEvents3Days: [ActivityOverlayEvent] = []
    @Published var fingerGlucoseEvents3Days: [FingerGlucoseEvent] = []

    @Published var mainChartCacheV1: [MainChartCacheItemV1] = []
    @Published var mainChartCacheLastUpdatedV1: Date? = nil

    @Published var last24hGlucoseMeanMgdl: Double? = nil
    @Published var last24hGlucoseCoverageMinutes: Int = 0
    @Published var last24hGlucoseExpectedMinutes: Int = 1440
    @Published var last24hGlucoseCoverageRatio: Double = 0
    @Published var last24hGlucoseIsPartial: Bool = true

    @Published var last24hGlucoseSdMgdl: Double? = nil
    @Published var last24hGlucoseCvPercent: Double? = nil

    @Published var last24hTIRVeryLowMinutes: Int = 0
    @Published var last24hTIRLowMinutes: Int = 0
    @Published var last24hTIRInRangeMinutes: Int = 0
    @Published var last24hTIRHighMinutes: Int = 0
    @Published var last24hTIRVeryHighMinutes: Int = 0

    @Published var last24hTIRCoverageMinutes: Int = 0
    @Published var last24hTIRExpectedMinutes: Int = 1440
    @Published var last24hTIRCoverageRatio: Double = 0
    @Published var last24hTIRIsPartial: Bool = true

    @Published var todayTIRVeryLowMinutes: Int = 0
    @Published var todayTIRLowMinutes: Int = 0
    @Published var todayTIRInRangeMinutes: Int = 0
    @Published var todayTIRHighMinutes: Int = 0
    @Published var todayTIRVeryHighMinutes: Int = 0

    @Published var todayTIRCoverageMinutes: Int = 0
    @Published var todayTIRExpectedMinutes: Int = 0
    @Published var todayTIRCoverageRatio: Double = 0
    @Published var todayTIRIsPartial: Bool = true

    @Published var todayGlucoseMeanMgdl: Double? = nil
    @Published var todayGlucoseCoverageMinutes: Int = 0
    @Published var todayGlucoseExpectedMinutes: Int = 0
    @Published var todayGlucoseCoverageRatio: Double = 0
    @Published var todayGlucoseIsPartial: Bool = true

    @Published var glucoseMean7dMgdl: Double? = nil
    @Published var glucoseMean14dMgdl: Double? = nil
    @Published var glucoseMean30dMgdl: Double? = nil
    @Published var glucoseMean90dMgdl: Double? = nil

    @Published var glucoseSd7dMgdl: Double? = nil
    @Published var glucoseSd14dMgdl: Double? = nil
    @Published var glucoseSd30dMgdl: Double? = nil
    @Published var glucoseSd90dMgdl: Double? = nil

    @Published var glucoseCv7dPercent: Double? = nil
    @Published var glucoseCv14dPercent: Double? = nil
    @Published var glucoseCv30dPercent: Double? = nil
    @Published var glucoseCv90dPercent: Double? = nil

    @Published var tirTodaySummary: TIRPeriodSummaryEntry? = nil
    @Published var tir7dSummary: TIRPeriodSummaryEntry? = nil
    @Published var tir14dSummary: TIRPeriodSummaryEntry? = nil
    @Published var tir30dSummary: TIRPeriodSummaryEntry? = nil
    @Published var tir90dSummary: TIRPeriodSummaryEntry? = nil

    @Published var dailyGlucoseStats90: [DailyGlucoseStatsEntry] = []
    @Published var dailyTIR90: [DailyTIREntry] = []

    @Published var dailyBolus90: [DailyBolusEntry] = []
    @Published var dailyBasal90: [DailyBasalEntry] = []

    @Published var dailyBolusBasalRatio90: [DailyBolusBasalRatioEntry] = []

    @Published var dailyCarbs90: [DailyCarbsEntry] = []
    @Published var dailyCarbBolusRatio90: [DailyCarbBolusRatioEntry] = []

    @Published var overviewGlucoseDaily7FullDays: [DailyGlucoseStatsEntry] = []
    @Published var overviewTIRDaily7FullDays: [DailyTIREntry] = []
    @Published var mainChartSelectedDayOffsetV1: Int = 0

    // ============================================================
    // MARK: - Preview Caches
    // ============================================================

    var previewDailySteps: [DailyStepsEntry] = []
    var previewDailyActiveEnergy: [ActivityEnergyEntry] = []
    var previewDailyExerciseMinutes: [DailyExerciseMinutesEntry] = []
    var previewDailyWorkoutMinutes: [DailyWorkoutMinutesEntry] = []

    var previewDailyMoveTime: [DailyMoveTimeEntry] = []
    var previewDailySleep: [DailySleepEntry] = []

    var previewDailyWeight: [DailyWeightEntry] = []
    var previewDailyMovementSplit: [DailyMovementSplitEntry] = []   // ✅ FIX (needed by HealthStore+MovementSplitV1)

    var previewDailyCarbs: [DailyCarbsEntry] = []
    var previewDailyProtein: [DailyProteinEntry] = []
    var previewDailyFat: [DailyFatEntry] = []
    var previewDailyNutritionEnergy: [DailyNutritionEnergyEntry] = []

    var previewDailyRestingHeartRate: [RestingHeartRateEntry] = []
    var previewDailyBodyFat: [BodyFatEntry] = []
    var previewDailyBMI: [BMIEntry] = []

    // ============================================================
    // MARK: - Authorization
    // ============================================================

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType             = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType     = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let restingEnergyType    = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
            let exerciseMinutesType  = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            let moveTimeType         = HKQuantityType.quantityType(forIdentifier: .appleMoveTime),
            let standTimeType        = HKQuantityType.quantityType(forIdentifier: .appleStandTime),
            let sleepType            = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType           = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            let bodyFatType          = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
            let bmiType              = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex),
            let carbsType            = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let proteinType          = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            let fatType              = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            let nutritionEnergyType  = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            let insulinDeliveryType  = HKQuantityType.quantityType(forIdentifier: .insulinDelivery),
            let bloodGlucoseType     = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
        else {
            return
        }

        let workoutType = HKObjectType.workoutType()

        healthStore.requestAuthorization(
            toShare: [],
            read: [
                stepType,
                activeEnergyType,
                restingEnergyType,
                exerciseMinutesType,
                moveTimeType,
                standTimeType,
                sleepType,
                weightType,
                restingHeartRateType,
                bodyFatType,
                bmiType,
                carbsType,
                proteinType,
                fatType,
                nutritionEnergyType,
                insulinDeliveryType,
                bloodGlucoseType,
                workoutType
            ]
        ) { success, error in
            if !success {
                print("HealthKit Auth fehlgeschlagen:", error?.localizedDescription ?? "unbekannt")
            }
        }
    }
}

// ============================================================
// MARK: - PREVIEW STORE
// ============================================================

extension HealthStore {
    static func preview() -> HealthStore {
        let store = HealthStore(isPreview: true)
        let _ = Calendar.current.startOfDay(for: Date())
        // Preview-Daten werden weiterhin extern (z.B. im #Preview) gesetzt.
        return store
    }
}

// ============================================================
// MARK: - Recent Workouts Fetch (existing helper)
// ============================================================

extension HealthStore {

    func fetchRecentWorkouts(limit: Int) async -> [HKWorkout] {
        if isPreview { return [] }

        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()

            let sort = NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate,
                ascending: false
            )

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: max(1, limit),
                sortDescriptors: [sort]
            ) { [weak self] _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                DispatchQueue.main.async {
                    self?.recentWorkouts = workouts
                    self?.recentWorkoutsOverview = workouts
                }
                continuation.resume(returning: workouts)
            }

            self.healthStore.execute(query)
        }
    }
}

// ============================================================
// MARK: - Workouts Fetch (History Window 10 days)
// ============================================================

extension HealthStore {

    func fetchRecentWorkoutsForHistoryWindowV1(days: Int = 10, limit: Int = 500) async -> [HKWorkout] { // NEW
        if isPreview { return [] }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(max(1, days) - 1), to: todayStart) ?? todayStart
        let end = Date() // now is fine

        let workoutType = HKObjectType.workoutType()

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: max(1, limit),
                sortDescriptors: [sort]
            ) { [weak self] _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                DispatchQueue.main.async {
                    self?.recentWorkouts = workouts
                    self?.recentWorkoutsOverview = workouts
                }
                continuation.resume(returning: workouts)
            }

            self.healthStore.execute(query)
        }
    }

    func fetchRecentWorkoutsForHistoryWindowV1Async(days: Int = 10) async { // NEW helper
        _ = await fetchRecentWorkoutsForHistoryWindowV1(days: days)
    }
}
