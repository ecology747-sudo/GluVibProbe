//
//  BodyOverviewViewModel.swift
//  GluVibProbe
//
//  ViewModel for the real Body Overview
//  - Uses HealthStore + SettingsModel
//  - Datenfluss analog zur NutritionOverview (selectedDayOffset / selectedDate / refresh())
//

import Foundation
import SwiftUI
import Combine

// MARK: - Trend models (shared with the View)

struct WeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

@MainActor
final class BodyOverviewViewModel: ObservableObject {

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private let dateProvider: () -> Date
    private let bodyInsightEngine = BodyInsightEngine()   // bleibt

    // MARK: - Published outputs

    // Weight
    @Published var todayWeightKg: Double? = nil
    @Published var targetWeightKg: Double = 0.0
    @Published var weightDeltaKg: Double = 0.0
    @Published var weightTrend: [WeightTrendPoint] = []

    // Sleep
    @Published var lastNightSleepMinutes: Int = 0
    @Published var sleepGoalMinutes: Int = 0
    @Published var sleepGoalCompletion: Double = 0.0      // 0.0–1.5

    // Heart / HRV
    @Published var restingHeartRateBpm: Int = 0
    @Published var hrvMs: Int = 0                         // TODO: später echte HRV-Logik

    // Body composition
    @Published var bmi: Double = 0.0
    @Published var bodyFatPercent: Double = 0.0

    // MARK: - NEU: Day Selection (Today / Yesterday / DayBefore)

    /// 0 = Today, -1 = Yesterday, -2 = DayBefore (wie bei NutritionOverview)
    @Published var selectedDayOffset: Int = 0             // bleibt, analog Nutrition

    /// Abgeleitetes Datum basierend auf `selectedDayOffset`
    var selectedDate: Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: dateProvider())
        return calendar.date(byAdding: .day, value: selectedDayOffset, to: base) ?? base
    }

    // MARK: - Init

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.healthStore = healthStore
        self.settings = settings
        self.dateProvider = dateProvider

        // WICHTIG:
        // Kein automatisches Laden mehr hier, genau wie bei NutritionOverviewViewModel.
        // Die View ruft `refresh()` selbst auf (z. B. in .task oder bei Pager-Wechsel).
    }

    // MARK: - Public API (analog NutritionOverviewViewModel)

    /// Lädt alle Body-Metriken für `selectedDate` neu.
    /// Wird von der View aufgerufen:
    /// - beim ersten Anzeigen (.task)
    /// - bei Pull-to-Refresh
    /// - bei Änderung des Pager-Index (DayBefore / Yesterday / Today)
    func refresh() async {                                 // zentrale Load-Funktion wie bei Nutrition
        // Ziel-Datum für die Abfrage (Today / Yesterday / DayBefore)
        let targetDate = selectedDate

        do {
            // Parallel-Fetch der Body-Metriken über die neuen Helper
            async let sleepMinutesAsync = try healthStore.fetchDailySleepMinutes(for: targetDate)
            async let weightKgRawAsync  = try healthStore.fetchDailyWeightKgRaw(for: targetDate)
            async let bmiAsync          = try healthStore.fetchDailyBMI(for: targetDate)
            async let bodyFatAsync      = try healthStore.fetchDailyBodyFatPercent(for: targetDate)
            async let restingHRAsync    = try healthStore.fetchDailyRestingHeartRate(for: targetDate)
            async let weightTrendAsync  = try healthStore.fetchLast90DaysWeightTrend()

            let (
                sleepMinutes,
                weightKgRaw,
                bmiValue,
                bodyFatValue,
                restingHR,
                weightTrendEntries
            ) = try await (
                sleepMinutesAsync,
                weightKgRawAsync,
                bmiAsync,
                bodyFatAsync,
                restingHRAsync,
                weightTrendAsync
            )

            // -------------------------
            // Sleep
            // -------------------------
            let sleepGoal = settings.dailySleepGoalMinutes

            self.lastNightSleepMinutes = sleepMinutes
            self.sleepGoalMinutes = sleepGoal

            if sleepGoal > 0 {
                self.sleepGoalCompletion = Double(sleepMinutes) / Double(sleepGoal)
            } else {
                self.sleepGoalCompletion = 0.0
            }

            // -------------------------
            // Weight + Fallback + Trend
            // -------------------------
            let hasHKWeight = weightKgRaw > 0
            let settingsWeight = Double(settings.weightKg)
            let settingsTarget = Double(settings.targetWeightKg)

            let currentWeight: Double
            if hasHKWeight {
                currentWeight = weightKgRaw
            } else {
                // 🔥 Fallback: Settings-Wert (bestehendes Verhalten)
                currentWeight = settingsWeight
            }

            self.todayWeightKg = currentWeight
            self.targetWeightKg = settingsTarget
            self.weightDeltaKg = currentWeight - settingsTarget

            // Trend: nur anzeigen, wenn es auch wirklich HealthKit-Gewicht gibt
            if hasHKWeight, !weightTrendEntries.isEmpty {
                // z.B. letzte 10 Mess-Tage als kleinen Trend
                let lastEntries = Array(weightTrendEntries.suffix(10))
                self.weightTrend = lastEntries.map { entry in
                    WeightTrendPoint(
                        date: entry.date,
                        weightKg: Double(entry.steps)   // steps = kg-Int aus Weight-Query
                    )
                }
            } else {
                // ❗ Kein HealthKit-Weight → kein Chart, nur KPI
                self.weightTrend = []
            }

            // -------------------------
            // Resting Heart Rate
            // -------------------------
            self.restingHeartRateBpm = restingHR

            // HRV noch nicht aus HealthKit angebunden → Placeholder
            self.hrvMs = 0

            // -------------------------
            // Body Composition
            // -------------------------
            self.bmi = bmiValue
            self.bodyFatPercent = bodyFatValue

            // Optional: später hier einen Body-Score / abgeleitete Werte berechnen,
            // analog zu recalculateDerivedValues() bei NutritionOverview.

        } catch {
            // Fehlerbehandlung analog NutritionOverview (nur Logging)
            print("BodyOverviewViewModel.refresh error:", error.localizedDescription)
        }
    }

    // MARK: - Formatting helpers (used by the View)

    func formattedWeight(_ value: Double?) -> String {
        guard let value = value else { return "–" }
        return String(format: "%.1f kg", value)
    }

    func formattedWeight(_ value: Double) -> String {
        return String(format: "%.1f kg", value)
    }

    func formattedDeltaKg(_ delta: Double) -> String {
        if delta > 0 {
            return String(format: "+%.1f kg", delta)
        } else if delta < 0 {
            return String(format: "%.1f kg", delta)
        } else {
            return "±0.0 kg"
        }
    }

    func deltaColor(for delta: Double) -> Color {
        if delta > 0 {
            return .red
        } else if delta < 0 {
            return .green
        } else {
            return Color.Glu.primaryBlue
        }
    }

    func formattedSleep(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours) h \(mins) min"
        } else {
            return "\(mins) min"
        }
    }

    func bmiCategoryText(for bmi: Double) -> String {
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal range"
        case 25..<30:
            return "Overweight"
        default:
            return "Obesity range"
        }
    }

    // MARK: - Trend & insight helpers

    /// Trend-Pfeil-Symbol – Logik analog ActivityOverview-Steps:
    /// gestern vs. Durchschnitt der vorangegangenen 1–3 Tage,
    /// Schwelle ~0.3 kg
    func trendArrowSymbol() -> String {
        // wir brauchen mindestens 2 Punkte (mind. ein „gestern“ + ein „davor“)
        guard weightTrend.count >= 2 else {
            return "arrow.right"
        }

        // chronologisch sortieren
        let sorted = weightTrend.sorted { $0.date < $1.date }
        let count = sorted.count

        // letzter Eintrag = heute, vorletzter = gestern
        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else {
            // es gibt keinen Tag „davor“
            return "arrow.right"
        }

        let yesterdayWeight = sorted[yesterdayIndex].weightKg

        // bis zu 3 Tage vor „gestern“ mitteln
        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else {
            return "arrow.right"
        }

        let sumPrev = previousSlice.reduce(0.0) { partial, point in
            partial + point.weightKg
        }
        let avgPrev = sumPrev / Double(previousSlice.count)

        let diff = yesterdayWeight - avgPrev
        let threshold: Double = 0.3   // ~0,3 kg als „deutlich“ definieren

        if diff > threshold {
            // Gewicht ↑
            return "arrow.up.right"
        } else if diff < -threshold {
            // Gewicht ↓
            return "arrow.down.right"
        } else {
            // quasi stabil
            return "arrow.right"
        }
    }

    /// Trend-Pfeil-Farbe:
    /// - Gewicht ↑ (diff > 0)  → rot
    /// - Gewicht ↓ (diff < 0)  → grün
    /// - stabil                 → primaryBlue
    func trendArrowColor() -> Color {
        guard weightTrend.count >= 2 else {
            return Color.Glu.primaryBlue
        }

        let sorted = weightTrend.sorted { $0.date < $1.date }
        let count = sorted.count

        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else {
            return Color.Glu.primaryBlue
        }

        let yesterdayWeight = sorted[yesterdayIndex].weightKg

        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else {
            return Color.Glu.primaryBlue
        }

        let sumPrev = previousSlice.reduce(0.0) { partial, point in
            partial + point.weightKg
        }
        let avgPrev = sumPrev / Double(previousSlice.count)

        let diff = yesterdayWeight - avgPrev

        // hier bewusst die „Gewichtslogik“:
        // ↑ = rot, ↓ = grün
        return deltaColor(for: diff)
    }

    func bodyInsightText() -> String {
        let input = BodyInsightInput(
            weightTrend: weightTrend,
            lastNightSleepMinutes: lastNightSleepMinutes,
            sleepGoalMinutes: sleepGoalMinutes,
            bmi: bmi,
            bodyFatPercent: bodyFatPercent,
            restingHeartRateBpm: restingHeartRateBpm
        )

        return bodyInsightEngine.makeInsight(for: input)
    }

    // MARK: - Preview helper

    static var preview: BodyOverviewViewModel {
        let vm = BodyOverviewViewModel(
            healthStore: HealthStore.preview(),             // nutzt Preview-Store wie Nutrition
            settings: .shared
        )
        return vm
    }
}
