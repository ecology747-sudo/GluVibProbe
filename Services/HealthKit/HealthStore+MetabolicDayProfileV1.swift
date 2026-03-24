//
//  HealthStore+MetabolicDayProfileV1.swift
//  GluVibProbe
//
//  Metabolic V1 — DayProfile (Raw3Days)
//
//  Ziel (V1 Backbone):
//  - DayProfile Overlay für Today/Yesterday/DayBefore
//  - Minimaler Start: Nutrition Raw Events (3 Tage)
//  - Danach: Insulin Raw (Stubs), CGM folgt später
//
//  Regeln:
//  - Carbs = Pflicht Overlay
//  - Protein = optional Raw Overlay (kein DailyStats)
//
//  SSOT:
//  Apple Health → HealthStore → Published Arrays (Raw3Days)
//

import Foundation

extension HealthStore {

    // ============================================================
    // MARK: - Metabolic V1 DayProfile (Raw3Days) — Public API
    // ============================================================

    @MainActor
    func refreshMetabolicTodayRaw3DaysV1(refreshSource: String) async {
        if isPreview { return }

        // Default “full raw” for non-overview contexts
        await refreshMetabolicRaw3DaysMainChartFastV1(refreshSource: refreshSource)

        if SettingsModel.shared.isInsulinTreated {
            await refreshMetabolicRaw3DaysTherapyOnlyV1(refreshSource: refreshSource)
        }
    }

    // 🟨 UPDATED: fast path for Premium Overview Stage A (no therapy raw fetch)
    @MainActor
    func refreshMetabolicRaw3DaysMainChartFastV1(refreshSource: String) async {
        if isPreview { return }

        // Nutrition Raw Overlay (3 Tage)
        fetchCarbEvents3DaysV1()
        fetchProteinEvents3DaysV1()

        // CGM Raw Overlay (3 Tage)
        fetchCGMSamples3DaysV1()

        // Activity Raw Overlay (3 Tage)
        fetchActivityEvents3DaysV1()

        // Cache Rebuild after RAW fetch calls
        scheduleMainChartCacheRebuildAfterRawFetchesV1()
    }

    // 🟨 UPDATED: therapy-only raw fetch (deferred stage)
    @MainActor
    func refreshMetabolicRaw3DaysTherapyOnlyV1(refreshSource: String) async {
        if isPreview { return }

        // Insulin Raw Overlay (3 Tage)
        fetchBolusEvents3DaysV1()
        fetchBasalEvents3DaysV1()

        // Cache rebuild so overlays show up on MainChart
        scheduleMainChartCacheRebuildAfterRawFetchesV1()
    }

    // ============================================================
    // MARK: - Metabolic V1 DayProfile (Raw3Days) — Helpers
    // ============================================================

    @MainActor
    func clearMetabolicRaw3DaysCacheV1() {
        cgmSamples3Days = []
        bolusEvents3Days = []
        basalEvents3Days = []
        carbEvents3Days = []
        proteinEvents3Days = []
        activityEvents3Days = []
        fingerGlucoseEvents3Days = []
    }

    // ============================================================
    // MARK: - MainChart Cache Wiring Helper
    // ============================================================

    @MainActor
    private func scheduleMainChartCacheRebuildAfterRawFetchesV1() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rebuildMainChartCacheFromRaw3DaysV1()
        }
    }
}
