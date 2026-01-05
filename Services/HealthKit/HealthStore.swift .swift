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
    @Published var todayRestingEnergyKcal: Int = 0                                    // !!! NEW
    @Published var last90DaysRestingEnergy: [RestingEnergyEntry] = []                 // !!! NEW
    @Published var monthlyRestingEnergy: [MonthlyMetricEntry] = []                    // !!! NEW
    @Published var restingEnergyDaily365: [DailyRestingEnergyEntry] = []              // !!! NEW

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

    @Published var recentWorkoutsOverview: [HKWorkout] = []

    // -------------------------
    // 🔵 SLEEP (Minuten)
    // -------------------------
    @Published var todaySleepMinutes: Int = 0
    @Published var last90DaysSleep: [DailySleepEntry] = []
    @Published var monthlySleep: [MonthlyMetricEntry] = []
    @Published var sleepDaily365: [DailySleepEntry] = []

    // ------------------------------------------------------------
    // !!! NEW: Session-based Series (Sleep session ending that day)
    // - NICHT für MovementSplit verwenden
    // - Nur für Sleep KPI/Charts (Session-Logik)
    // ------------------------------------------------------------
    @Published var last90DaysSleepSessionsEndingDay: [DailySleepEntry] = []     // !!! NEW
    @Published var sleepDaily365SessionsEndingDay: [DailySleepEntry] = []       // !!! NEW

    // -------------------------
    // 🟠 WEIGHT (kg) — V1
    // -------------------------
    @Published var todayWeightKgRaw: Double = 0
    @Published var last90DaysWeight: [DailyWeightEntry] = []
    @Published var monthlyWeight: [MonthlyMetricEntry] = []
    @Published var weightDaily365Raw: [DailyWeightEntry] = []

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

    // -------------------------
    // 🩸 RAW3DAYS (Today/Yesterday/DayBefore) — DayProfile Overlay
    // -------------------------
    @Published var cgmSamples3Days: [CGMSamplePoint] = []                       // !!! NEW
    @Published var bolusEvents3Days: [InsulinBolusEvent] = []                   // !!! NEW
    @Published var basalEvents3Days: [InsulinBasalEvent] = []                   // CHANGE: Segments -> Events

    @Published var carbEvents3Days: [NutritionEvent] = []                       // !!! NEW
    @Published var proteinEvents3Days: [NutritionEvent] = []                    // !!! NEW

    @Published var activityEvents3Days: [ActivityOverlayEvent] = []             // !!! NEW
    @Published var fingerGlucoseEvents3Days: [FingerGlucoseEvent] = []          // !!! NEW (optional)

    // -------------------------
    // MainChart Cache (V1) — stored state MUST be in HealthStore (no stored props in Extensions)
    // -------------------------
    @Published var mainChartCacheV1: [MainChartCacheItemV1] = []                // NEW
    @Published var mainChartCacheLastUpdatedV1: Date? = nil                     // NEW

    // ============================================================
    // CGM — QUICK KPIs + PERIOD STATE (SSoT = HealthStore Published)
    // ============================================================
    //
    // Enthält NUR State (berechnete Werte), keine DailyStats-Berechnung hier.
    // Berechnung passiert in:
    // - HealthStore+CGMV1.swift (RAW → Today + Last24h + Period RAW-derived)
    // - HealthStore+CGMTIRV1.swift (HYBRID Period Builder für TIR aus dailyTIR90 + todayTIR*)
    //
    // ============================================================


    // ============================================================
    // MARK: - LAST 24H — Glucose Quick KPI (RAW-based)
    // - Mean mg/dL (Last 24h)
    // - Coverage Minutes (Samples * 5, capped to 1440)
    // ============================================================

    @Published var last24hGlucoseMeanMgdl: Double? = nil
    @Published var last24hGlucoseCoverageMinutes: Int = 0
    @Published var last24hGlucoseExpectedMinutes: Int = 1440
    @Published var last24hGlucoseCoverageRatio: Double = 0
    @Published var last24hGlucoseIsPartial: Bool = true

    // --- Variability (Last 24h)
    @Published var last24hGlucoseSdMgdl: Double? = nil                        // SD (mg/dL)  // !!! NEW (falls nicht schon vorhanden)
    @Published var last24hGlucoseCvPercent: Double? = nil                     // CV (%)      // !!! NEW


    // ============================================================
    // MARK: - LAST 24H — TIR Quick KPI (RAW-based)
    // - Minutenbasiert (Samples * 5)
    // - Nur vorhandene Samples zählen (keine Hochrechnung auf 288)
    // ============================================================

    @Published var last24hTIRVeryLowMinutes: Int = 0
    @Published var last24hTIRLowMinutes: Int = 0
    @Published var last24hTIRInRangeMinutes: Int = 0
    @Published var last24hTIRHighMinutes: Int = 0
    @Published var last24hTIRVeryHighMinutes: Int = 0

    @Published var last24hTIRCoverageMinutes: Int = 0
    @Published var last24hTIRExpectedMinutes: Int = 1440
    @Published var last24hTIRCoverageRatio: Double = 0
    @Published var last24hTIRIsPartial: Bool = true


    // ============================================================
    // MARK: - TODAY — TIR Quick KPI (00:00 → now) ✅ required for HYBRID periods
    // - Minutenbasiert (Samples * 5)
    // - Nur vorhandene Samples zählen (keine Hochrechnung auf 288)
    // ============================================================

    @Published var todayTIRVeryLowMinutes: Int = 0
    @Published var todayTIRLowMinutes: Int = 0
    @Published var todayTIRInRangeMinutes: Int = 0
    @Published var todayTIRHighMinutes: Int = 0
    @Published var todayTIRVeryHighMinutes: Int = 0

    @Published var todayTIRCoverageMinutes: Int = 0
    @Published var todayTIRExpectedMinutes: Int = 0
    @Published var todayTIRCoverageRatio: Double = 0
    @Published var todayTIRIsPartial: Bool = true


    // ============================================================
    // MARK: - TODAY — Glucose Quick KPI (RAW-based; 00:00 → now)
    // - Mean mg/dL (Today)
    // - Coverage Minutes (Samples * 5, capped to expected)
    // ============================================================

    @Published var todayGlucoseMeanMgdl: Double? = nil
    @Published var todayGlucoseCoverageMinutes: Int = 0
    @Published var todayGlucoseExpectedMinutes: Int = 0
    @Published var todayGlucoseCoverageRatio: Double = 0
    @Published var todayGlucoseIsPartial: Bool = true


    // ============================================================
    // MARK: - PERIOD KPIs — CGM (RAW-derived, no DailyStats)
    // - Glucose Mean / SD / CV for 7/14/30/90
    // - TIR Summaries (computed elsewhere / wrapper state)
    // ============================================================

    // --- Glucose Mean (mg/dL)
    @Published var glucoseMean7dMgdl: Double? = nil
    @Published var glucoseMean14dMgdl: Double? = nil
    @Published var glucoseMean30dMgdl: Double? = nil                            // !!! NEW
    @Published var glucoseMean90dMgdl: Double? = nil                            // !!! NEW

    // --- Glucose SD (mg/dL)
    @Published var glucoseSd7dMgdl: Double? = nil
    @Published var glucoseSd14dMgdl: Double? = nil
    @Published var glucoseSd30dMgdl: Double? = nil
    @Published var glucoseSd90dMgdl: Double? = nil

    // --- Glucose CV (%)
    @Published var glucoseCv7dPercent: Double? = nil                            // !!! NEW
    @Published var glucoseCv14dPercent: Double? = nil                           // !!! NEW
    @Published var glucoseCv30dPercent: Double? = nil                           // !!! NEW
    @Published var glucoseCv90dPercent: Double? = nil                           // !!! NEW

    // --- TIR Summaries (State only)
    @Published var tirTodaySummary: TIRPeriodSummaryEntry? = nil
    @Published var tir7dSummary: TIRPeriodSummaryEntry? = nil
    @Published var tir14dSummary: TIRPeriodSummaryEntry? = nil
    @Published var tir30dSummary: TIRPeriodSummaryEntry? = nil
    @Published var tir90dSummary: TIRPeriodSummaryEntry? = nil


    // ============================================================
    // MARK: - DAILYSTATS90 (≥90 Tage) — Trends / Rolling / Ratios
    // ============================================================

    @Published var dailyGlucoseStats90: [DailyGlucoseStatsEntry] = []
    @Published var dailyTIR90: [DailyTIREntry] = []

    @Published var dailyBolus90: [DailyBolusEntry] = []
    @Published var dailyBasal90: [DailyBasalEntry] = []

    @Published var dailyBolusBasalRatio90: [DailyBolusBasalRatioEntry] = []

    @Published var dailyCarbs90: [DailyCarbsEntry] = []
    @Published var dailyCarbBolusRatio90: [DailyCarbBolusRatioEntry] = []

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
    var previewDailyMovementSplit: [DailyMovementSplitEntry] = []

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
            let bloodGlucoseType     = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)   // !!! NEW
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
        ) { [weak self] success, error in
            guard let self else { return }

            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }

                    // ----------------------------------------------------
                    // STEPS (V1)
                    // ----------------------------------------------------
                    self.fetchStepsTodayV1()
                    self.fetchLast90DaysStepsV1()
                    self.fetchMonthlyStepsV1()
                    self.fetchStepsDaily365V1()

                    // ----------------------------------------------------
                    // ACTIVITY ENERGY (V1)
                    // ----------------------------------------------------
                    self.fetchActiveEnergyTodayV1()
                    self.fetchLast90DaysActiveEnergyV1()
                    self.fetchMonthlyActiveEnergyV1()
                    self.fetchActiveEnergyDaily365V1()

                    // ----------------------------------------------------
                    // RESTING ENERGY (V1)
                    // ----------------------------------------------------
                    self.fetchRestingEnergyTodayV1()                                       // !!! NEW
                    self.fetchLast90DaysRestingEnergyV1()                                  // !!! NEW
                    self.fetchMonthlyRestingEnergyV1()                                     // !!! NEW
                    self.fetchRestingEnergyDaily365V1()                                    // !!! NEW

                    // ----------------------------------------------------
                    // EXERCISE TIME (V1)
                    // ----------------------------------------------------
                    self.todayExerciseMinutes = 0
                    self.last90DaysExerciseMinutes = []
                    self.monthlyExerciseMinutes = []
                    self.fetchExerciseTimeDaily365V1()

                    // ----------------------------------------------------
                    // MOVEMENT SPLIT (V1)
                    // ----------------------------------------------------
                    self.movementSplitActiveSourceTodayV1 = .none
                    self.fetchMovementSplitDaily365V1(last: 3, completion: nil)

                    // ----------------------------------------------------
                    // SLEEP (V1)
                    // ----------------------------------------------------
                    self.fetchSleepTodayV1()
                    self.fetchLast90DaysSleepV1()
                    self.fetchMonthlySleepV1()
                    self.fetchSleepDaily365V1()

                    // ----------------------------------------------------
                    // WEIGHT (V1)
                    // ----------------------------------------------------
                    self.fetchWeightTodayV1()
                    self.fetchLast90DaysWeightV1()
                    self.fetchMonthlyWeightV1()
                    self.fetchWeightDaily365RawV1()

                    // ----------------------------------------------------
                    // RESTING HEART RATE (V1)
                    // ----------------------------------------------------
                    self.fetchRestingHeartRateTodayV1()
                    self.fetchLast90DaysRestingHeartRateV1()
                    self.fetchMonthlyRestingHeartRateV1()
                    self.fetchRestingHeartRateDaily365V1()

                    // ----------------------------------------------------
                    // BODY FAT (V1)
                    // ----------------------------------------------------
                    self.fetchBodyFatTodayV1()
                    self.fetchLast90DaysBodyFatV1()
                    self.fetchMonthlyBodyFatV1()
                    self.fetchBodyFatDaily365V1()

                    // ----------------------------------------------------
                    // BMI (V1)
                    // ----------------------------------------------------
                    self.fetchBMITodayV1()
                    self.fetchLast90DaysBMIV1()
                    self.fetchMonthlyBMIV1()
                    self.fetchBMIDaily365V1()

                    // ----------------------------------------------------
                    // NUTRITION (V1)
                    // ----------------------------------------------------
                    self.fetchCarbsTodayV1()
                    self.fetchLast90DaysCarbsV1()
                    self.fetchMonthlyCarbsV1()
                    self.fetchCarbsDaily365V1()

                    self.fetchProteinTodayV1()
                    self.fetchLast90DaysProteinV1()
                    self.fetchMonthlyProteinV1()
                    self.fetchProteinDaily365V1()

                    self.fetchFatTodayV1()
                    self.fetchLast90DaysFatV1()
                    self.fetchMonthlyFatV1()
                    self.fetchFatDaily365V1()

                    self.fetchNutritionEnergyTodayV1()
                    self.fetchLast90DaysNutritionEnergyV1()
                    self.fetchMonthlyNutritionEnergyV1()
                    self.fetchNutritionEnergyDaily365V1()
                }

            } else {
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
        // ... (Rest deiner Preview-Logik unverändert lassen)
        return store
    }
}

// ============================================================
// MARK: - Recent Workouts (needed by ActivityOverviewViewModelV1)
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
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            self.healthStore.execute(query)
        }
    }
}
