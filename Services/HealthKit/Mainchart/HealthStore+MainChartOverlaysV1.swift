//
//  HealthStore+MainChartOverlaysV1.swift
//  GluVibProbe
//
//  MainChart V1 — DayProfile Builder (from existing RAW caches)
//
//  Zweck:
//  - Baut einen MainChartDayProfileV1 für einen Kalendertag
//  - Nutzt vorhandene Published RAW Arrays (SSoT = HealthStore)
//  - Keine DailyStats, keine neuen Berechnungen
//
//  Hinweis (Foundation-first):
//  - Aktuell filtert der Builder nur aus den bereits vorhandenen RAW Arrays.
//  - Für echte 7–10 Tage Historie erweitern wir später die Fetches (stabil, Schritt für Schritt).
//

import Foundation

extension HealthStore {

    // ============================================================
    // MARK: - Public API
    // ============================================================

    /// Cache-API Wrapper für konsistentes Wiring:
    /// - Erwartet `dayStart` (00:00 lokaler Tag)
    /// - Wird vom Cache/Refresh-Flow genutzt, ohne dass Views/VMs irgendwas wissen müssen.
    @MainActor
    func buildMainChartDayProfileV1(dayStart: Date) -> MainChartDayProfileV1 {
        buildMainChartDayProfileFromCurrentCachesV1(for: dayStart)
    }

    /// Build a day profile from currently available RAW caches.
    /// IMPORTANT:
    /// - Works immediately for Today/Yesterday/DayBefore (weil Raw3Days gefüllt ist).
    /// - For older days, result may be empty until we extend fetch windows.
    @MainActor
    func buildMainChartDayProfileFromCurrentCachesV1(for day: Date) -> MainChartDayProfileV1 {

        // ========================================================
        // MARK: - Time Window (0:00 → end)
        // ========================================================

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let todayStart = cal.startOfDay(for: Date())
        let isToday = (dayStart == todayStart)

        // For today we cap at "now", for past days we use end-of-day
        let end: Date = isToday ? Date() : dayEnd

        // ========================================================
        // MARK: - CGM (points)
        // ========================================================

        let rawCGM = cgmSamples3Days
        let cgm = rawCGM
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        // ========================================================
        // MARK: - Insulin (events)
        // ========================================================

        let rawBolus = bolusEvents3Days
        let bolus = rawBolus
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        // CHANGE: Basal ist Event (wie Bolus), kein Segment mehr
        let rawBasal = basalEvents3Days
        let basal = rawBasal
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }  // CHANGE: timestamp filter statt overlap
            .sorted { $0.timestamp < $1.timestamp }

        // ========================================================
        // MARK: - Nutrition (events)
        // ========================================================

        let rawCarbs = carbEvents3Days
        let carbs = rawCarbs
            .filter { $0.timestamp >= dayStart && $0.timestamp < end && $0.kind == .carbs }
            .sorted { $0.timestamp < $1.timestamp }

        let rawProtein = proteinEvents3Days
        let protein = rawProtein
            .filter { $0.timestamp >= dayStart && $0.timestamp < end && $0.kind == .protein }
            .sorted { $0.timestamp < $1.timestamp }

        // ========================================================
        // MARK: - Activity + Fingerstick (optional overlays)
        // ========================================================

        let rawActivity = activityEvents3Days
        let activity = rawActivity
            .filter { $0.end > dayStart && $0.start < end }   // overlap filter bleibt korrekt für Activity-Intervalle
            .sorted { $0.start < $1.start }

        let rawFinger = fingerGlucoseEvents3Days
        let finger = rawFinger
            .filter { $0.timestamp >= dayStart && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        // ========================================================
        // MARK: - Compose Profile
        // ========================================================

        return MainChartDayProfileV1(
            id: UUID(),
            day: dayStart,
            builtAt: Date(),
            isToday: isToday,
            cgm: cgm,
            bolus: bolus,
            basal: basal,          // CHANGE: [InsulinBasalEvent]
            carbs: carbs,
            protein: protein,
            activity: activity,
            finger: finger
        )
    }
}
