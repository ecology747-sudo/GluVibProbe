//
//  HealthStore+Bootstrap.swift
//  GluVibProbe
//
//  Zentrale Bootstrap/Refresh-Orchestrierung
//  ------------------------------------------------------------
//  - Einheitliches Verhalten bei:
//    (1) App-Start
//    (2) Pull-to-Refresh
//    (3) Navigation (Overview <-> Metric)
//  - Keine neuen Published Properties
//  - WICHTIG: In dieser Datei werden KEINE Metric-Fetch-Funktionen definiert,
//             nur orchestriert (sonst: "Invalid redeclaration").
//

import Foundation

// ============================================================
// MARK: - HealthStore Bootstrap / Refresh Orchestrator
// ============================================================

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

            // !!! NEW: Metabolic (Navigation)
            await refreshMetabolicChartsAndHistory(context)

            return
        }

        await refreshTodaysKPIs()
        await refreshChartsAndHistory()
        await refreshSecondaryData()

        // !!! NEW: Metabolic (Full)
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
    func refreshNutrition(_ context: RefreshContext = .pullToRefresh) async {            // !!! NEW
        if isPreview { return }                                                          // !!! NEW

        if context == .navigation {                                                      // !!! NEW
            await refreshNutritionTodaysKPIs()                                            // !!! NEW
            await refreshNutritionChartsAndHistory()                                      // !!! NEW
            return                                                                        // !!! NEW
        }                                                                                 // !!! NEW

        await refreshNutritionTodaysKPIs()                                                // !!! NEW
        await refreshNutritionChartsAndHistory()                                          // !!! NEW
        await refreshNutritionSecondary()                                                 // !!! NEW
    }                                                                                     // !!! NEW

    // ============================================================
    // MARK: - !!! NEW: Public Orchestration (Metabolic-only)
    // ============================================================

    @MainActor
    func refreshMetabolic(_ context: RefreshContext = .pullToRefresh) async {            // !!! NEW
        if isPreview { return }                                                          // !!! NEW

        if context == .navigation {                                                      // !!! NEW
            await refreshMetabolicTodaysKPIs(context)                                     // !!! NEW
            await refreshMetabolicChartsAndHistory(context)                               // !!! NEW
            return                                                                        // !!! NEW
        }                                                                                 // !!! NEW

        await refreshMetabolicTodaysKPIs(context)                                         // !!! NEW
        await refreshMetabolicChartsAndHistory(context)                                   // !!! NEW
        await refreshMetabolicSecondary(context)                                          // !!! NEW
    }                                                                                     // !!! NEW

    // ============================================================
    // MARK: - Private Orchestration (All Domains)
    // ============================================================

    // ------------------------------------------------------------
    // MARK: 1) Today KPIs (alle Domains)
    // ------------------------------------------------------------

    @MainActor
    private func refreshTodaysKPIs() async {

        // ----------------------------------------------------
        // STEPS
        // ----------------------------------------------------
        fetchStepsTodayV1()

        // ----------------------------------------------------
        // ACTIVITY
        // ----------------------------------------------------
        fetchActiveEnergyTodayV1()
        fetchRestingEnergyTodayV1()                                                       // !!! UPDATED (Resting Energy TODAY)

        await refreshExerciseMinutesTodayFromExerciseTimeV1Async()

        // ----------------------------------------------------
        // SLEEP
        // ----------------------------------------------------
        fetchSleepTodayV1()

        // ----------------------------------------------------
        // MOVEMENT SPLIT
        // ----------------------------------------------------
        await fetchMovementSplitFastSliceAsync(last: 3)

        // ----------------------------------------------------
        // BODY
        // ----------------------------------------------------
        fetchWeightTodayV1()
        fetchRestingHeartRateTodayV1()
        fetchBodyFatTodayV1()                                                             // !!! UPDATED (war fetchFatTodayV1)
        fetchBMITodayV1()

        // ----------------------------------------------------
        // NUTRITION
        // ----------------------------------------------------
        fetchNutritionEnergyTodayV1()
        fetchCarbsTodayV1()
        fetchProteinTodayV1()
        fetchFatTodayV1()                                                                 // !!! UPDATED (NUTRITION FAT bleibt hier)
    }

    // ------------------------------------------------------------
    // MARK: 2) Charts/History (alle Domains)
    // ------------------------------------------------------------

    @MainActor
    private func refreshChartsAndHistory() async {

        // ----------------------------------------------------
        // STEPS
        // ----------------------------------------------------
        fetchStepsDaily365V1()

        // ----------------------------------------------------
        // ACTIVITY
        // ----------------------------------------------------
        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()

        // !!! NEW: Resting Energy History (needed for Yesterday/DayBefore in Nutrition Overview)
        fetchLast90DaysRestingEnergyV1()                                                   // !!! NEW
        fetchMonthlyRestingEnergyV1()                                                      // !!! NEW

        await refreshExerciseMinutesHistoryFromExerciseTimeV1Async()

        // ----------------------------------------------------
        // SLEEP
        // ----------------------------------------------------
        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()
        fetchSleepDaily365V1()                                                             // !!! UPDATED: needed as base-series for charts

        // ----------------------------------------------------
        // BODY
        // ----------------------------------------------------
        // WEIGHT (V1)
        fetchWeightDaily365RawV1()

        // RESTING HEART RATE (V1)
        fetchLast90DaysRestingHeartRateV1()
        fetchMonthlyRestingHeartRateV1()

        // BODY FAT (V1)
        fetchLast90DaysBodyFatV1()                                                        // !!! UPDATED
        fetchMonthlyBodyFatV1()                                                           // !!! UPDATED

        // BMI (V1)
        fetchLast90DaysBMIV1()
        fetchMonthlyBMIV1()

        // ✅ REQUIRED: Overview Past Days need Daily365 caches too (BMI/BodyFat were missing)
        fetchBMIDaily365V1()                                                              // !!! NEW
        fetchBodyFatDaily365V1()                                                          // !!! NEW

        // ----------------------------------------------------
        // NUTRITION (V1 only)
        // ----------------------------------------------------
        fetchLast90DaysNutritionEnergyV1()
        fetchMonthlyNutritionEnergyV1()

        fetchLast90DaysCarbsV1()
        fetchMonthlyCarbsV1()

        fetchLast90DaysProteinV1()
        fetchMonthlyProteinV1()

        fetchLast90DaysFatV1()
        fetchMonthlyFatV1()
    }

    // ------------------------------------------------------------
    // MARK: 3) Secondary (optional / heavy)
    // ------------------------------------------------------------

    @MainActor
    private func refreshSecondaryData() async {

        // ----------------------------------------------------
        // RESTING ENERGY Secondary
        // ----------------------------------------------------
        fetchRestingEnergyDaily365V1()                                                     // !!! NEW

        // ----------------------------------------------------
        // NUTRITION Secondary (V1 only)
        // ----------------------------------------------------
        fetchNutritionEnergyDaily365V1()
        fetchCarbsDaily365V1()
        fetchProteinDaily365V1()
        fetchFatDaily365V1()

        // ----------------------------------------------------
        // SLEEP Secondary
        // ----------------------------------------------------
        fetchSleepDaily365V1()                                                             // !!! UPDATED: keep single call
    }

    // ============================================================
    // MARK: - Private Orchestration (Activity-only)
    // ============================================================

    @MainActor
    private func refreshActivityTodaysKPIs() async {
        fetchStepsTodayV1()
        fetchActiveEnergyTodayV1()
        fetchRestingEnergyTodayV1()                                                       // !!! UPDATED
        await refreshExerciseMinutesTodayFromExerciseTimeV1Async()
        fetchSleepTodayV1()

        fetchMoveTimeTodayV1()
        fetchWorkoutMinutesTodayV1()

        await fetchMovementSplitFastSliceAsync(last: 3)
    }

    @MainActor
    private func refreshActivityChartsAndHistory() async {

        fetchStepsDaily365V1()

        fetchLast90DaysActiveEnergyV1()
        fetchMonthlyActiveEnergyV1()

        // !!! NEW: Resting Energy History (keine UI-Pflicht in Activity, aber konsistent verfügbar)
        fetchLast90DaysRestingEnergyV1()                                                   // !!! NEW
        fetchMonthlyRestingEnergyV1()                                                      // !!! NEW

        await refreshExerciseMinutesHistoryFromExerciseTimeV1Async()

        fetchLast90DaysWorkoutMinutesV1()
        fetchMonthlyWorkoutMinutesV1()
        fetchWorkoutMinutesDaily365V1()

        fetchLast90DaysMoveTimeV1()
        fetchMonthlyMoveTimeV1()
        fetchMoveTimeDaily365V1()

        // ----------------------------------------------------
        // SLEEP: Session-Series for Charts (ending that day)
        // ----------------------------------------------------
        fetchLast90DaysSleepV1()                                                           // !!! NEW
        fetchMonthlySleepV1()                                                              // !!! UPDATED: keep consistent
        fetchSleepDaily365V1()                                                             // !!! UPDATED: required for detail charts

        await fetchMovementSplitFastSliceAsync(last: 90)
    }

    @MainActor
    private func refreshActivitySecondary() async {
        fetchStepsDaily365V1()
        fetchActiveEnergyDaily365V1()
        fetchExerciseTimeDaily365V1()
        fetchMovementSplitDaily365V1(last: 365)
        fetchMoveTimeDaily365V1()

        // ----------------------------------------------------
        // SLEEP Secondary
        // ----------------------------------------------------
        fetchSleepDaily365V1()                                                             // !!! UPDATED: keep single call

        // !!! NEW
        fetchRestingEnergyDaily365V1()                                                     // !!! NEW
    }

    // ============================================================
    // MARK: - Private Orchestration (Body-only)
    // ============================================================

    @MainActor
    private func refreshBodyTodaysKPIs() async {

        // SLEEP (V1)
        fetchSleepTodayV1()

        // WEIGHT (V1)
        fetchWeightTodayV1()                                                               // !!! UPDATED (war fetchWeightDaily365RawV1)

        // RESTING HEART RATE (V1)
        fetchRestingHeartRateTodayV1()

        // BODY FAT (V1)
        fetchBodyFatTodayV1()

        // BMI (V1)
        fetchBMITodayV1()
    }

    @MainActor
    private func refreshBodyChartsAndHistory() async {

        // SLEEP
        fetchLast90DaysSleepV1()
        fetchMonthlySleepV1()
        fetchSleepDaily365V1()                                                             // !!! UPDATED: required for detail charts

        // WEIGHT
        fetchLast90DaysWeightV1()
        fetchMonthlyWeightV1()

        // RESTING HR (V1)
        fetchLast90DaysRestingHeartRateV1()
        fetchMonthlyRestingHeartRateV1()

        // BODY FAT (V1)
        fetchLast90DaysBodyFatV1()
        fetchMonthlyBodyFatV1()

        // BMI (V1)
        fetchLast90DaysBMIV1()
        fetchMonthlyBMIV1()

        // ✅ REQUIRED for Overview Past Days (Daily365 Caches)
        fetchWeightDaily365RawV1()                                                         // !!! NEW (required)
        fetchBMIDaily365V1()                                                               // !!! NEW (required)
        fetchBodyFatDaily365V1()                                                           // !!! NEW (required)
    }

    @MainActor
    private func refreshBodySecondary() async {
        fetchWeightDaily365RawV1()
        fetchBMIDaily365V1()
        fetchBodyFatDaily365V1()
        fetchRestingHeartRateDaily365V1()
        fetchSleepDaily365V1()

        // !!! NEW
        fetchRestingEnergyDaily365V1()                                                     // !!! NEW
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

        fetchRestingEnergyTodayV1()                                                        // !!! UPDATED (Resting Energy TODAY for Nutrition Overview)
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

        // !!! NEW: Resting Energy History (needed for Yesterday/DayBefore)
        fetchLast90DaysRestingEnergyV1()                                                   // !!! NEW
        fetchMonthlyRestingEnergyV1()                                                      // !!! NEW
    }

    @MainActor
    private func refreshNutritionSecondary() async {
        fetchNutritionEnergyDaily365V1()
        fetchCarbsDaily365V1()
        fetchProteinDaily365V1()
        fetchFatDaily365V1()

        // !!! NEW
        fetchRestingEnergyDaily365V1()                                                     // !!! NEW
    }

    // ============================================================
    // MARK: - !!! NEW: Private Orchestration (Metabolic-only)
    // ============================================================

    @MainActor
    private func refreshMetabolicTodaysKPIs(_ context: RefreshContext) async {             // !!! NEW
        // KPI kommen in den VMs aus daily*90 Serien.
        // Daher: wir refreshen die DailyStats (90) auch für KPI-Konsistenz.
        await refreshMetabolicDailyStats90V1FromContext(context)                           // !!! NEW

        // Carbs/Bolus Ratio braucht Carbs TODAY auch (für Header/KPI optional).
        // (harmlos, existiert bereits in Nutrition V1)
        fetchCarbsTodayV1()                                                                // !!! NEW
    }

    @MainActor
    private func refreshMetabolicChartsAndHistory(_ context: RefreshContext) async {      // !!! NEW
        // Core Metabolic: Bolus/Basal + Ratio-Basis
        await refreshMetabolicDailyStats90V1FromContext(context)                           // !!! NEW

        // Carbs/Bolus Ratio braucht Carbs 90d Serie als Input
        fetchLast90DaysCarbsV1()                                                           // !!! NEW

        // (Optional, bereits vorhanden; nützlich für spätere DayProfile Overlays)
        fetchCarbEvents3DaysV1()                                                           // !!! NEW
    }

    @MainActor
    private func refreshMetabolicSecondary(_ context: RefreshContext) async {             // !!! NEW
        // Metabolic V1 hat aktuell kein 365/Monthly – daher “Secondary” bewusst minimal.
        // Wir halten hier nur Nutrition-Carbs 365 bereit, falls du später Ratio/Trends >90 brauchst.
        fetchCarbsDaily365V1()                                                             // !!! NEW
    }

    @MainActor
    private func refreshMetabolicDailyStats90V1FromContext(_ context: RefreshContext) async { // !!! NEW
        // BolusView/BasalView nutzen refreshSource Strings.
        // Wir mappen Bootstrap-Context -> refreshSource deterministisch.
        await refreshMetabolicDailyStats90V1(refreshSource: "bootstrap-\(context.rawValue)")    // !!! NEW
    }
}

// ============================================================
// MARK: - Async Helpers (nur Wrapper / keine neue Logik)
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
