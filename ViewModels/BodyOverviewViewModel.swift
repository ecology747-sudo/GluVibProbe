//
//  BodyOverviewViewModel.swift
//  GluVibProbe
//
//  ViewModel for the real Body Overview
//  - Uses HealthStore + SettingsModel
//  - Preview bleibt über Mock-Daten stabil
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
    private let bodyInsightEngine = BodyInsightEngine()   // 👈 NEU

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

    // MARK: - State

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Init

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.healthStore = healthStore
        self.settings = settings
        self.dateProvider = dateProvider

        Task {
            await loadData()
        }
    }

    // MARK: - Public API

    func refresh() async {
        await loadData()
    }

    // MARK: - Core Loading Logic

    /// Lädt Daten entweder aus echten HealthStore-Werten (Produktivmodus)
    /// oder aus Mock-Daten (Preview / Design-Phase).
    private func loadData() async {
        isLoading = true
        errorMessage = nil

        if healthStore.isPreview {
            await loadPreviewMockData()
        } else {
            await loadFromHealthStore()
        }

        isLoading = false
    }

    // ============================================================
    // MARK: - Preview / Mock-Daten (für Previews & Design)
    // ============================================================

    private func loadPreviewMockData() async {
        let today = dateProvider()

        // Dummy weight trend (10 measurements, slightly decreasing)
        let weightTrendMock: [WeightTrendPoint] = (0..<10).map { offset in
            let date = Calendar.current.date(
                byAdding: .day,
                value: -9 + offset,
                to: today
            ) ?? today

            let weight = 96.0 - Double(offset) * 0.2
            return WeightTrendPoint(date: date, weightKg: weight)
        }

        self.todayWeightKg = 96.0
        self.targetWeightKg = 92.0
        self.weightDeltaKg = (todayWeightKg ?? 0) - targetWeightKg
        self.weightTrend = weightTrendMock

        self.lastNightSleepMinutes = 450            // 7.5h
        self.sleepGoalMinutes = 480                 // 8h
        self.sleepGoalCompletion = Double(lastNightSleepMinutes) / Double(sleepGoalMinutes)

        self.restingHeartRateBpm = 58
        self.hrvMs = 72

        self.bmi = 29.4
        self.bodyFatPercent = 23.0
    }

    // ============================================================
    // MARK: - Produktiv: Werte direkt aus HealthStore + Settings
    // ============================================================

    private func loadFromHealthStore() async {

        // 🔹 Basis: HealthStore wurde bereits über requestAuthorization() befüllt.
        // Wir lesen hier die aktuellen Published-Werte aus und ergänzen sie mit Settings.

        // -------------------------
        // Sleep
        // -------------------------
        let sleepMinutes = healthStore.todaySleepMinutes
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
        let hkWeightRaw = healthStore.todayWeightKgRaw          // echter Double-Wert aus HK
        let hasHKWeight = hkWeightRaw > 0

        let settingsWeight = Double(settings.weightKg)
        let settingsTarget = Double(settings.targetWeightKg)

        let currentWeight: Double
        if hasHKWeight {
            currentWeight = hkWeightRaw
        } else {
            // 🔥 Fallback: Settings-Wert
            currentWeight = settingsWeight
        }

        self.todayWeightKg = currentWeight
        self.targetWeightKg = settingsTarget
        self.weightDeltaKg = currentWeight - settingsTarget

        // Trend: nur anzeigen, wenn es auch wirklich HealthKit-Gewicht gibt
        if hasHKWeight, !healthStore.last90DaysWeight.isEmpty {
            // z.B. letzte 10 Mess-Tage als kleinen Trend
            let lastEntries = Array(healthStore.last90DaysWeight.suffix(10))
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
        self.restingHeartRateBpm = healthStore.todayRestingHeartRate

        // HRV noch nicht aus HealthKit angebunden → Placeholder
        self.hrvMs = 0

        // -------------------------
        // Body Composition
        // -------------------------
        self.bmi = healthStore.todayBMI
        self.bodyFatPercent = healthStore.todayBodyFatPercent
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

    func trendArrowSymbol() -> String {
        guard let first = weightTrend.first?.weightKg,
              let last = weightTrend.last?.weightKg else {
            return "arrow.right"
        }
        let diff = last - first
        if diff > 0.5 {
            return "arrow.up.right"
        } else if diff < -0.5 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }

    func trendArrowColor() -> Color {
        guard let first = weightTrend.first?.weightKg,
              let last = weightTrend.last?.weightKg else {
            return Color.Glu.primaryBlue
        }
        let diff = last - first
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
            healthStore: HealthStore(isPreview: true),
            settings: .shared
        )
        return vm
    }
}
