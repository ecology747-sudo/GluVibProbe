//
//  HealthStore+Bootstrap.swift
//  GluVibProbe
//
//  Zentrale Bootstrap/Refresh-Orchestrierung
//  - Einheitliches Verhalten bei:
//    (1) App-Start
//    (2) Pull-to-Refresh
//    (3) Navigation (Overview <-> Metric)
//  - Keine neuen Published Properties
//  - Nutzt nur bestehende Fetch-Funktionen (HealthStore+X)
//

import Foundation

extension HealthStore {

    // MARK: - Refresh Context (optional, nur für Debug/Logging)

    enum RefreshContext: String {
        case appLaunch
        case pullToRefresh
        case navigation
        case periodic
    }

    // MARK: - Public API

    /// Ein einziger Einstiegspunkt, der IMMER dasselbe „Gefühl“ liefert.
    /// - ruft alle Domain-Fetches in definierter Reihenfolge auf
    /// - sorgt dafür, dass Overview/Metric nach Navigation nicht „anders“ sind
    @MainActor
    func refreshAll(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        // Optional: Debug
        // print("🔄 refreshAll:", context.rawValue)

        // 1) „Today“-Werte zuerst (KPI-Gefühl sofort korrekt)
        await refreshTodaysKPIs()

        // 2) Dann Chart-Daten (90d/Monthly etc.)
        await refreshChartsAndHistory()

        // 3) Optional: Dinge, die seltener nötig sind / schwerer sind
        await refreshSecondaryData()
    }

    /// Für Views, die nur Activity betreffen (z.B. ActivityOverview, Steps/ActiveTime/Energy).
    /// Vorteil: schneller als refreshAll, aber konsistent innerhalb Activity.
    @MainActor
    func refreshActivity(_ context: RefreshContext = .pullToRefresh) async {
        if isPreview { return }

        await refreshActivityTodaysKPIs()
        await refreshActivityChartsAndHistory()
        await refreshActivitySecondary()
    }

    // MARK: - Internals (Aufgeteilt, damit es stabil bleibt)

    // ------------------------------------------------------------
    // MARK: - 1) Today KPI Refresh (alle Domains)
    // ------------------------------------------------------------

    @MainActor
    private func refreshTodaysKPIs() async {
        // STEPS
        fetchStepsToday()

        // ACTIVITY ENERGY
        fetchActiveEnergyToday()

        // EXERCISE MINUTES (callback → published)
        await fetchExerciseMinutesTodayAsync()

        // SLEEP
        fetchSleepToday()

        // WEIGHT
        fetchWeightToday()

        // RESTING HR
        fetchRestingHeartRateToday()

        // BODY FAT
        fetchBodyFatToday()

        // BMI
        fetchBMIToday()

        // NUTRITION (async-basiert)
        await fetchCarbsTodayAsync()
        await fetchProteinTodayAsync()
        await fetchFatTodayAsync()
        await fetchNutritionEnergyTodayAsync()
    }

    // ------------------------------------------------------------
    // MARK: - 2) Charts/History Refresh (alle Domains)
    // ------------------------------------------------------------

    @MainActor
    private func refreshChartsAndHistory() async {
        // STEPS
        fetchLast90Days()
        fetchMonthlySteps()

        // ACTIVITY ENERGY
        fetchLast90DaysActiveEnergy()
        fetchMonthlyActiveEnergy()

        // EXERCISE MINUTES
        await fetchLast90DaysExerciseMinutesAsync()
        await fetchMonthlyExerciseMinutesAsync()

        // SLEEP
        fetchLast90DaysSleep()
        fetchMonthlySleep()

        // WEIGHT
        fetchLast90DaysWeight()
        fetchMonthlyWeight()

        // RESTING HR
        fetchLast90DaysRestingHeartRate()
        fetchMonthlyRestingHeartRate()

        // BODY FAT
        fetchLast90DaysBodyFat()
        fetchMonthlyBodyFat()

        // BMI
        fetchLast90DaysBMI()
        fetchMonthlyBMI()

        // NUTRITION
        fetchLast90DaysCarbs()
        fetchMonthlyCarbs()

        await fetchProteinDailyAsync(last: 90, assign: { [weak self] entries in
            self?.last90DaysProtein = entries
        })
        await fetchProteinMonthlyAsync()

        await fetchFatDailyAsync(last: 90, assign: { [weak self] entries in
            self?.last90DaysFat = entries
        })
        await fetchFatMonthlyAsync()

        await fetchNutritionEnergyDailyAsync(last: 90, assign: { [weak self] entries in
            self?.last90DaysNutritionEnergy = entries
        })
        await fetchNutritionEnergyMonthlyAsync()
    }

    // ------------------------------------------------------------
    // MARK: - 3) Secondary/Optional Refresh (z.B. Workouts)
    // ------------------------------------------------------------

    @MainActor
    private func refreshSecondaryData() async {
        // Wenn du irgendwo Last Exercise nutzt:
        // -> Workouts werden bei dir async via HealthStore+ActivityOverview geholt.
        // -> Hier KEIN Published-Assign, weil du Workouts vermutlich direkt im VM holst.
        // (Absichtlich leer lassen, bis du es zentralisieren willst.)
    }

    // ------------------------------------------------------------
    // MARK: - Activity-only Refresh (schneller)
    // ------------------------------------------------------------

    @MainActor
    private func refreshActivityTodaysKPIs() async {
        fetchStepsToday()
        fetchActiveEnergyToday()
        await fetchExerciseMinutesTodayAsync()
        // MovementSplit nutzt vermutlich MoveTime + Sleep: je nach Implementierung
        // -> SleepToday kann für den Split relevant sein
        fetchSleepToday()
    }

    @MainActor
    private func refreshActivityChartsAndHistory() async {
        fetchLast90Days()
        fetchMonthlySteps()

        fetchLast90DaysActiveEnergy()
        fetchMonthlyActiveEnergy()

        await fetchLast90DaysExerciseMinutesAsync()
        await fetchMonthlyExerciseMinutesAsync()

        // MovementSplit Charts: falls du 30 Tage Splits hast, bleibt das im MovementSplitViewModel
        // -> oder später hier zentralisieren
    }

    @MainActor
    private func refreshActivitySecondary() async {
        // Workouts / Last Exercise / Insight Inputs etc.
        // aktuell bewusst leer (VM lädt Workouts selbst)
    }
}

// ============================================================
// MARK: - Async Wrapper für callback-basierte Fetches
// ============================================================

private extension HealthStore {

    // EXERCISE TODAY
    func fetchExerciseMinutesTodayAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchExerciseMinutesToday { minutes in
                DispatchQueue.main.async {
                    self.todayExerciseMinutes = minutes
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // EXERCISE 90D
    func fetchLast90DaysExerciseMinutesAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchLast90DaysExerciseMinutes { entries in
                DispatchQueue.main.async {
                    self.last90DaysExerciseMinutes = entries
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // EXERCISE MONTHLY
    func fetchMonthlyExerciseMinutesAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchMonthlyExerciseMinutes { monthly in
                DispatchQueue.main.async {
                    self.monthlyExerciseMinutes = monthly
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // CARBS TODAY (async → published)
    func fetchCarbsTodayAsync() async {
        do {
            let grams = try await fetchTodayCarbs()
            await MainActor.run {
                self.todayCarbsGrams = grams
            }
        } catch {
            // optional: print("fetchCarbsTodayAsync failed:", error)
        }
    }

    // PROTEIN TODAY (async → published)
    func fetchProteinTodayAsync() async {
        do {
            let grams = try await fetchTodayProtein()
            await MainActor.run {
                self.todayProteinGrams = grams
            }
        } catch {
            // optional: print("fetchProteinTodayAsync failed:", error)
        }
    }

    // FAT TODAY (async → published)
    func fetchFatTodayAsync() async {
        do {
            let grams = try await fetchTodayFat()
            await MainActor.run {
                self.todayFatGrams = grams
            }
        } catch {
            // optional: print("fetchFatTodayAsync failed:", error)
        }
    }

    // NUTRITION ENERGY TODAY (async → published)
    func fetchNutritionEnergyTodayAsync() async {
        do {
            let kcal = try await fetchTodayEnergy()
            await MainActor.run {
                self.todayNutritionEnergyKcal = kcal
            }
        } catch {
            // optional: print("fetchNutritionEnergyTodayAsync failed:", error)
        }
    }

    // PROTEIN DAILY
    func fetchProteinDailyAsync(last days: Int, assign: @escaping ([DailyProteinEntry]) -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchProteinDaily(last: days) { entries in
                DispatchQueue.main.async {
                    assign(entries)
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // PROTEIN MONTHLY
    func fetchProteinMonthlyAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchProteinMonthly { monthly in
                DispatchQueue.main.async {
                    self.monthlyProtein = monthly
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // FAT DAILY
    func fetchFatDailyAsync(last days: Int, assign: @escaping ([DailyFatEntry]) -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchFatDaily(last: days) { entries in
                DispatchQueue.main.async {
                    assign(entries)
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // FAT MONTHLY
    func fetchFatMonthlyAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchFatMonthly { monthly in
                DispatchQueue.main.async {
                    self.monthlyFat = monthly
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // NUTRITION ENERGY DAILY
    func fetchNutritionEnergyDailyAsync(last days: Int, assign: @escaping ([DailyNutritionEnergyEntry]) -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchNutritionEnergyDaily(last: days) { entries in
                DispatchQueue.main.async {
                    assign(entries)
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // NUTRITION ENERGY MONTHLY
    func fetchNutritionEnergyMonthlyAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchNutritionEnergyMonthly { monthly in
                DispatchQueue.main.async {
                    self.monthlyNutritionEnergy = monthly
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
