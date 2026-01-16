//
//  HealthStore+MainChartOverlaysV1.swift
//  GluVibProbe
//
//  MainChart V1 — DayProfile Builder (from existing RAW caches)
//

import Foundation

extension HealthStore {

    // ============================================================
    // MARK: - Public API
    // ============================================================

    @MainActor
    func buildMainChartDayProfileV1(dayStart: Date) -> MainChartDayProfileV1 {
        buildMainChartDayProfileFromCurrentCachesV1(for: dayStart)
    }

    @MainActor
    func buildMainChartDayProfileFromCurrentCachesV1(for day: Date) -> MainChartDayProfileV1 {

        // ========================================================
        // MARK: - Settings Gating (Premium rules)  // !!! NEW
        // ========================================================

        let settings = SettingsModel.shared                              // !!! NEW
        let hasCGM = settings.hasCGM                                    // !!! NEW
        let isInsulinTreated = settings.isInsulinTreated                // !!! NEW

        // ========================================================
        // MARK: - Time Window (0:00 → end)
        // ========================================================

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let todayStart = cal.startOfDay(for: Date())
        let isToday = (dayStart == todayStart)

        let end: Date = isToday ? Date() : dayEnd

        // ========================================================
        // MARK: - CGM (points)
        // ========================================================

        let cgm: [CGMSamplePoint] = {
            guard hasCGM else { return [] }                              // !!! NEW
            return cgmSamples3Days
                .filter { $0.timestamp >= dayStart && $0.timestamp < end }
                .sorted { $0.timestamp < $1.timestamp }
        }()

        // ========================================================
        // MARK: - Insulin (events)
        // ========================================================

        let bolus: [InsulinBolusEvent] = {
            guard hasCGM, isInsulinTreated else { return [] }           // !!! NEW
            return bolusEvents3Days
                .filter { $0.timestamp >= dayStart && $0.timestamp < end }
                .sorted { $0.timestamp < $1.timestamp }
        }()

        let basal: [InsulinBasalEvent] = {
            guard hasCGM, isInsulinTreated else { return [] }           // !!! NEW
            return basalEvents3Days
                .filter { $0.timestamp >= dayStart && $0.timestamp < end }
                .sorted { $0.timestamp < $1.timestamp }
        }()

        // ========================================================
        // MARK: - Nutrition (events)
        // ========================================================

        let carbs = carbEvents3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end && $0.kind == .carbs }
            .sorted { $0.timestamp < $1.timestamp }

        let protein = proteinEvents3Days
            .filter { $0.timestamp >= dayStart && $0.timestamp < end && $0.kind == .protein }
            .sorted { $0.timestamp < $1.timestamp }

        // ========================================================
        // MARK: - Activity + Fingerstick (optional overlays)
        // ========================================================

        let activity = activityEvents3Days
            .filter { $0.end > dayStart && $0.start < end }
            .sorted { $0.start < $1.start }

        let finger = fingerGlucoseEvents3Days
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
            basal: basal,
            carbs: carbs,
            protein: protein,
            activity: activity,
            finger: finger
        )
    }
}
