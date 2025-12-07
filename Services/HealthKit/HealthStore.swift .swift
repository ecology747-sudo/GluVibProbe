//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore: ObservableObject {

    // Singleton-Instanz der App
    static let shared = HealthStore()

    let healthStore = HKHealthStore()
    let isPreview: Bool

    // Standard-Init
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

    // -------------------------
    // 🔶 ACTIVITY ENERGY (kcal)
    // -------------------------
    @Published var todayActiveEnergy: Int = 0
    @Published var last90DaysActiveEnergy: [ActivityEnergyEntry] = []
    @Published var monthlyActiveEnergy: [MonthlyMetricEntry] = []

    // -------------------------
    // 🔵 SLEEP (Minuten)
    // -------------------------
    @Published var todaySleepMinutes: Int = 0
    @Published var last90DaysSleep: [DailySleepEntry] = []
    @Published var monthlySleep: [MonthlyMetricEntry] = []

    // -------------------------
    // 🟠 WEIGHT (kg)
    // -------------------------
    @Published var todayWeightKg: Int = 0
    @Published var todayWeightKgRaw: Double = 0    // 🔥 NEU: ungefilterter HealthKit-Wert
    @Published var last90DaysWeight: [DailyStepsEntry] = []
    @Published var monthlyWeight: [MonthlyMetricEntry] = []

    // -------------------------
    // ❤️ RESTING HEART RATE (bpm)
    // -------------------------
    @Published var todayRestingHeartRate: Int = 0          // !!! NEW
    @Published var last90DaysRestingHeartRate:             // !!! NEW
        [RestingHeartRateEntry] = []                       // !!! NEW
    @Published var monthlyRestingHeartRate:                // !!! NEW
        [MonthlyMetricEntry] = []                          // !!! NEW

    // -------------------------
    // 🧍‍♂️ BODY FAT (%)
    // -------------------------
    @Published var todayBodyFatPercent: Double = 0         // !!! NEW
    @Published var last90DaysBodyFat:                      // !!! NEW
        [BodyFatEntry] = []                                // !!! NEW
    @Published var monthlyBodyFat:                         // !!! NEW
        [MonthlyMetricEntry] = []                          // !!! NEW

    // -------------------------
    // 📊 BMI
    // -------------------------
    @Published var todayBMI: Double = 0                    // !!! NEW
    @Published var last90DaysBMI:                          // !!! NEW
        [BMIEntry] = []                                    // !!! NEW
    @Published var monthlyBMI:                             // !!! NEW
        [MonthlyMetricEntry] = []                          // !!! NEW

    // -------------------------
    // 🟢 CARBS (g)
    // -------------------------
    @Published var todayCarbsGrams: Int = 0
    @Published var last90DaysCarbs: [DailyCarbsEntry] = []
    @Published var monthlyCarbs: [MonthlyMetricEntry] = []

    // -------------------------
    // 🧬 PROTEIN (g)
    // -------------------------
    @Published var todayProteinGrams: Int = 0
    @Published var last90DaysProtein: [DailyProteinEntry] = []
    @Published var monthlyProtein: [MonthlyMetricEntry] = []

    // -------------------------
    // 🧈 FAT (g)
    // -------------------------
    @Published var todayFatGrams: Int = 0
    @Published var last90DaysFat: [DailyFatEntry] = []
    @Published var monthlyFat: [MonthlyMetricEntry] = []

    // -------------------------
    // 🍽️ NUTRITION ENERGY (kcal)
    // -------------------------
    @Published var todayNutritionEnergyKcal: Int = 0
    @Published var last90DaysNutritionEnergy: [DailyNutritionEnergyEntry] = []
    @Published var monthlyNutritionEnergy: [MonthlyMetricEntry] = []

    // ============================================================
    // MARK: - Preview Caches
    // ============================================================

    var previewDailySteps: [DailyStepsEntry] = []
    var previewDailyActiveEnergy: [ActivityEnergyEntry] = []
    var previewDailySleep: [DailySleepEntry] = []
    var previewDailyWeight: [DailyStepsEntry] = []

    var previewDailyCarbs: [DailyCarbsEntry] = []
    var previewDailyProtein: [DailyProteinEntry] = []
    var previewDailyFat: [DailyFatEntry] = []
    var previewDailyNutritionEnergy: [DailyNutritionEnergyEntry] = []

    var previewDailyRestingHeartRate: [RestingHeartRateEntry] = []  // !!! NEW
    var previewDailyBodyFat: [BodyFatEntry] = []                    // !!! NEW
    var previewDailyBMI: [BMIEntry] = []                            // !!! NEW

    // ============================================================
    // MARK: - Authorization
    // ============================================================

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType          = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType  = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let sleepType         = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType        = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            let restingHeartRateType =
                HKQuantityType.quantityType(forIdentifier: .restingHeartRate),     // !!! NEW
            let bodyFatType =
                HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),    // !!! NEW
            let bmiType =
                HKQuantityType.quantityType(forIdentifier: .bodyMassIndex),        // !!! NEW
            let carbsType         = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let proteinType       = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            let fatType           = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            let nutritionEnergyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else {
            return
        }

        healthStore.requestAuthorization(
            toShare: [],
            read: [
                stepType,
                activeEnergyType,
                sleepType,
                weightType,
                restingHeartRateType,                                         // !!! NEW
                bodyFatType,                                                  // !!! NEW
                bmiType,                                                      // !!! NEW
                carbsType,
                proteinType,
                fatType,
                nutritionEnergyType
            ]
        ) { success, error in

            if success {
                // STEPS
                self.fetchStepsToday()
                self.fetchLast90Days()
                self.fetchMonthlySteps()

                // ACTIVITY ENERGY
                self.fetchActiveEnergyToday()
                self.fetchLast90DaysActiveEnergy()
                self.fetchMonthlyActiveEnergy()

                // SLEEP
                self.fetchSleepToday()
                self.fetchLast90DaysSleep()
                self.fetchMonthlySleep()

                // WEIGHT
                self.fetchWeightToday()
                self.fetchLast90DaysWeight()
                self.fetchMonthlyWeight()

                // RESTING HEART RATE                                       // !!! NEW
                self.fetchRestingHeartRateToday()                           // !!! NEW
                self.fetchLast90DaysRestingHeartRate()                      // !!! NEW
                self.fetchMonthlyRestingHeartRate()                         // !!! NEW

                // BODY FAT                                                 // !!! NEW
                self.fetchBodyFatToday()                                    // !!! NEW
                self.fetchLast90DaysBodyFat()                               // !!! NEW
                self.fetchMonthlyBodyFat()                                  // !!! NEW

                // BMI                                                      // !!! NEW
                self.fetchBMIToday()                                        // !!! NEW
                self.fetchLast90DaysBMI()                                   // !!! NEW
                self.fetchMonthlyBMI()                                      // !!! NEW

                // CARBS
                self.fetchCarbsToday()
                self.fetchLast90DaysCarbs()
                self.fetchMonthlyCarbs()

                // PROTEIN
                self.fetchProteinToday { grams in
                    self.todayProteinGrams = grams
                }
                self.fetchProteinDaily(last: 90) { entries in
                    self.last90DaysProtein = entries
                }
                self.fetchProteinMonthly { monthly in
                    self.monthlyProtein = monthly
                }

                // FAT
                self.fetchFatToday { grams in
                    self.todayFatGrams = grams
                }
                self.fetchFatDaily(last: 90) { entries in
                    self.last90DaysFat = entries
                }
                self.fetchFatMonthly { monthly in
                    self.monthlyFat = monthly
                }

                // NUTRITION ENERGY
                self.fetchNutritionEnergyToday { kcal in
                    self.todayNutritionEnergyKcal = kcal
                }
                self.fetchNutritionEnergyDaily(last: 90) { entries in
                    self.last90DaysNutritionEnergy = entries
                }
                self.fetchNutritionEnergyMonthly { monthly in
                    self.monthlyNutritionEnergy = monthly
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // STEPS
        store.todaySteps = 8_532
        store.previewDailySteps = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailyStepsEntry(date: d, steps: Int.random(in: 3_000...12_000))
        }.sorted { $0.date < $1.date }
        store.last90Days = Array(store.previewDailySteps.suffix(90))
        store.monthlySteps = [
            .init(monthShort: "Jul", value: 140_000),
            .init(monthShort: "Aug", value: 152_000),
            .init(monthShort: "Sep", value: 165_000),
            .init(monthShort: "Okt", value: 158_000),
            .init(monthShort: "Nov", value: 171_000)
        ]

        // ACTIVITY ENERGY
        store.todayActiveEnergy = 650
        store.previewDailyActiveEnergy = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return ActivityEnergyEntry(date: d, activeEnergy: Int.random(in: 200...1_200))
        }.sorted { $0.date < $1.date }
        store.last90DaysActiveEnergy = Array(store.previewDailyActiveEnergy.suffix(90))
        store.monthlyActiveEnergy = [
            .init(monthShort: "Jul", value: 18_200),
            .init(monthShort: "Aug", value: 19_500),
            .init(monthShort: "Sep", value: 20_100),
            .init(monthShort: "Okt", value: 19_800),
            .init(monthShort: "Nov", value: 21_000)
        ]

        // SLEEP
        store.todaySleepMinutes = 420
        store.previewDailySleep = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailySleepEntry(date: d, minutes: Int.random(in: 300...540))
        }.sorted { $0.date < $1.date }
        store.last90DaysSleep = Array(store.previewDailySleep.suffix(90))
        store.monthlySleep = [
            .init(monthShort: "Jul", value: 13_200),
            .init(monthShort: "Aug", value: 12_600),
            .init(monthShort: "Sep", value: 13_800),
            .init(monthShort: "Okt", value: 12_900),
            .init(monthShort: "Nov", value: 13_500)
        ]

        // WEIGHT (Preview)
        store.previewDailyWeight = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let w = Int.random(in: 92...100)
            return DailyStepsEntry(date: d, steps: w)
        }.sorted { $0.date < $1.date }
        store.last90DaysWeight = Array(store.previewDailyWeight.suffix(90))
        store.todayWeightKg = store.previewDailyWeight.last?.steps ?? 0

        // RESTING HEART RATE (Preview)                              // !!! FIX
        store.previewDailyRestingHeartRate = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let bpm = Int.random(in: 55...75)
            return RestingHeartRateEntry(date: d, restingHeartRate: bpm)
        }.sorted { $0.date < $1.date }
        store.last90DaysRestingHeartRate = Array(store.previewDailyRestingHeartRate.suffix(90))
        store.todayRestingHeartRate =
            store.previewDailyRestingHeartRate.last?.restingHeartRate ?? 0   // !!! FIX

        // BODY FAT (Preview)                                           // !!! FIX
        store.previewDailyBodyFat = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let percent = Double.random(in: 15.0...25.0)
            return BodyFatEntry(date: d, bodyFatPercent: percent)
        }.sorted { $0.date < $1.date }
        store.last90DaysBodyFat = Array(store.previewDailyBodyFat.suffix(90))
        store.todayBodyFatPercent =
            store.previewDailyBodyFat.last?.bodyFatPercent ?? 0             // !!! FIX

        // BMI (Preview)                                                 // !!! FIX
        store.previewDailyBMI = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let bmi = Double.random(in: 22.0...30.0)
            return BMIEntry(date: d, bmi: bmi)
        }.sorted { $0.date < $1.date }
        store.last90DaysBMI = Array(store.previewDailyBMI.suffix(90))
        store.todayBMI = store.previewDailyBMI.last?.bmi ?? 0              // !!! FIX

        // CARBS
        store.todayCarbsGrams = 180
        store.previewDailyCarbs = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let g = Int.random(in: 80...320)
            return DailyCarbsEntry(date: d, grams: g)
        }.sorted { $0.date < $1.date }
        store.last90DaysCarbs = Array(store.previewDailyCarbs.suffix(90))

        // PROTEIN
        store.todayProteinGrams = 120

        // FAT
        store.todayFatGrams = 70

        // NUTRITION ENERGY
        store.todayNutritionEnergyKcal = 2_200

        return store
    }
}

// ============================================================
// MARK: - NUTRITION ASYNC HELPERS (für Overview & Dashboards)
// ============================================================

extension HealthStore {

    func fetchTodayCarbs() async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchCarbsDaily(last: 1) { entries in
                let value = entries.last?.grams ?? 0
                continuation.resume(returning: value)
            }
        }
    }

    func fetchTodayProtein() async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchProteinDaily(last: 1) { entries in
                let value = entries.last?.grams ?? 0
                continuation.resume(returning: value)
            }
        }
    }

    func fetchTodayFat() async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchFatDaily(last: 1) { entries in
                let value = entries.last?.grams ?? 0
                continuation.resume(returning: value)
            }
        }
    }

    func fetchTodayEnergy() async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchNutritionEnergyDaily(last: 1) { entries in
                let value = entries.last?.energyKcal ?? 0
                continuation.resume(returning: value)
            }
        }
    }

    func fetchLast14DaysEnergy() async throws -> [(day: Int, energy: Int)] {
        await withCheckedContinuation { continuation in
            self.fetchNutritionEnergyDaily(last: 14) { entries in
                let mapped: [(day: Int, energy: Int)] = entries.enumerated().map { idx, entry in
                    (day: idx + 1, energy: entry.energyKcal)
                }
                continuation.resume(returning: mapped)
            }
        }
    }
}
