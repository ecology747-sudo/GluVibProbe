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
    // 🟣 EXERCISE MINUTES (min)
    // -------------------------
    @Published var todayExerciseMinutes: Int = 0
    @Published var last90DaysExerciseMinutes: [DailyExerciseMinutesEntry] = []
    @Published var monthlyExerciseMinutes: [MonthlyMetricEntry] = []

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
    @Published var todayWeightKgRaw: Double = 0
    @Published var last90DaysWeight: [DailyStepsEntry] = []
    @Published var monthlyWeight: [MonthlyMetricEntry] = []

    // -------------------------
    // ❤️ RESTING HEART RATE (bpm)
    // -------------------------
    @Published var todayRestingHeartRate: Int = 0
    @Published var last90DaysRestingHeartRate: [RestingHeartRateEntry] = []
    @Published var monthlyRestingHeartRate: [MonthlyMetricEntry] = []

    // -------------------------
    // 🧍‍♂️ BODY FAT (%)
    // -------------------------
    @Published var todayBodyFatPercent: Double = 0
    @Published var last90DaysBodyFat: [BodyFatEntry] = []
    @Published var monthlyBodyFat: [MonthlyMetricEntry] = []

    // -------------------------
    // 📊 BMI
    // -------------------------
    @Published var todayBMI: Double = 0
    @Published var last90DaysBMI: [BMIEntry] = []
    @Published var monthlyBMI: [MonthlyMetricEntry] = []

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
    var previewDailyExerciseMinutes: [DailyExerciseMinutesEntry] = []
    var previewDailySleep: [DailySleepEntry] = []
    var previewDailyWeight: [DailyStepsEntry] = []

    var previewDailyCarbs: [DailyCarbsEntry] = []
    var previewDailyProtein: [DailyProteinEntry] = []
    var previewDailyFat: [DailyFatEntry] = []
    var previewDailyNutritionEnergy: [DailyNutritionEnergyEntry] = []

    var previewDailyRestingHeartRate: [RestingHeartRateEntry] = []
    var previewDailyBodyFat: [BodyFatEntry] = []
    var previewDailyBMI: [BMIEntry] = []

    // ============================================================
    // MARK: - Authorization
    // ============================================================

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType             = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType     = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let exerciseMinutesType  = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            let moveTimeType         = HKQuantityType.quantityType(forIdentifier: .appleMoveTime),      // !!! NEW
            let sleepType            = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType           = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            let bodyFatType          = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
            let bmiType              = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex),
            let carbsType            = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let proteinType          = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            let fatType              = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            let nutritionEnergyType  = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else {
            return
        }

        let workoutType = HKObjectType.workoutType()                   // !!! NEW

        healthStore.requestAuthorization(
            toShare: [],
            read: [
                stepType,
                activeEnergyType,
                exerciseMinutesType,
                moveTimeType,          // !!! NEW: Apple Move Time für Movement Split
                sleepType,
                weightType,
                restingHeartRateType,
                bodyFatType,
                bmiType,
                carbsType,
                proteinType,
                fatType,
                nutritionEnergyType,
                workoutType            // !!! NEW: Workouts für Last Exercise
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

                // EXERCISE MINUTES
                self.fetchExerciseMinutesToday { minutes in
                    self.todayExerciseMinutes = minutes
                }
                self.fetchLast90DaysExerciseMinutes { entries in
                    self.last90DaysExerciseMinutes = entries
                }
                self.fetchMonthlyExerciseMinutes { monthly in
                    self.monthlyExerciseMinutes = monthly
                }

                // SLEEP
                self.fetchSleepToday()
                self.fetchLast90DaysSleep()
                self.fetchMonthlySleep()

                // WEIGHT
                self.fetchWeightToday()
                self.fetchLast90DaysWeight()
                self.fetchMonthlyWeight()

                // RESTING HEART RATE
                self.fetchRestingHeartRateToday()
                self.fetchLast90DaysRestingHeartRate()
                self.fetchMonthlyRestingHeartRate()

                // BODY FAT
                self.fetchBodyFatToday()
                self.fetchLast90DaysBodyFat()
                self.fetchMonthlyBodyFat()

                // BMI
                self.fetchBMIToday()
                self.fetchLast90DaysBMI()
                self.fetchMonthlyBMI()

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

        // ... (Rest deiner Preview-Logik unverändert lassen)
        // 👉 Diesen Teil kannst du 1:1 aus deiner bestehenden Datei übernehmen.

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
