//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

enum DataAvailabilityState: String {
    case noData
    case insufficient
    case partial
    case sufficient
}

final class HealthStore: ObservableObject {

    static let shared = HealthStore()

    let healthStore = HKHealthStore()
    let isPreview: Bool

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    // 🟨 UPDATED: Altlasten entfernt (globale Reconnect/Permission Flags).
    // needsAppleHealthReconnectForCGM / needsAppleHealthReconnectForInsulin / needsAppleHealthReconnectAny / reconnectHintTextV1
    // werden durch metrikspezifische Read-Probes ersetzt (später: stepsReadAuthIssueV1, basalReadAuthIssueV1, ...).

    // MARK: - Published Values für SwiftUI

    @Published var todaySteps: Int = 0
    @Published var last90Days: [DailyStepsEntry] = []
    @Published var monthlySteps: [MonthlyMetricEntry] = []
    @Published var stepsDaily365: [DailyStepsEntry] = []

    @Published var todayActiveEnergy: Int = 0
    @Published var last90DaysActiveEnergy: [ActivityEnergyEntry] = []
    @Published var monthlyActiveEnergy: [MonthlyMetricEntry] = []
    @Published var activeEnergyDaily365: [ActivityEnergyEntry] = []

    @Published var todayRestingEnergyKcal: Int = 0
    @Published var last90DaysRestingEnergy: [RestingEnergyEntry] = []
    @Published var monthlyRestingEnergy: [MonthlyMetricEntry] = []
    @Published var restingEnergyDaily365: [DailyRestingEnergyEntry] = []

    @Published var todayExerciseMinutes: Int = 0
    @Published var last90DaysExerciseMinutes: [DailyExerciseMinutesEntry] = []
    @Published var monthlyExerciseMinutes: [MonthlyMetricEntry] = []
    @Published var activeTimeDaily365: [DailyExerciseMinutesEntry] = []

    @Published var todayMoveTimeMinutes: Int = 0
    @Published var last90DaysMoveTime: [DailyMoveTimeEntry] = []
    @Published var monthlyMoveTime: [MonthlyMetricEntry] = []
    @Published var moveTimeDaily365: [DailyMoveTimeEntry] = []

    @Published var todayWorkoutMinutes: Int = 0
    @Published var last90DaysWorkoutMinutes: [DailyWorkoutMinutesEntry] = []
    @Published var monthlyWorkoutMinutes: [MonthlyMetricEntry] = []
    @Published var workoutMinutesDaily365: [DailyWorkoutMinutesEntry] = []

    @Published var recentWorkouts: [HKWorkout] = []
    @Published var recentWorkoutsOverview: [HKWorkout] = []

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

    @Published var avg7dExerciseMinutesEndingToday: Int = 0
    @Published var avg7dActiveEnergyKcalEndingToday: Int = 0

    @Published var todaySleepMinutes: Int = 0
    @Published var last90DaysSleep: [DailySleepEntry] = []
    @Published var monthlySleep: [MonthlyMetricEntry] = []
    @Published var sleepDaily365: [DailySleepEntry] = []

    @Published var last90DaysSleepSessionsEndingDay: [DailySleepEntry] = []
    @Published var sleepDaily365SessionsEndingDay: [DailySleepEntry] = []

    @Published var todayWeightKgRaw: Double = 0
    @Published var last90DaysWeight: [DailyWeightEntry] = []
    @Published var monthlyWeight: [MonthlyMetricEntry] = []
    @Published var weightDaily365Raw: [DailyWeightEntry] = []
    @Published var recentWeightSamplesForHistoryV1: [WeightSamplePointV1] = []

    @Published var todayRestingHeartRate: Int = 0
    @Published var last90DaysRestingHeartRate: [RestingHeartRateEntry] = []
    @Published var monthlyRestingHeartRate: [MonthlyMetricEntry] = []
    @Published var restingHeartRateDaily365: [RestingHeartRateEntry] = []

    @Published var todayBodyFatPercent: Double = 0
    @Published var last90DaysBodyFat: [BodyFatEntry] = []
    @Published var monthlyBodyFat: [MonthlyMetricEntry] = []
    @Published var bodyFatDaily365: [BodyFatEntry] = []

    @Published var todayBMI: Double = 0
    @Published var last90DaysBMI: [BMIEntry] = []
    @Published var monthlyBMI: [MonthlyMetricEntry] = []
    @Published var bmiDaily365: [BMIEntry] = []

    @Published var todayCarbsGrams: Int = 0
    @Published var last90DaysCarbs: [DailyCarbsEntry] = []
    @Published var monthlyCarbs: [MonthlyMetricEntry] = []
    @Published var carbsDaily365: [DailyCarbsEntry] = []

    @Published var todayProteinGrams: Int = 0
    @Published var last90DaysProtein: [DailyProteinEntry] = []
    @Published var monthlyProtein: [MonthlyMetricEntry] = []
    @Published var proteinDaily365: [DailyProteinEntry] = []

    @Published var todayFatGrams: Int = 0
    @Published var last90DaysFat: [DailyFatEntry] = []
    @Published var monthlyFat: [MonthlyMetricEntry] = []
    @Published var fatDaily365: [DailyFatEntry] = []

    @Published var todayNutritionEnergyKcal: Int = 0
    @Published var last90DaysNutritionEnergy: [DailyNutritionEnergyEntry] = []
    @Published var monthlyNutritionEnergy: [MonthlyMetricEntry] = []
    @Published var nutritionEnergyDaily365: [DailyNutritionEnergyEntry] = []

    @Published var todaySugarGrams: Int = 0
    @Published var last90DaysSugar: [DailySugarEntry] = []
    @Published var monthlySugar: [MonthlyMetricEntry] = []
    @Published var sugarDaily365: [DailySugarEntry] = []

    // 🟨 NEW: Carbs Split (Chart-only metric)
    @Published var carbsDaypartsDaily90V1: [DailyCarbsByDaypartEntryV1] = []
    @Published var carbsDaypartsPeriodAveragesV1: [CarbsDaypartPeriodAverageEntryV1] = []

    // MARK: - METABOLIC DOMAIN (V1) — Published State (SSoT)

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

    // 🟨 NEW: History Window (10 days) — independent from MainChartCache
    @Published var carbEventsHistoryWindowV1: [NutritionEvent] = []
    @Published var bolusEventsHistoryWindowV1: [InsulinBolusEvent] = []
    @Published var basalEventsHistoryWindowV1: [InsulinBasalEvent] = []
    @Published var cgmSamplesHistoryWindowV1: [CGMSamplePoint] = []   // 🟨 NEW: History markers (10 days)

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

    @Published var rollingGlucoseSdMgdl7: Double?
    @Published var rollingGlucoseSdMgdl14: Double?
    @Published var rollingGlucoseSdMgdl30: Double?
    @Published var rollingGlucoseSdMgdl90: Double?

    @Published var rollingGlucoseCvPercent7: Double?
    @Published var rollingGlucoseCvPercent14: Double?
    @Published var rollingGlucoseCvPercent30: Double?
    @Published var rollingGlucoseCvPercent90: Double?

    // ============================================================
    // MARK: - Metric Read Auth Issues (V1) — set ONLY by read queries
    // ============================================================

    @Published var stepsReadAuthIssueV1: Bool = false
    @Published var workoutMinutesReadAuthIssueV1: Bool = false
    @Published var activeEnergyReadAuthIssueV1: Bool = false
    @Published var standTimeReadAuthIssueV1: Bool = false // 🟨 NEW
    @Published var exerciseTimeReadAuthIssueV1: Bool = false // 🟨 NEW
    @Published var activityBadgeSourcesResolvedV1: Bool = false // 🟨 UPDATED
    @Published var bodyBadgeSourcesResolvedV1: Bool = false // 🟨 UPDATED
    @Published var nutritionBadgeSourcesResolvedV1: Bool = false // 🟨 UPDATED

    // ✅ NEW (Body)
    @Published var weightReadAuthIssueV1: Bool = false
    @Published var sleepReadAuthIssueV1: Bool = false
    @Published var bmiReadAuthIssueV1: Bool = false
    @Published var bodyFatReadAuthIssueV1: Bool = false
    @Published var restingHeartRateReadAuthIssueV1: Bool = false

    // existing:
    @Published var basalReadAuthIssueV1: Bool = false
    @Published var bolusReadAuthIssueV1: Bool = false
    @Published var glucoseReadAuthIssueV1: Bool = false
    @Published var carbsReadAuthIssueV1: Bool = false
    @Published var proteinReadAuthIssueV1: Bool = false
    @Published var fatReadAuthIssueV1: Bool = false
    @Published var nutritionEnergyReadAuthIssueV1: Bool = false
    @Published var sugarReadAuthIssueV1: Bool = false

    // ============================================================
    // MARK: - Central Badge Sources (V1) — Domain aggregation
    // ============================================================

    var metabolicGlucoseAuthIssueAnyV1: Bool {
        glucoseAnyAttentionForBadgesV1
    }

    var metabolicTherapyAuthIssueAnyV1: Bool {
        basalReadAuthIssueV1 || bolusReadAuthIssueV1
    }

    var metabolicCarbsAuthIssueAnyV1: Bool {
        carbsReadAuthIssueV1
    }

    var metabolicAnyAuthIssueForBadgesV1: Bool {
        metabolicGlucoseAuthIssueAnyV1
            || metabolicTherapyAuthIssueAnyV1
            || metabolicCarbsAuthIssueAnyV1
    }

    private var carbsHasAnyHistoryForBadgesV1: Bool {
        last90DaysCarbs.contains { $0.grams > 0 } ||
        carbsDaily365.contains { $0.grams > 0 }
    }

    private var sugarHasAnyHistoryForBadgesV1: Bool {
        last90DaysSugar.contains { $0.grams > 0 } ||
        sugarDaily365.contains { $0.grams > 0 }
    }

    private var proteinHasAnyHistoryForBadgesV1: Bool {
        last90DaysProtein.contains { $0.grams > 0 } ||
        proteinDaily365.contains { $0.grams > 0 }
    }

    private var fatHasAnyHistoryForBadgesV1: Bool {
        last90DaysFat.contains { $0.grams > 0 } ||
        fatDaily365.contains { $0.grams > 0 }
    }

    private var nutritionEnergyHasAnyHistoryForBadgesV1: Bool {
        last90DaysNutritionEnergy.contains(where: { entry in entry.energyKcal > 0 }) ||
        nutritionEnergyDaily365.contains(where: { entry in entry.energyKcal > 0 })
    }

    var carbsAnyAttentionForBadgesV1: Bool {
        carbsReadAuthIssueV1 ||
        (todayCarbsGrams == 0 && !carbsHasAnyHistoryForBadgesV1)
    }

    var sugarAnyAttentionForBadgesV1: Bool {
        sugarReadAuthIssueV1 ||
        (todaySugarGrams == 0 && !sugarHasAnyHistoryForBadgesV1)
    }

    var proteinAnyAttentionForBadgesV1: Bool {
        proteinReadAuthIssueV1 ||
        (todayProteinGrams == 0 && !proteinHasAnyHistoryForBadgesV1)
    }

    var fatAnyAttentionForBadgesV1: Bool {
        fatReadAuthIssueV1 ||
        (todayFatGrams == 0 && !fatHasAnyHistoryForBadgesV1)
    }

    var nutritionEnergyAnyAttentionForBadgesV1: Bool {
        nutritionEnergyReadAuthIssueV1 ||
        (todayNutritionEnergyKcal == 0 && !nutritionEnergyHasAnyHistoryForBadgesV1)
    }

    var nutritionAnyAuthIssueForBadgesV1: Bool {
        guard nutritionBadgeSourcesResolvedV1 else { return false } // 🟨 UPDATED

        return
            carbsAnyAttentionForBadgesV1
            || sugarAnyAttentionForBadgesV1
            || proteinAnyAttentionForBadgesV1
            || fatAnyAttentionForBadgesV1
            || nutritionEnergyAnyAttentionForBadgesV1
    }

    private var glucoseHasAnyHistoryForBadgesV1: Bool {
        dailyGlucoseStats90.contains { $0.coverageMinutes > 0 }
    }

    private var stepsHasAnyHistoryForBadgesV1: Bool {
        last90Days.contains { $0.steps > 0 } ||
        stepsDaily365.contains { $0.steps > 0 }
    }

    private var workoutMinutesHasAnyHistoryForBadgesV1: Bool {
        last90DaysWorkoutMinutes.contains { $0.minutes > 0 } ||
        workoutMinutesDaily365.contains { $0.minutes > 0 }
    }

    private var activeEnergyHasAnyHistoryForBadgesV1: Bool {
        last90DaysActiveEnergy.contains { $0.activeEnergy > 0 } ||
        activeEnergyDaily365.contains { $0.activeEnergy > 0 }
    }

    private var movementSplitHasAnyHistoryForBadgesV1: Bool {
        movementSplitDaily365.contains {
            ($0.sleepMorningMinutes + $0.sleepEveningMinutes + $0.activeMinutes) > 0
        }
    }

    private var bolusHasAnyHistoryForBadgesV1: Bool {
        dailyBolus90.contains { $0.bolusUnits > 0 }
    }

    private var basalHasAnyHistoryForBadgesV1: Bool {
        dailyBasal90.contains { $0.basalUnits > 0 }
    }

    private var weightHasAnyHistoryForBadgesV1: Bool { // 🟨 UPDATED
        last90DaysWeight.contains { $0.kg > 0 } ||
        weightDaily365Raw.contains { $0.kg > 0 }
    }

    private var restingHeartRateHasAnyHistoryForBadgesV1: Bool {
        last90DaysRestingHeartRate.contains { $0.restingHeartRate > 0 } ||
        restingHeartRateDaily365.contains { $0.restingHeartRate > 0 }
    }

    private var sleepHasAnyHistoryForBadgesV1: Bool {
        last90DaysSleep.contains { $0.minutes > 0 } ||
        sleepDaily365.contains { $0.minutes > 0 } ||
        last90DaysSleepSessionsEndingDay.contains { $0.minutes > 0 } ||
        sleepDaily365SessionsEndingDay.contains { $0.minutes > 0 }
    }

    private var bmiHasAnyHistoryForBadgesV1: Bool {
        last90DaysBMI.contains { $0.bmi > 0 } ||
        bmiDaily365.contains { $0.bmi > 0 }
    }

    private var bodyFatHasAnyHistoryForBadgesV1: Bool {
        last90DaysBodyFat.contains { $0.bodyFatPercent > 0 } ||
        bodyFatDaily365.contains { $0.bodyFatPercent > 0 }
    }

    var glucoseAnyAttentionForBadgesV1: Bool {
        glucoseReadAuthIssueV1 ||
        (todayGlucoseCoverageMinutes == 0 && !glucoseHasAnyHistoryForBadgesV1)
    }

    var stepsAnyAttentionForBadgesV1: Bool {
        stepsReadAuthIssueV1 ||
        (todaySteps == 0 && !stepsHasAnyHistoryForBadgesV1)
    }

    var workoutMinutesAnyAttentionForBadgesV1: Bool {
        workoutMinutesReadAuthIssueV1 ||
        (todayWorkoutMinutes == 0 && !workoutMinutesHasAnyHistoryForBadgesV1)
    }

    var activeEnergyAnyAttentionForBadgesV1: Bool {
        activeEnergyReadAuthIssueV1 ||
        (todayActiveEnergy == 0 && !activeEnergyHasAnyHistoryForBadgesV1)
    }

    var movementSplitAnyAttentionForBadgesV1: Bool {
        let activeBlockMissing =
            standTimeReadAuthIssueV1 &&
            exerciseTimeReadAuthIssueV1 &&
            workoutMinutesReadAuthIssueV1

        return
            sleepReadAuthIssueV1 ||
            activeBlockMissing ||
            (
                todaySleepSplitMinutes == 0 &&
                todayMoveMinutes == 0 &&
                !movementSplitHasAnyHistoryForBadgesV1
            )
    }

    private var todayBolusValueForBadgesV1: Double {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return dailyBolus90.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.bolusUnits ?? 0
    }

    private var todayBasalValueForBadgesV1: Double {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return dailyBasal90.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.basalUnits ?? 0
    }

    var bolusAnyAttentionForBadgesV1: Bool {
        bolusReadAuthIssueV1 ||
        ((dailyBolus90.isEmpty || todayBolusValueForBadgesV1 == 0) && !bolusHasAnyHistoryForBadgesV1)
    }

    var basalAnyAttentionForBadgesV1: Bool {
        basalReadAuthIssueV1 ||
        ((dailyBasal90.isEmpty || todayBasalValueForBadgesV1 == 0) && !basalHasAnyHistoryForBadgesV1)
    }

    var metabolicTherapyAnyAttentionForBadgesV1: Bool {
        bolusAnyAttentionForBadgesV1 || basalAnyAttentionForBadgesV1
    }

    var metabolicAnyAttentionForBadgesV1: Bool {
        metabolicGlucoseAuthIssueAnyV1
            || metabolicTherapyAnyAttentionForBadgesV1
            || metabolicCarbsAuthIssueAnyV1
    }

    var activityAnyAuthIssueForBadgesV1: Bool {
        guard activityBadgeSourcesResolvedV1 else { return false } // 🟨 UPDATED

        return
            stepsAnyAttentionForBadgesV1
            || workoutMinutesAnyAttentionForBadgesV1
            || activeEnergyAnyAttentionForBadgesV1
            || movementSplitAnyAttentionForBadgesV1
    }

    var weightAnyAttentionForBadgesV1: Bool {
        weightReadAuthIssueV1 ||
        (todayWeightKgRaw == 0 && !weightHasAnyHistoryForBadgesV1)
    }

    var sleepAnyAttentionForBadgesV1: Bool {
        sleepReadAuthIssueV1 ||
        (todaySleepMinutes == 0 && !sleepHasAnyHistoryForBadgesV1)
    }

    var bmiAnyAttentionForBadgesV1: Bool {
        bmiReadAuthIssueV1 ||
        (todayBMI == 0 && !bmiHasAnyHistoryForBadgesV1)
    }

    var bodyFatAnyAttentionForBadgesV1: Bool {
        bodyFatReadAuthIssueV1 ||
        (todayBodyFatPercent == 0 && !bodyFatHasAnyHistoryForBadgesV1)
    }

    var restingHeartRateAnyAttentionForBadgesV1: Bool {
        restingHeartRateReadAuthIssueV1 ||
        (todayRestingHeartRate == 0 && !restingHeartRateHasAnyHistoryForBadgesV1)
    }

    var bodyAnyAuthIssueForBadgesV1: Bool {
        guard bodyBadgeSourcesResolvedV1 else { return false } // 🟨 UPDATED

        return
            weightAnyAttentionForBadgesV1
            || sleepAnyAttentionForBadgesV1
            || bmiAnyAttentionForBadgesV1
            || bodyFatAnyAttentionForBadgesV1
            || restingHeartRateAnyAttentionForBadgesV1
    }

    var anyDomainAuthIssueForBadgesV1: Bool {
        metabolicAnyAttentionForBadgesV1
            || nutritionAnyAuthIssueForBadgesV1
            || activityAnyAuthIssueForBadgesV1
            || bodyAnyAuthIssueForBadgesV1
    }

    var anyAuthIssueForBadgesV1: Bool {
        anyDomainAuthIssueForBadgesV1
    }
    
    // MARK: - Preview Caches

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
}

extension HealthStore {
    static func preview() -> HealthStore {
        let store = HealthStore(isPreview: true)
        let _ = Calendar.current.startOfDay(for: Date())
        return store
    }
}

extension HealthStore {

    @MainActor
    var isDebugSimulatingNoHealthDataV1: Bool { // 🟨 NEW
        SettingsModel.shared.debugSimulateNoHealthData
    }

    @MainActor
    func applyDebugSimulatedNoHealthDataV1() { // 🟨 NEW
        // Activity
        todaySteps = 0
        last90Days = []
        monthlySteps = []
        stepsDaily365 = []

        todayActiveEnergy = 0
        last90DaysActiveEnergy = []
        monthlyActiveEnergy = []
        activeEnergyDaily365 = []

        todayRestingEnergyKcal = 0
        last90DaysRestingEnergy = []
        monthlyRestingEnergy = []
        restingEnergyDaily365 = []

        todayExerciseMinutes = 0
        last90DaysExerciseMinutes = []
        monthlyExerciseMinutes = []
        activeTimeDaily365 = []

        todayMoveTimeMinutes = 0
        last90DaysMoveTime = []
        monthlyMoveTime = []
        moveTimeDaily365 = []

        todayWorkoutMinutes = 0
        last90DaysWorkoutMinutes = []
        monthlyWorkoutMinutes = []
        workoutMinutesDaily365 = []

        recentWorkouts = []
        recentWorkoutsOverview = []

        todayMoveMinutes = 0
        todaySedentaryMinutes = 0
        todaySleepSplitMinutes = 0
        movementSplitDaily30 = []
        movementSplitDaily365 = []
        movementSplitActiveSourceTodayV1 = .none
        avg7dExerciseMinutesEndingToday = 0
        avg7dActiveEnergyKcalEndingToday = 0
        activityBadgeSourcesResolvedV1 = true // 🟨 UPDATED
        bodyBadgeSourcesResolvedV1 = true // 🟨 UPDATED
        nutritionBadgeSourcesResolvedV1 = true // 🟨 UPDATED

        // Body
        todaySleepMinutes = 0
        last90DaysSleep = []
        monthlySleep = []
        sleepDaily365 = []
        last90DaysSleepSessionsEndingDay = []
        sleepDaily365SessionsEndingDay = []

        todayWeightKgRaw = 0
        last90DaysWeight = []
        monthlyWeight = []
        weightDaily365Raw = []
        recentWeightSamplesForHistoryV1 = []

        todayRestingHeartRate = 0
        last90DaysRestingHeartRate = []
        monthlyRestingHeartRate = []
        restingHeartRateDaily365 = []

        todayBodyFatPercent = 0
        last90DaysBodyFat = []
        monthlyBodyFat = []
        bodyFatDaily365 = []

        todayBMI = 0
        last90DaysBMI = []
        monthlyBMI = []
        bmiDaily365 = []

        // Nutrition
        todayCarbsGrams = 0
        last90DaysCarbs = []
        monthlyCarbs = []
        carbsDaily365 = []

        todayProteinGrams = 0
        last90DaysProtein = []
        monthlyProtein = []
        proteinDaily365 = []

        todayFatGrams = 0
        last90DaysFat = []
        monthlyFat = []
        fatDaily365 = []

        todayNutritionEnergyKcal = 0
        last90DaysNutritionEnergy = []
        monthlyNutritionEnergy = []
        nutritionEnergyDaily365 = []

        todaySugarGrams = 0
        last90DaysSugar = []
        monthlySugar = []
        sugarDaily365 = []

        carbsDaypartsDaily90V1 = []
        carbsDaypartsPeriodAveragesV1 = []

        // Metabolic
        dailyRange90 = []

        rangeTodaySummary = nil
        range7dSummary = nil
        range14dSummary = nil
        range30dSummary = nil
        range90dSummary = nil

        cgmSamples3Days = []
        bolusEvents3Days = []
        basalEvents3Days = []

        carbEvents3Days = []
        proteinEvents3Days = []

        activityEvents3Days = []
        fingerGlucoseEvents3Days = []

        carbEventsHistoryWindowV1 = []
        bolusEventsHistoryWindowV1 = []
        basalEventsHistoryWindowV1 = []
        cgmSamplesHistoryWindowV1 = []

        mainChartCacheV1 = []
        mainChartCacheLastUpdatedV1 = nil

        last24hGlucoseMeanMgdl = nil
        last24hGlucoseCoverageMinutes = 0
        last24hGlucoseExpectedMinutes = 1440
        last24hGlucoseCoverageRatio = 0
        last24hGlucoseIsPartial = true

        last24hGlucoseSdMgdl = nil
        last24hGlucoseCvPercent = nil

        last24hTIRVeryLowMinutes = 0
        last24hTIRLowMinutes = 0
        last24hTIRInRangeMinutes = 0
        last24hTIRHighMinutes = 0
        last24hTIRVeryHighMinutes = 0

        last24hTIRCoverageMinutes = 0
        last24hTIRExpectedMinutes = 1440
        last24hTIRCoverageRatio = 0
        last24hTIRIsPartial = true

        todayTIRVeryLowMinutes = 0
        todayTIRLowMinutes = 0
        todayTIRInRangeMinutes = 0
        todayTIRHighMinutes = 0
        todayTIRVeryHighMinutes = 0

        todayTIRCoverageMinutes = 0
        todayTIRExpectedMinutes = 0
        todayTIRCoverageRatio = 0
        todayTIRIsPartial = true

        todayGlucoseMeanMgdl = nil
        todayGlucoseCoverageMinutes = 0
        todayGlucoseExpectedMinutes = 0
        todayGlucoseCoverageRatio = 0
        todayGlucoseIsPartial = true

        glucoseMean7dMgdl = nil
        glucoseMean14dMgdl = nil
        glucoseMean30dMgdl = nil
        glucoseMean90dMgdl = nil

        tirTodaySummary = nil
        tir7dSummary = nil
        tir14dSummary = nil
        tir30dSummary = nil
        tir90dSummary = nil

        dailyGlucoseStats90 = []
        dailyTIR90 = []

        dailyBolus90 = []
        dailyBasal90 = []
        dailyBolusBasalRatio90 = []

        dailyCarbs90 = []
        dailyCarbBolusRatio90 = []

        overviewGlucoseDaily7FullDays = []
        overviewTIRDaily7FullDays = []
        mainChartSelectedDayOffsetV1 = 0

        rollingGlucoseSdMgdl7 = nil
        rollingGlucoseSdMgdl14 = nil
        rollingGlucoseSdMgdl30 = nil
        rollingGlucoseSdMgdl90 = nil

        rollingGlucoseCvPercent7 = nil
        rollingGlucoseCvPercent14 = nil
        rollingGlucoseCvPercent30 = nil
        rollingGlucoseCvPercent90 = nil

        // IMPORTANT:
        // Auth issue flags are intentionally NOT modified here.
        // This debug mode simulates "no readable data", not fake permission denial.
    }
}

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

extension HealthStore {

    func fetchRecentWorkoutsForHistoryWindowV1(days: Int = 10, limit: Int = 500) async -> [HKWorkout] {
        if isPreview { return [] }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(max(1, days) - 1), to: todayStart) ?? todayStart

        let workoutType = HKObjectType.workoutType()

        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

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

    func fetchRecentWorkoutsForHistoryWindowV1Async(days: Int = 10) async {
        _ = await fetchRecentWorkoutsForHistoryWindowV1(days: days)
    }
}
