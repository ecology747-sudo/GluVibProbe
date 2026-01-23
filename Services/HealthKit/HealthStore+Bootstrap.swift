//
//  HealthStore+Bootstrap.swift
//  GluVibProbe
//
//  Zentrale Bootstrap/Refresh-Orchestrierung
//
//  Zweck dieser Datei:
//  - Orchestrierung (WAS wird wann geladen)
//  - Keine Metric-Fetch-Definitionen (die Fetch-Funktionen existieren in anderen Dateien)
//  - Keine fachliche Berechnungslogik (nur Reihenfolge / Kontextsteuerung)
//
//  Kontext-Hinweise:
//  - Activity / Body / Nutrition: überwiegend tagesbasierte Daten (leichter)
//  - Metabolic: Kombination aus tages- und minutenbasierten Daten (teurer)
//  - Metabolic Overview: bewusst „lightweight“ (keine DailyStats90)
//

import Foundation

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
    // MARK: - Public API (Entry Points)
    // ============================================================

    @MainActor
    func refreshAll(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        if context == .navigation {
            await refreshTodaysKPIs()
            await refreshChartsAndHistory()
            await refreshMetabolicChartsAndHistory(context)
            return
        }

        await refreshTodaysKPIs()
        await refreshChartsAndHistory()
        await refreshSecondaryData()

        await refreshMetabolicTodaysKPIs(context)
        await refreshMetabolicChartsAndHistory(context)
        await refreshMetabolicSecondary(context)
    }

    @MainActor
    func refreshActivity(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        if context == .navigation {
            await refreshActivityTodaysKPIs()
            await refreshActivityChartsAndHistory()
            return
        }

        await refreshActivityTodaysKPIs()
        await refreshActivityChartsAndHistory()
        await refreshActivitySecondary()
    }

    @MainActor
    func refreshBody(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        if context == .navigation {
            await refreshBodyTodaysKPIs()
            await refreshBodyChartsAndHistory()
            return
        }

        await refreshBodyTodaysKPIs()
        await refreshBodyChartsAndHistory()
        await refreshBodySecondary()
    }

    @MainActor
    func refreshNutrition(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        if context == .navigation {
            await refreshNutritionTodaysKPIs()
            await refreshNutritionChartsAndHistory()
            return
        }

        await refreshNutritionTodaysKPIs()
        await refreshNutritionChartsAndHistory()
        await refreshNutritionSecondary()
    }
    
    // ============================================================
    // MARK: - Report (Bootstrap Orchestration)
    // ============================================================

   

        @MainActor
        func refreshMetabolicReport(_ context: RefreshContext = .pullToRefresh, windowDays: Int) async { // UPDATED
            if isPreview { return }

            // 1) RAW3DAYS (Today/Yesterday/DayBefore) – needed for Today RAW KPIs + cache
            await refreshMetabolicTodayRaw3DaysV1(refreshSource: "bootstrap-report-\(context.rawValue)")

            // 2) RANGE Hybrid (needs RAW3DAYS: cgmSamples3Days)
            let s = SettingsModel.shared
            let thresholds = RangeThresholds(
                glucoseMin: s.glucoseMin,
                glucoseMax: s.glucoseMax,
                veryLowLimit: s.veryLowLimit,
                veryHighLimit: s.veryHighLimit
            )
            await refreshRangeHybridV1Async(thresholds: thresholds)

            // 3) DailyStats90 (heavy) – deterministic basis for period KPIs / GMI hybrid
            await refreshMetabolicDailyStats90V1(refreshSource: "bootstrap-report-\(context.rawValue)")

            // 4) Deterministic gate (optional but recommended for Report consistency)
            await awaitHybridGlucoseReadyV1()
        }
    

    // ============================================================
    // MARK: - Metabolic Domain (Bootstrap Orchestration)
    // ============================================================

    // ============================================================
    // MARK: - Public API (Metabolic-only)
    // ============================================================
    //
    // refreshMetabolic:
    // - für Detailmetriken innerhalb der Metabolic Domain
    // - darf bei .navigation auch schwere Serien laden (DailyStats90)
    //
    // refreshMetabolicOverview:
    // - für Premium Metabolic Overview
    // - MUSS lightweight bleiben (keine DailyStats90)
    //

    @MainActor
    func refreshMetabolic(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        if context == .navigation {
            await refreshMetabolicTodaysKPIs(context)
            await refreshMetabolicChartsAndHistory(context)
            return
        }

        await refreshMetabolicTodaysKPIs(context)
        await refreshMetabolicChartsAndHistory(context)
        await refreshMetabolicSecondary(context)
    }

    @MainActor
    func refreshMetabolicOverview(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        await refreshMetabolicTodaysKPIs(context)
        await refreshMetabolicOverviewChartsAndHistory(context)
    }

    // ============================================================
    // MARK: - History (Bootstrap Orchestration)
    // ============================================================

    @MainActor
    func refreshHistory(_ context: RefreshContext = .pullToRefresh) async { // !!! NEW
        if isPreview { return }
        await refreshHistoryData(context)
    }

    // ============================================================
    // MARK: - Private Orchestration (Metabolic-only)
    // ============================================================

    @MainActor
    private func refreshMetabolicTodaysKPIs(_ context: RefreshContext) async {
        fetchCarbsTodayV1()
    }

    @MainActor
    private func refreshMetabolicChartsAndHistory(_ context: RefreshContext) async {

        // RAW3DAYS (CGM RAW + MainChart Cache + Quick KPIs intern)
        await refreshMetabolicTodayRaw3DaysV1(refreshSource: "bootstrap-\(context.rawValue)")

        // Range Hybrid (depends on RAW3DAYS: cgmSamples3Days)
        let s = SettingsModel.shared
        let thresholds = RangeThresholds(
            glucoseMin: s.glucoseMin,
            glucoseMax: s.glucoseMax,
            veryLowLimit: s.veryLowLimit,
            veryHighLimit: s.veryHighLimit
        )
        await refreshRangeHybridV1Async(thresholds: thresholds)

        // DailyStats90 (Detail-only)
        if context == .navigation {
            await refreshMetabolicDailyStats90V1FromContext(context)
        }
    }

    @MainActor
    private func refreshMetabolicSecondary(_ context: RefreshContext) async {
        fetchCarbsDaily365V1()
    }

    @MainActor
    private func refreshMetabolicDailyStats90V1FromContext(_ context: RefreshContext) async {
        await refreshMetabolicDailyStats90V1(refreshSource: "bootstrap-\(context.rawValue)")
    }

    // ------------------------------------------------------------
    // MARK: Metabolic Overview (Premium Overview)
    // ------------------------------------------------------------

    @MainActor
    private func refreshMetabolicOverviewChartsAndHistory(_ context: RefreshContext) async {

        // RAW3DAYS (needed for MainChart + last24h summary)
        await refreshMetabolicTodayRaw3DaysV1(refreshSource: "bootstrap-overview-\(context.rawValue)")

        // Overview GMI(90) Light (must not depend on DailyStats90)
        await fetchGlucoseMean90dMgdlLightV1Async()

        // Range Hybrid (needs RAW3DAYS: cgmSamples3Days)
        let s = SettingsModel.shared
        let thresholds = RangeThresholds(
            glucoseMin: s.glucoseMin,
            glucoseMax: s.glucoseMax,
            veryLowLimit: s.veryLowLimit,
            veryHighLimit: s.veryHighLimit
        )
        await refreshRangeHybridV1Async(thresholds: thresholds)

        // Overview-only daily series (7 full days: yesterday + 6 before)
        await refreshMetabolicOverviewDaily7FullDaysV1(refreshSource: "bootstrap-overview-\(context.rawValue)")

        // Therapy preloads (Overview cards need these immediately)
        fetchLast90DaysActiveEnergyV1()
        await refreshMetabolicTherapyDaily90LightV1(refreshSource: "bootstrap-overview-\(context.rawValue)")
    }

    // ============================================================
    // MARK: - Private Orchestration (History)
    // ============================================================

    @MainActor
    private func refreshHistoryData(_ context: RefreshContext) async {

        let force = (context == .pullToRefresh)

        for offset in stride(from: 0, through: -9, by: -1) {
            await ensureMainChartCachedV1(dayOffset: offset, forceRefetch: force)
        }

        // ✅ FIX: no async wrapper here (prevents redeclaration issues)
        // HistoryViewModel listens to $recentWorkouts and rebuilds when data arrives.
        await fetchRecentWorkoutsForHistoryWindowV1(days: 10)

        // ✅ Weight Samples for History (10 days)
        fetchRecentWeightSamplesForHistoryWindowV1(days: 10)
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
        fetchProteinTodayV1()
        fetchFatTodayV1()
    }

    @MainActor
    private func refreshChartsAndHistory() async {
        fetchStepsDaily365V1()

        fetchLast90DaysStepsV1()     // UPDATED: required for Steps 90d chart
        fetchMonthlyStepsV1()        // UPDATED: required for Steps monthly chart

        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()

        fetchLast90DaysRestingEnergyV1()
        fetchMonthlyRestingEnergyV1()

        await refreshExerciseMinutesHistoryFromExerciseTimeV1Async()

        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()
        fetchSleepDaily365V1()

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
        fetchMonthlyCarbsV1()

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
    private func refreshActivityChartsAndHistory() async {
        fetchStepsDaily365V1()

        fetchLast90DaysStepsV1()     // UPDATED: required for Steps 90d chart
        fetchMonthlyStepsV1()        // UPDATED: required for Steps monthly chart

        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()

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
        fetchStepsDaily365V1()
        fetchActiveEnergyDaily365V1()
        fetchExerciseTimeDaily365V1()
        fetchMovementSplitDaily365V1(last: 365) { }
        fetchMoveTimeDaily365V1()
        fetchSleepDaily365V1()
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
        fetchWeightDaily365RawV1()
        fetchBMIDaily365V1()
        fetchBodyFatDaily365V1()
        fetchRestingHeartRateDaily365V1()
        fetchSleepDaily365V1()
        fetchRestingEnergyDaily365V1()
    }

    // ============================================================
    // MARK: - Private Orchestration (Nutrition-only)
    // ============================================================

    @MainActor
    private func refreshNutritionTodaysKPIs() async {
        fetchNutritionEnergyTodayV1()
        fetchCarbsTodayV1()
        fetchProteinTodayV1()
        fetchFatTodayV1()
        fetchRestingEnergyTodayV1()
    }

    @MainActor
    private func refreshNutritionChartsAndHistory() async {
        fetchLast90DaysNutritionEnergyV1()
        fetchMonthlyNutritionEnergyV1()

        fetchLast90DaysCarbsV1()
        fetchMonthlyCarbsV1()

        fetchLast90DaysProteinV1()
        fetchMonthlyProteinV1()

        fetchLast90DaysFatV1()
        fetchMonthlyFatV1()

        fetchLast90DaysRestingEnergyV1()
        fetchMonthlyRestingEnergyV1()
    }

    @MainActor
    private func refreshNutritionSecondary() async {
        fetchNutritionEnergyDaily365V1()
        fetchCarbsDaily365V1()
        fetchProteinDaily365V1()
        fetchFatDaily365V1()
        fetchRestingEnergyDaily365V1()
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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchExerciseTimeDaily365V1()
            DispatchQueue.main.async { continuation.resume(returning: ()) }
        }
    }

    func fetchMovementSplitFastSliceAsync(last days: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchMovementSplitDaily365V1(last: days) { continuation.resume(returning: ()) }
        }
    }
}
