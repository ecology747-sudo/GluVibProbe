//
//  HealthStore+Bootstrap.swift
//  GluVibProbe
//
//  Bootstrap / Refresh Orchestration (SSoT: HealthStore)
//
//  Purpose
//  - Central entry points for refreshing all domains (Activity / Body / Nutrition / Metabolic / History).
//  - Ensures deterministic “Today” KPIs + charts refresh pipelines and staged loading (Stage A blocking, Stage B/C deferred).
//  - Sets global permission-badge surfaces via metric-specific read probes (probe*ReadAuthIssue* async).
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → ViewModels (mapping) → Views
//
//  Notes
//  - Views/VMs do NOT call HealthKit directly.
//  - Read auth issue flags are set ONLY by dedicated probe functions in metric files.
//  - Sugar is integrated as Nutrition metric (subset of Carbs in UI semantics; handled in UI, not here).
//

import Foundation
import HealthKit
import OSLog // 🟨 UPDATED

extension HealthStore {

    // ============================================================
    // MARK: - Types
    // ============================================================

    enum RefreshContext: String {
        case appLaunch
        case pullToRefresh
        case navigation
        case periodic
    }

    // ============================================================
    // MARK: - Capability Gates (Central Trust Gates)
    // ============================================================

    @MainActor
    private var hasEffectiveMetabolicAccessV1: Bool {
        SettingsModel.shared.hasMetabolicPremiumEffective
    }

    @MainActor
    private var hasCGMEnabledV1: Bool {
        let s = SettingsModel.shared
        return s.hasCGM && hasEffectiveMetabolicAccessV1
    }

    @MainActor
    private var hasInsulinEnabledV1: Bool {
        let s = SettingsModel.shared
        return hasCGMEnabledV1 && s.isInsulinTreated
    }

    @MainActor
    private func logBootstrapStatusV1(prefix: String, context: RefreshContext) { // 🟨 UPDATED
        let s = SettingsModel.shared

        GluLog.bootstrap.notice(
            "\(prefix, privacy: .public) | context=\(context.rawValue, privacy: .public) premium=\(s.hasMetabolicPremiumEffective, privacy: .public) trial=\(s.isTrialActive, privacy: .public) hasCGM=\(s.hasCGM, privacy: .public) insulin=\(s.isInsulinTreated, privacy: .public) warnings=\(s.showPermissionWarnings, privacy: .public) debugNoData=\(s.debugSimulateNoHealthData, privacy: .public)"
        )
    }

    @MainActor
    private func applyDebugNoDataModeIfNeededV1() -> Bool {
        guard isDebugSimulatingNoHealthDataV1 else { return false }
        applyDebugSimulatedNoHealthDataV1()
        return true
    }

    @MainActor
    private func applyMetabolicDebugNoDataModeIfNeededV1() -> Bool {
        guard isDebugSimulatingNoHealthDataV1 else { return false }

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

        return true
    }

    // ============================================================
    // MARK: - Public API (Entry Points)
    // ============================================================

    // ------------------------------------------------------------
    // MARK: Global Refresh (All Domains)
    // ------------------------------------------------------------

    @MainActor
    func refreshAll(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshAll started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshAll skipped | preview=true")
            return
        }
        if applyDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshAll skipped | debugNoData=true")
            return
        }

        await runActivityReadProbesV1(context: context)
        await runBodyReadProbesV1(context: context)
        await runNutritionReadProbesV1(context: context)

        activityBadgeSourcesResolvedV1 = false
        bodyBadgeSourcesResolvedV1 = false
        nutritionBadgeSourcesResolvedV1 = false

        if context == .navigation {
            GluLog.bootstrap.debug("refreshAll navigation path entered")

            await refreshTodaysKPIs()
            await refreshChartsAndHistory()

            activityBadgeSourcesResolvedV1 = true
            bodyBadgeSourcesResolvedV1 = true
            nutritionBadgeSourcesResolvedV1 = true

            if hasCGMEnabledV1 {
                await refreshMetabolicChartsAndHistory(context)
            }

            logBootstrapStatusV1(prefix: "refreshAll finished", context: context)
            return
        }

        await refreshTodaysKPIs()
        await refreshChartsAndHistory()

        activityBadgeSourcesResolvedV1 = true
        bodyBadgeSourcesResolvedV1 = true
        nutritionBadgeSourcesResolvedV1 = true

        await refreshSecondaryData()

        if hasCGMEnabledV1 {
            await refreshMetabolicTodaysKPIs(context)
            await refreshMetabolicChartsAndHistory(context)
            await refreshMetabolicSecondary(context)
        }

        logBootstrapStatusV1(prefix: "refreshAll finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: Activity staged loading
    // ------------------------------------------------------------

    @MainActor
    func refreshActivity(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshActivity started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshActivity skipped | preview=true")
            return
        }
        if applyDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshActivity skipped | debugNoData=true")
            return
        }

        activityBadgeSourcesResolvedV1 = false

        await runActivityReadProbesV1(context: context)

        if context == .navigation {
            GluLog.bootstrap.debug("refreshActivity navigation path entered")

            await refreshActivityTodaysKPIs()
            await refreshActivityChartsLightV1()

            activityBadgeSourcesResolvedV1 = true

            Task { @MainActor in
                await self.refreshActivitySecondaryDeferredV1(force: false)
            }

            logBootstrapStatusV1(prefix: "refreshActivity finished", context: context)
            return
        }

        await refreshActivityTodaysKPIs()
        await refreshActivityChartsAndHistory()

        activityBadgeSourcesResolvedV1 = true

        await refreshActivitySecondary()

        logBootstrapStatusV1(prefix: "refreshActivity finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: Body staged loading
    // ------------------------------------------------------------

    @MainActor
    func refreshBody(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshBody started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshBody skipped | preview=true")
            return
        }
        if applyDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshBody skipped | debugNoData=true")
            return
        }

        bodyBadgeSourcesResolvedV1 = false

        await runBodyReadProbesV1(context: context)

        if context == .navigation {
            GluLog.bootstrap.debug("refreshBody navigation path entered")

            await refreshBodyTodaysKPIs()
            await refreshBodyChartsLightV1()

            bodyBadgeSourcesResolvedV1 = true

            Task { @MainActor in
                await self.refreshBodySecondaryDeferredV1(force: false)
            }

            logBootstrapStatusV1(prefix: "refreshBody finished", context: context)
            return
        }

        await refreshBodyTodaysKPIs()
        await refreshBodyChartsAndHistory()

        bodyBadgeSourcesResolvedV1 = true

        await refreshBodySecondary()

        logBootstrapStatusV1(prefix: "refreshBody finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: Nutrition staged loading
    // ------------------------------------------------------------

    @MainActor
    func refreshNutrition(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshNutrition started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshNutrition skipped | preview=true")
            return
        }
        if applyDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshNutrition skipped | debugNoData=true")
            return
        }

        nutritionBadgeSourcesResolvedV1 = false

        await runNutritionReadProbesV1(context: context)

        if context == .navigation {
            GluLog.bootstrap.debug("refreshNutrition navigation path entered")

            await refreshNutritionTodaysKPIs()
            await refreshNutritionChartsLightV1()

            nutritionBadgeSourcesResolvedV1 = true

            Task { @MainActor in
                await self.refreshNutritionMonthlyDeferredV1(force: false)
            }

            Task { @MainActor in
                await self.refreshNutritionSecondaryDeferredV1(force: false)
            }

            logBootstrapStatusV1(prefix: "refreshNutrition finished", context: context)
            return
        }

        await refreshNutritionTodaysKPIs()
        await refreshNutritionChartsLightV1()

        nutritionBadgeSourcesResolvedV1 = true

        await refreshNutritionMonthlyDeferredV1(force: true)
        await refreshNutritionSecondaryDeferredV1(force: true)

        logBootstrapStatusV1(prefix: "refreshNutrition finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: Report (Bootstrap Orchestration)
    // ------------------------------------------------------------

    @MainActor
    func refreshMetabolicReport(_ context: RefreshContext = .pullToRefresh, windowDays: Int) async {
        logBootstrapStatusV1(
            prefix: "refreshMetabolicReport started | windowDays=\(windowDays)",
            context: context
        )

        if isPreview {
            GluLog.bootstrap.debug("refreshMetabolicReport skipped | preview=true")
            return
        }
        if applyMetabolicDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshMetabolicReport skipped | debugNoData=true")
            return
        }
        guard hasCGMEnabledV1 else {
            GluLog.bootstrap.notice("refreshMetabolicReport skipped | cgmEnabled=false")
            return
        }

        await refreshMetabolicTodayRaw3DaysV1(refreshSource: "bootstrap-report-\(context.rawValue)")

        let s = SettingsModel.shared
        let thresholds = RangeThresholds(
            glucoseMin: s.glucoseMin,
            glucoseMax: s.glucoseMax,
            veryLowLimit: s.veryLowLimit,
            veryHighLimit: s.veryHighLimit
        )
        await refreshRangeHybridV1Async(thresholds: thresholds)

        await refreshMetabolicDailyStats90V1(refreshSource: "bootstrap-report-\(context.rawValue)")

        await awaitHybridGlucoseReadyV1()

        logBootstrapStatusV1(prefix: "refreshMetabolicReport finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: Metabolic Domain (Bootstrap Orchestration)
    // ------------------------------------------------------------

    @MainActor
    func refreshMetabolic(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshMetabolic started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshMetabolic skipped | preview=true")
            return
        }
        if applyMetabolicDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshMetabolic skipped | debugNoData=true")
            return
        }
        guard hasCGMEnabledV1 else {
            GluLog.bootstrap.notice("refreshMetabolic skipped | cgmEnabled=false")
            return
        }

        if context == .navigation {
            GluLog.bootstrap.debug("refreshMetabolic navigation path entered")

            await refreshMetabolicTodaysKPIs(context)
            await refreshMetabolicChartsAndHistory(context)

            logBootstrapStatusV1(prefix: "refreshMetabolic finished", context: context)
            return
        }

        await refreshMetabolicTodaysKPIs(context)
        await refreshMetabolicChartsAndHistory(context)
        await refreshMetabolicSecondary(context)

        logBootstrapStatusV1(prefix: "refreshMetabolic finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: Metabolic Overview (Premium Home) staged
    // ------------------------------------------------------------

    @MainActor
    func refreshMetabolicOverview(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshMetabolicOverview started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshMetabolicOverview skipped | preview=true")
            return
        }
        if applyMetabolicDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshMetabolicOverview skipped | debugNoData=true")
            return
        }
        guard hasCGMEnabledV1 else {
            GluLog.bootstrap.notice("refreshMetabolicOverview skipped | cgmEnabled=false")
            return
        }

        await refreshMetabolicTodaysKPIs(context)

        await refreshMetabolicOverviewStageA_V1(context: context)

        Task { @MainActor in
            await self.refreshMetabolicOverviewDeferredStages_V1(context: context, force: (context == .pullToRefresh))
        }

        logBootstrapStatusV1(prefix: "refreshMetabolicOverview finished", context: context)
    }

    // ------------------------------------------------------------
    // MARK: History (Bootstrap Orchestration)
    // ------------------------------------------------------------

    @MainActor
    func refreshHistory(_ context: RefreshContext = .pullToRefresh) async {
        logBootstrapStatusV1(prefix: "refreshHistory started", context: context)

        if isPreview {
            GluLog.bootstrap.debug("refreshHistory skipped | preview=true")
            return
        }
        if applyDebugNoDataModeIfNeededV1() {
            GluLog.bootstrap.notice("refreshHistory skipped | debugNoData=true")
            return
        }
        await refreshHistoryData(context)

        logBootstrapStatusV1(prefix: "refreshHistory finished", context: context)
    }

    // ============================================================
    // MARK: - Private Orchestration (Metabolic-only)
    // ============================================================

    @MainActor
    private func refreshMetabolicTodaysKPIs(_ context: RefreshContext) async {
        guard hasCGMEnabledV1 else { return }
        fetchCarbsTodayV1()
    }

    @MainActor
    private func refreshMetabolicChartsAndHistory(_ context: RefreshContext) async {
        guard hasCGMEnabledV1 else { return }

        let key = ObjectIdentifier(self)
        guard MetabolicDeferredLoadGateV1.beginStageA(for: key) else { return }
        defer { MetabolicDeferredLoadGateV1.finishStageA(for: key) }

        await refreshMetabolicTodayRaw3DaysV1(refreshSource: "bootstrap-\(context.rawValue)")

        let s = SettingsModel.shared
        let thresholds = RangeThresholds(
            glucoseMin: s.glucoseMin,
            glucoseMax: s.glucoseMax,
            veryLowLimit: s.veryLowLimit,
            veryHighLimit: s.veryHighLimit
        )

        if context == .pullToRefresh {

            if MetabolicDeferredLoadGateV1.beginHybrid(for: key) {
                await self.refreshRangeHybridV1Async(thresholds: thresholds)
                MetabolicDeferredLoadGateV1.finishHybrid(for: key)
            }

        } else if MetabolicDeferredLoadGateV1.shouldRunHybrid(for: key) {

            Task { @MainActor in
                guard MetabolicDeferredLoadGateV1.beginHybrid(for: key) else { return }
                await self.refreshRangeHybridV1Async(thresholds: thresholds)
                MetabolicDeferredLoadGateV1.finishHybrid(for: key)
            }
        }

        if context == .navigation || context == .pullToRefresh {
            await refreshMetabolicDailyStats90V1FromContext(context)
        }
    }

    @MainActor
    private func refreshMetabolicSecondary(_ context: RefreshContext) async {
        guard hasCGMEnabledV1 else { return }
        fetchCarbsDaily365V1()
    }

    @MainActor
    private func refreshMetabolicDailyStats90V1FromContext(_ context: RefreshContext) async {
        await refreshMetabolicDailyStats90V1(refreshSource: "bootstrap-\(context.rawValue)")
    }

    // ------------------------------------------------------------
    // MARK: Metabolic Overview — Stage A/B/C
    // ------------------------------------------------------------

    @MainActor
    private func refreshMetabolicOverviewStageA_V1(context: RefreshContext) async {
        let key = ObjectIdentifier(self)
        guard MetabolicDeferredLoadGateV1.beginStageA(for: key) else { return }
        defer { MetabolicDeferredLoadGateV1.finishStageA(for: key) }

        await refreshMetabolicRaw3DaysMainChartFastV1(refreshSource: "bootstrap-overview-\(context.rawValue)")

        let force = (context == .pullToRefresh)

        fetchActiveEnergyTodayV1()

        if force || last90DaysActiveEnergy.isEmpty {
            fetchLast90DaysActiveEnergyV1()
        }
        if force || monthlyActiveEnergy.isEmpty {
            fetchMonthlyActiveEnergyV1()
        }

        _ = await probeActiveEnergyReadAuthIssueV1Async()
    }

    @MainActor
    private func refreshMetabolicOverviewDeferredStages_V1(context: RefreshContext, force: Bool) async {
        let key = ObjectIdentifier(self)

        if force || MetabolicDeferredLoadGateV1.shouldRunMean90Light(for: key) {
            guard MetabolicDeferredLoadGateV1.beginMean90Light(for: key) else { return }
            await fetchGlucoseMean90dMgdlLightV1Async()
            MetabolicDeferredLoadGateV1.finishMean90Light(for: key)
        }

        let s = SettingsModel.shared
        let thresholds = RangeThresholds(
            glucoseMin: s.glucoseMin,
            glucoseMax: s.glucoseMax,
            veryLowLimit: s.veryLowLimit,
            veryHighLimit: s.veryHighLimit
        )

        if force || MetabolicDeferredLoadGateV1.shouldRunHybrid(for: key) {
            guard MetabolicDeferredLoadGateV1.beginHybrid(for: key) else { return }
            await refreshRangeHybridV1Async(thresholds: thresholds)
            MetabolicDeferredLoadGateV1.finishHybrid(for: key)
        }

        if hasInsulinEnabledV1 {
            if force || MetabolicDeferredLoadGateV1.shouldRunTherapyRaw3Days(for: key) {
                guard MetabolicDeferredLoadGateV1.beginTherapyRaw3Days(for: key) else { return }
                await refreshMetabolicRaw3DaysTherapyOnlyV1(refreshSource: "bootstrap-overview-\(context.rawValue)")
                MetabolicDeferredLoadGateV1.finishTherapyRaw3Days(for: key)
            }
        }

        if force || MetabolicDeferredLoadGateV1.shouldRunDaily7(for: key) {
            guard MetabolicDeferredLoadGateV1.beginDaily7(for: key) else { return }
            await refreshMetabolicOverviewDaily7FullDaysV1(refreshSource: "bootstrap-overview-\(context.rawValue)")
            MetabolicDeferredLoadGateV1.finishDaily7(for: key)
        }

        if hasInsulinEnabledV1 {
            if force || MetabolicDeferredLoadGateV1.shouldRunTherapy90Light(for: key) {
                guard MetabolicDeferredLoadGateV1.beginTherapy90Light(for: key) else { return }
                await refreshMetabolicTherapyDaily90LightV1(refreshSource: "bootstrap-overview-\(context.rawValue)")
                MetabolicDeferredLoadGateV1.finishTherapy90Light(for: key)
            }
        }
    }

    // ============================================================
    // MARK: - Read-Probes (Central)
    // ============================================================

    @MainActor
    private func runActivityReadProbesV1(context: RefreshContext) async {
        _ = await probeStepsReadAuthIssueV1Async()
        _ = await probeWorkoutMinutesReadAuthIssueV1Async()
        _ = await probeActiveEnergyReadAuthIssueV1Async()
    }

    @MainActor
    private func runBodyReadProbesV1(context: RefreshContext) async {
        _ = await probeWeightReadAuthIssueV1Async()
        _ = await probeSleepReadAuthIssueV1Async()
        _ = await probeBMIReadAuthIssueV1Async()
        _ = await probeBodyFatReadAuthIssueV1Async()
        _ = await probeRestingHeartRateReadAuthIssueV1Async()
    }

    @MainActor
    private func runNutritionReadProbesV1(context: RefreshContext) async {
        _ = await probeNutritionEnergyReadAuthIssueV1Async()
        _ = await probeCarbsReadAuthIssueV1Async()
        _ = await probeSugarReadAuthIssueV1Async()
        _ = await probeProteinReadAuthIssueV1Async()
        _ = await probeFatReadAuthIssueV1Async()
    }

    // ============================================================
    // MARK: - Private Orchestration (History)
    // ============================================================

    @MainActor
    private func refreshHistoryData(_ context: RefreshContext) async {

        let days = 10

        fetchCarbEventsForHistoryWindowV1(days: days)
        await fetchRecentWorkoutsForHistoryWindowV1(days: days)
        fetchRecentWeightSamplesForHistoryWindowV1(days: days)

        if hasCGMEnabledV1 {
            fetchCGMSamplesForHistoryWindowV1(days: days)
        }

        if hasInsulinEnabledV1 {
            fetchBolusEventsForHistoryWindowV1(days: days)
            fetchBasalEventsForHistoryWindowV1(days: days)
        }
    }

    // ============================================================
    // MARK: - Private Orchestration (All Domains)
    // ============================================================

    @MainActor
    private func refreshTodaysKPIs() async {
        fetchStepsTodayV1()

        fetchActiveEnergyTodayV1()
        fetchRestingEnergyTodayV1()
        await refreshExerciseMinutesTodayFromExerciseTimeV1Async()

        fetchSleepTodayV1()
        await fetchMovementSplitFastSliceAsync(last: 3)

        fetchWeightTodayV1()
        fetchRestingHeartRateTodayV1()
        fetchBodyFatTodayV1()
        fetchBMITodayV1()

        fetchNutritionEnergyTodayV1()
        fetchCarbsTodayV1()
        fetchSugarTodayV1()
        fetchProteinTodayV1()
        fetchFatTodayV1()
    }

    @MainActor
    private func refreshChartsAndHistory() async {
        fetchStepsDaily365V1()

        fetchLast90DaysStepsV1()
        fetchMonthlyStepsV1()

        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()

        fetchLast90DaysRestingEnergyV1()
        fetchMonthlyRestingEnergyV1()

        await refreshExerciseMinutesHistoryFromExerciseTimeV1Async()

        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()
        
        fetchLast90DaysWeightV1()
        fetchMonthlyWeightV1()

        fetchWeightDaily365RawV1()

        fetchLast90DaysRestingHeartRateV1()
        fetchMonthlyRestingHeartRateV1()

        fetchLast90DaysBodyFatV1()
        fetchMonthlyBodyFatV1()

        fetchLast90DaysBMIV1()
        fetchMonthlyBMIV1()

        fetchBMIDaily365V1()
        fetchBodyFatDaily365V1()

        fetchLast90DaysNutritionEnergyV1()
        fetchMonthlyNutritionEnergyV1()

        fetchLast90DaysCarbsV1()
        fetchLast90DaysSugarV1()
        fetchMonthlyCarbsV1()
        fetchMonthlySugarV1()

        fetchLast90DaysProteinV1()
        fetchMonthlyProteinV1()

        fetchLast90DaysFatV1()
        fetchMonthlyFatV1()
    }

    @MainActor
    private func refreshSecondaryData() async {
        fetchRestingEnergyDaily365V1()

        fetchNutritionEnergyDaily365V1()
        fetchCarbsDaily365V1()
        fetchSugarDaily365V1()
        fetchProteinDaily365V1()
        fetchFatDaily365V1()

        fetchSleepDaily365V1()
    }

    // ============================================================
    // MARK: - Private Orchestration (Activity-only)
    // ============================================================

    @MainActor
    private func refreshActivityTodaysKPIs() async {
        fetchStepsTodayV1()
        fetchActiveEnergyTodayV1()
        fetchRestingEnergyTodayV1()
        await refreshExerciseMinutesTodayFromExerciseTimeV1Async()
        fetchSleepTodayV1()

        fetchMoveTimeTodayV1()
        fetchWorkoutMinutesTodayV1()

        await fetchMovementSplitFastSliceAsync(last: 3)
    }

    @MainActor
    private func refreshActivityChartsLightV1() async {
        fetchLast90DaysStepsV1()
        fetchMonthlyStepsV1()

        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()

        fetchLast90DaysWorkoutMinutesV1()
        fetchMonthlyWorkoutMinutesV1()

        fetchLast90DaysMoveTimeV1()
        fetchMonthlyMoveTimeV1()

        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()

        await fetchMovementSplitFastSliceAsync(last: 90)
    }

    @MainActor
    private func refreshActivitySecondaryDeferredV1(force: Bool) async {

        let key = ObjectIdentifier(self)

        let hasAny365 =
            !stepsDaily365.isEmpty ||
            !activeEnergyDaily365.isEmpty ||
            !moveTimeDaily365.isEmpty ||
            !workoutMinutesDaily365.isEmpty ||
            !sleepDaily365.isEmpty ||
            !movementSplitDaily365.isEmpty ||
            !activeTimeDaily365.isEmpty

        if !force {
            guard ActivityDeferredLoadGateV1.shouldRunDaily365(for: key, hasAny365: hasAny365) else { return }
            guard ActivityDeferredLoadGateV1.beginDaily365(for: key) else { return }
        } else {
            _ = ActivityDeferredLoadGateV1.beginDaily365(for: key)
        }

        fetchStepsDaily365V1()
        fetchActiveEnergyDaily365V1()
        fetchMoveTimeDaily365V1()
        fetchWorkoutMinutesDaily365V1()
        fetchSleepDaily365V1()
        fetchRestingEnergyDaily365V1()

        fetchExerciseTimeDaily365V1()
        fetchMovementSplitDaily365V1(last: 365) { }

        ActivityDeferredLoadGateV1.finishDaily365(for: key)
    }

    @MainActor
    private func refreshActivityChartsAndHistory() async {
        fetchStepsDaily365V1()

        fetchLast90DaysStepsV1()
        fetchMonthlyStepsV1()

        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()
        fetchActiveEnergyDaily365V1()

        fetchLast90DaysRestingEnergyV1()
        fetchMonthlyRestingEnergyV1()

        await refreshExerciseMinutesHistoryFromExerciseTimeV1Async()

        fetchLast90DaysWorkoutMinutesV1()
        fetchMonthlyWorkoutMinutesV1()
        fetchWorkoutMinutesDaily365V1()

        fetchLast90DaysMoveTimeV1()
        fetchMonthlyMoveTimeV1()
        fetchMoveTimeDaily365V1()

        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()
        fetchSleepDaily365V1()

        await fetchMovementSplitFastSliceAsync(last: 90)
    }

    @MainActor
    private func refreshActivitySecondary() async {
        fetchExerciseTimeDaily365V1()
        fetchMovementSplitDaily365V1(last: 365) { }
        fetchRestingEnergyDaily365V1()
    }

    // ============================================================
    // MARK: - Private Orchestration (Body-only)
    // ============================================================

    @MainActor
    private func refreshBodyTodaysKPIs() async {
        fetchSleepTodayV1()
        fetchWeightTodayV1()
        fetchRestingHeartRateTodayV1()
        fetchBodyFatTodayV1()
        fetchBMITodayV1()
    }

    @MainActor
    private func refreshBodyChartsLightV1() async {
        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()

        fetchLast90DaysWeightV1()
        fetchMonthlyWeightV1()

        fetchLast90DaysRestingHeartRateV1()
        fetchMonthlyRestingHeartRateV1()

        fetchLast90DaysBodyFatV1()
        fetchMonthlyBodyFatV1()

        fetchLast90DaysBMIV1()
        fetchMonthlyBMIV1()
    }

    @MainActor
    private func refreshBodySecondaryDeferredV1(force: Bool) async {

        let key = ObjectIdentifier(self)

        let hasAny365 =
            !sleepDaily365.isEmpty ||
            !weightDaily365Raw.isEmpty ||
            !bmiDaily365.isEmpty ||
            !bodyFatDaily365.isEmpty ||
            !restingHeartRateDaily365.isEmpty

        if !force {
            guard BodyDeferredLoadGateV1.shouldRunDaily365(for: key, hasAny365: hasAny365) else { return }
            guard BodyDeferredLoadGateV1.beginDaily365(for: key) else { return }
        } else {
            _ = BodyDeferredLoadGateV1.beginDaily365(for: key)
        }

        fetchSleepDaily365V1()
        fetchWeightDaily365RawV1()
        fetchBMIDaily365V1()
        fetchBodyFatDaily365V1()
        fetchRestingHeartRateDaily365V1()
        fetchRestingEnergyDaily365V1()

        BodyDeferredLoadGateV1.finishDaily365(for: key)
    }

    @MainActor
    private func refreshBodyChartsAndHistory() async {
        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()
        fetchSleepDaily365V1()

        fetchLast90DaysWeightV1()
        fetchMonthlyWeightV1()

        fetchLast90DaysRestingHeartRateV1()
        fetchMonthlyRestingHeartRateV1()

        fetchLast90DaysBodyFatV1()
        fetchMonthlyBodyFatV1()

        fetchLast90DaysBMIV1()
        fetchMonthlyBMIV1()

        fetchWeightDaily365RawV1()
        fetchBMIDaily365V1()
        fetchBodyFatDaily365V1()
    }

    @MainActor
    private func refreshBodySecondary() async {
        fetchRestingHeartRateDaily365V1()
        fetchRestingEnergyDaily365V1()
    }

    // ============================================================
    // MARK: - Private Orchestration (Nutrition-only)
    // ============================================================

    @MainActor
    private func refreshNutritionTodaysKPIs() async {
        fetchNutritionEnergyTodayV1()
        fetchCarbsTodayV1()
        fetchSugarTodayV1()
        fetchProteinTodayV1()
        fetchFatTodayV1()
        fetchRestingEnergyTodayV1()
        fetchActiveEnergyTodayV1()
    }

    @MainActor
    private func refreshNutritionChartsLightV1() async {
        fetchLast90DaysNutritionEnergyV1()
        fetchLast90DaysCarbsV1()
        fetchLast90DaysSugarV1()
        fetchLast90DaysProteinV1()
        fetchLast90DaysFatV1()
        fetchLast90DaysRestingEnergyV1()
        fetchLast90DaysActiveEnergyV1()
    }

    @MainActor
    private func refreshNutritionMonthlyDeferredV1(force: Bool) async {

        let key = ObjectIdentifier(self)

        if !force {
            guard NutritionDeferredLoadGateV1.shouldRunMonthly(for: key) else { return }
            guard NutritionDeferredLoadGateV1.beginMonthly(for: key) else { return }
        } else {
            _ = NutritionDeferredLoadGateV1.beginMonthly(for: key)
        }

        fetchMonthlyNutritionEnergyV1()
        fetchMonthlyCarbsV1()
        fetchMonthlySugarV1()
        fetchMonthlyProteinV1()
        fetchMonthlyFatV1()
        fetchMonthlyRestingEnergyV1()
        fetchMonthlyActiveEnergyV1()

        NutritionDeferredLoadGateV1.finishMonthly(for: key)
    }

    @MainActor
    private func refreshNutritionSecondaryDeferredV1(force: Bool) async {

        let key = ObjectIdentifier(self)

        let hasAny365 =
            !nutritionEnergyDaily365.isEmpty ||
            !carbsDaily365.isEmpty ||
            !sugarDaily365.isEmpty ||
            !proteinDaily365.isEmpty ||
            !fatDaily365.isEmpty

        if !force {
            guard NutritionDeferredLoadGateV1.shouldRunDaily365(for: key, hasAny365: hasAny365) else { return }
            guard NutritionDeferredLoadGateV1.beginDaily365(for: key) else { return }
        } else {
            _ = NutritionDeferredLoadGateV1.beginDaily365(for: key)
        }

        fetchNutritionEnergyDaily365V1()
        fetchCarbsDaily365V1()
        fetchSugarDaily365V1()
        fetchProteinDaily365V1()
        fetchFatDaily365V1()
        fetchRestingEnergyDaily365V1()
        fetchActiveEnergyDaily365V1()

        await self.refreshCarbsDayparts90V1Async(force: force)

        NutritionDeferredLoadGateV1.finishDaily365(for: key)
    }
}

// ============================================================
// MARK: - Async Helpers (Wrapper only)
// ============================================================

private extension HealthStore {

    func refreshExerciseMinutesTodayFromExerciseTimeV1Async() async {
        await fetchExerciseTimeDaily365V1Async()

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let value = self.activeTimeDaily365
            .first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
            .minutes ?? 0

        await MainActor.run {
            self.todayExerciseMinutes = max(0, value)
        }
    }

    func refreshExerciseMinutesHistoryFromExerciseTimeV1Async() async {
        await fetchExerciseTimeDaily365V1Async()

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let start90 = calendar.date(byAdding: .day, value: -89, to: todayStart) ?? todayStart
        let last90 = self.activeTimeDaily365
            .filter { $0.date >= start90 && $0.date <= todayStart }
            .sorted { $0.date < $1.date }

        let monthsBack = 4
        let monthAnchor = calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
        let startMonth = calendar.date(byAdding: .month, value: -monthsBack, to: monthAnchor) ?? monthAnchor

        var bucket: [String: Int] = [:]
        for e in self.activeTimeDaily365 where e.date >= startMonth && e.date <= todayStart {
            let key = e.date.formatted(.dateTime.month(.abbreviated))
            bucket[key, default: 0] += max(0, e.minutes)
        }

        var monthly: [MonthlyMetricEntry] = []
        monthly.reserveCapacity(monthsBack + 1)

        for i in 0...monthsBack {
            guard let d = calendar.date(byAdding: .month, value: i, to: startMonth) else { continue }
            let key = d.formatted(.dateTime.month(.abbreviated))
            monthly.append(MonthlyMetricEntry(monthShort: key, value: bucket[key] ?? 0))
        }

        await MainActor.run {
            self.last90DaysExerciseMinutes = last90
            self.monthlyExerciseMinutes = monthly
        }
    }

    func fetchExerciseTimeDaily365V1Async() async {
        await self.loadExerciseTimeDaily365V1Async()
    }

    func fetchMovementSplitFastSliceAsync(last days: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchMovementSplitDaily365V1(last: days) { continuation.resume(returning: ()) }
        }
    }
}

// ============================================================
// MARK: - Nutrition Deferred Load Gate (file-local)
// ============================================================

private enum NutritionDeferredLoadGateV1 {

    private static let monthlyTTL: TimeInterval = 60 * 60 * 6
    private static let daily365TTL: TimeInterval = 60 * 60 * 12

    private static var lastMonthly: [ObjectIdentifier: Date] = [:]
    private static var lastDaily365: [ObjectIdentifier: Date] = [:]

    private static var monthlyInFlight: Set<ObjectIdentifier> = []
    private static var daily365InFlight: Set<ObjectIdentifier> = []

    static func shouldRunMonthly(for key: ObjectIdentifier) -> Bool {
        let now = Date()
        guard let last = lastMonthly[key] else { return true }
        return now.timeIntervalSince(last) > monthlyTTL
    }

    static func shouldRunDaily365(for key: ObjectIdentifier, hasAny365: Bool) -> Bool {
        let now = Date()
        if !hasAny365 { return true }
        guard let last = lastDaily365[key] else { return true }
        return now.timeIntervalSince(last) > daily365TTL
    }

    static func beginMonthly(for key: ObjectIdentifier) -> Bool {
        if monthlyInFlight.contains(key) { return false }
        monthlyInFlight.insert(key)
        return true
    }

    static func finishMonthly(for key: ObjectIdentifier) {
        monthlyInFlight.remove(key)
        lastMonthly[key] = Date()
    }

    static func beginDaily365(for key: ObjectIdentifier) -> Bool {
        if daily365InFlight.contains(key) { return false }
        daily365InFlight.insert(key)
        return true
    }

    static func finishDaily365(for key: ObjectIdentifier) {
        daily365InFlight.remove(key)
        lastDaily365[key] = Date()
    }
}

// ============================================================
// MARK: - Activity Deferred Load Gate (file-local)
// ============================================================

private enum ActivityDeferredLoadGateV1 {

    private static let daily365TTL: TimeInterval = 60 * 60 * 12

    private static var lastDaily365: [ObjectIdentifier: Date] = [:]
    private static var daily365InFlight: Set<ObjectIdentifier> = []

    static func shouldRunDaily365(for key: ObjectIdentifier, hasAny365: Bool) -> Bool {
        let now = Date()
        if !hasAny365 { return true }
        guard let last = lastDaily365[key] else { return true }
        return now.timeIntervalSince(last) > daily365TTL
    }

    static func beginDaily365(for key: ObjectIdentifier) -> Bool {
        if daily365InFlight.contains(key) { return false }
        daily365InFlight.insert(key)
        return true
    }

    static func finishDaily365(for key: ObjectIdentifier) {
        daily365InFlight.remove(key)
        lastDaily365[key] = Date()
    }
}

// ============================================================
// MARK: - Body Deferred Load Gate (file-local)
// ============================================================

private enum BodyDeferredLoadGateV1 {

    private static let daily365TTL: TimeInterval = 60 * 60 * 12

    private static var lastDaily365: [ObjectIdentifier: Date] = [:]
    private static var daily365InFlight: Set<ObjectIdentifier> = []

    static func shouldRunDaily365(for key: ObjectIdentifier, hasAny365: Bool) -> Bool {
        let now = Date()
        if !hasAny365 { return true }
        guard let last = lastDaily365[key] else { return true }
        return now.timeIntervalSince(last) > daily365TTL
    }

    static func beginDaily365(for key: ObjectIdentifier) -> Bool {
        if daily365InFlight.contains(key) { return false }
        daily365InFlight.insert(key)
        return true
    }

    static func finishDaily365(for key: ObjectIdentifier) {
        daily365InFlight.remove(key)
        lastDaily365[key] = Date()
    }
}

// ============================================================
// MARK: - Metabolic Deferred Load Gate (file-local)
// ============================================================

private enum MetabolicDeferredLoadGateV1 {

    private static let hybridTTL: TimeInterval = 60 * 60 * 6
    private static let mean90LightTTL: TimeInterval = 60 * 60 * 6
    private static let daily7TTL: TimeInterval = 60 * 60 * 2
    private static let therapy90LightTTL: TimeInterval = 60 * 60 * 12
    private static let therapyRaw3DaysTTL: TimeInterval = 60 * 30

    private static var stageAInFlight: Set<ObjectIdentifier> = []

    private static var lastHybrid: [ObjectIdentifier: Date] = [:]
    private static var lastMean90Light: [ObjectIdentifier: Date] = [:]
    private static var lastDaily7: [ObjectIdentifier: Date] = [:]
    private static var lastTherapy90Light: [ObjectIdentifier: Date] = [:]
    private static var lastTherapyRaw3Days: [ObjectIdentifier: Date] = [:]

    private static var hybridInFlight: Set<ObjectIdentifier> = []
    private static var mean90LightInFlight: Set<ObjectIdentifier> = []
    private static var daily7InFlight: Set<ObjectIdentifier> = []
    private static var therapy90LightInFlight: Set<ObjectIdentifier> = []
    private static var therapyRaw3DaysInFlight: Set<ObjectIdentifier> = []

    static func beginStageA(for key: ObjectIdentifier) -> Bool {
        if stageAInFlight.contains(key) { return false }
        stageAInFlight.insert(key)
        return true
    }

    static func finishStageA(for key: ObjectIdentifier) {
        stageAInFlight.remove(key)
    }

    static func shouldRunHybrid(for key: ObjectIdentifier) -> Bool {
        let now = Date()
        guard let last = lastHybrid[key] else { return true }
        return now.timeIntervalSince(last) > hybridTTL
    }

    static func beginHybrid(for key: ObjectIdentifier) -> Bool {
        if hybridInFlight.contains(key) { return false }
        hybridInFlight.insert(key)
        return true
    }

    static func finishHybrid(for key: ObjectIdentifier) {
        hybridInFlight.remove(key)
        lastHybrid[key] = Date()
    }

    static func shouldRunMean90Light(for key: ObjectIdentifier) -> Bool {
        let now = Date()
        guard let last = lastMean90Light[key] else { return true }
        return now.timeIntervalSince(last) > mean90LightTTL
    }

    static func beginMean90Light(for key: ObjectIdentifier) -> Bool {
        if mean90LightInFlight.contains(key) { return false }
        mean90LightInFlight.insert(key)
        return true
    }

    static func finishMean90Light(for key: ObjectIdentifier) {
        mean90LightInFlight.remove(key)
        lastMean90Light[key] = Date()
    }

    static func shouldRunDaily7(for key: ObjectIdentifier) -> Bool {
        let now = Date()
        guard let last = lastDaily7[key] else { return true }
        return now.timeIntervalSince(last) > daily7TTL
    }

    static func beginDaily7(for key: ObjectIdentifier) -> Bool {
        if daily7InFlight.contains(key) { return false }
        daily7InFlight.insert(key)
        return true
    }

    static func finishDaily7(for key: ObjectIdentifier) {
        daily7InFlight.remove(key)
        lastDaily7[key] = Date()
    }

    static func shouldRunTherapy90Light(for key: ObjectIdentifier) -> Bool {
        let now = Date()
        guard let last = lastTherapy90Light[key] else { return true }
        return now.timeIntervalSince(last) > therapy90LightTTL
    }

    static func beginTherapy90Light(for key: ObjectIdentifier) -> Bool {
        if therapy90LightInFlight.contains(key) { return false }
        therapy90LightInFlight.insert(key)
        return true
    }

    static func finishTherapy90Light(for key: ObjectIdentifier) {
        therapy90LightInFlight.remove(key)
        lastTherapy90Light[key] = Date()
    }

    static func shouldRunTherapyRaw3Days(for key: ObjectIdentifier) -> Bool {
        let now = Date()
        guard let last = lastTherapyRaw3Days[key] else { return true }
        return now.timeIntervalSince(last) > therapyRaw3DaysTTL
    }

    static func beginTherapyRaw3Days(for key: ObjectIdentifier) -> Bool {
        if therapyRaw3DaysInFlight.contains(key) { return false }
        therapyRaw3DaysInFlight.insert(key)
        return true
    }

    static func finishTherapyRaw3Days(for key: ObjectIdentifier) {
        therapyRaw3DaysInFlight.remove(key)
        lastTherapyRaw3Days[key] = Date()
    }
}
