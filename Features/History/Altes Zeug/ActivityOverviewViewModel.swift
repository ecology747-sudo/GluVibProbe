//
//  ActivityOverviewViewModel.swift
//  GluVibProbe
//
//  Aggregiert Steps /  "Active Time", / Activity Energy / Movement Split
//  für die ActivityOverviewView.
//

import Foundation
import Combine
import HealthKit                                  // für HKWorkout / HKWorkoutActivityType

final class ActivityOverviewViewModel: ObservableObject {

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel

    private let stepsViewModel: StepsViewModelV1
    private let exerciseViewModel: ExerciseMinutesViewModel
    private let activeEnergyViewModel: ActivityEnergyViewModel
    private let movementSplitViewModel: MovementSplitViewModel

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Insight & Score Engines
    private let activityScoreEngine = ActivityScoreEngine()
    
    // MARK: - Intern: Letztes Workout für Insight/ScoreEngine
    private var lastWorkoutForInsight: HKWorkout? = nil

    // MARK: - Last Exercise Display

    @Published var lastExercisesDisplay: [(name: String, detail: String, date: String, time: String)] = []
    
    // MARK: - Insight output for the card

    @Published var activityInsightText: String = ""
    @Published var activityInsightCategory: ActivityInsightCategory = .neutral

    // MARK: - Activity Score (Overview header)

    @Published var activityScore: Int = 0
    
    // MARK: - Day Selection (Pager: DayBefore / Yesterday / Today)

    /// 0 = Today, -1 = Yesterday, -2 = DayBeforeYesterday
    @Published var selectedDayOffset: Int = 0                     // !!! NEW

    /// Ausgewähltes Datum basierend auf selectedDayOffset
    var selectedDate: Date {                                      // !!! NEW
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: selectedDayOffset, to: today) ?? today
    }

    // MARK: - Published Output (für ActivityOverviewView)

    // Steps-Kachel
    @Published var todaySteps: Int = 0
    @Published var stepsGoal: Int = 0
    @Published var stepsSevenDayAverage: Int = 0

    @Published var distanceTodayKm: Double = 0
    @Published var distanceSevenDayAverageKm: Double = 0

    /// Mini-Trend für 7 Tage (relativ zum gewählten Datum)
    @Published var lastSevenDaysSteps: [DailyStepsEntry] = []

    // Exercise-Kachel
    @Published var todayExerciseMinutes: Int = 0
    @Published var sevenDayAverageExerciseMinutes: Int = 0

    // Active-Energy-Kachel
    @Published var todayActiveEnergyKcal: Int = 0
    @Published var sevenDayAverageActiveEnergyKcal: Int = 0

    // Movement-Split (für ausgewählten Tag)
    @Published var movementSleepMinutesToday: Int = 0
    @Published var movementActiveMinutesToday: Int = 0
    @Published var movementSedentaryMinutesToday: Int = 0

    /// Anteil des Tages, der bereits vergangen ist (0.0–1.0)
    @Published var movementSplitFillFractionOfDay: Double = 0

    /// Prozent-Anteile innerhalb der bisher vergangenen Tageszeit
    /// (sleep + move + sedentary ≈ 1.0)
    @Published var movementSplitPercentages: (sleep: Double, move: Double, sedentary: Double) = (0, 0, 0)

    // MARK: - Init

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        // Child-ViewModels wie in den Detail-Views
        self.stepsViewModel = StepsViewModelV1(
            healthStore: healthStore,
            settings: settings
        )
        self.exerciseViewModel = ExerciseMinutesViewModel(
            healthStore: healthStore
        )
        self.activeEnergyViewModel = ActivityEnergyViewModel(
            healthStore: healthStore,
            settings: settings
        )
        self.movementSplitViewModel = MovementSplitViewModel(
            healthStore: healthStore
        )

        bindChildViewModels()
    }

    // MARK: - Binding

    private func bindChildViewModels() {

        // 🟦 STEPS
        stepsViewModel.$todaySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                // Live-Update nur für Today – bei Yesterday/DayBefore
                // wird alles über refreshForSelectedDay() gemappt.     // !!! UPDATED
                if self.selectedDayOffset == 0 {
                    self.todaySteps = value
                    self.updateDistanceForSelectedDay()   // << richtige Helper-Funktion
                    self.updateStepsAggregatesForSelectedDay()        // !!! NEW
                    self.updateActivityInsight()
                }
            }
            .store(in: &cancellables)

        stepsViewModel.$dailyStepsGoalInt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                self.stepsGoal = value
                self.updateActivityInsight()
            }
            .store(in: &cancellables)

        stepsViewModel.$dailySteps365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Wenn neue History reinkommt, mappen wir erneut
                // die Steps-Daten auf den aktuell ausgewählten Tag.   // !!! NEW
                Task { @MainActor in
                    await self.refreshForSelectedDay()
                }
            }
            .store(in: &cancellables)

        // 🟩 EXERCISE MINUTES
        exerciseViewModel.$todayExerciseMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self else { return }
                // Live-Update nur für Today, sonst übernimmt die Day-Logik
                if self.selectedDayOffset == 0 {
                    self.todayExerciseMinutes = value
                    self.updateActivityInsight()
                }
            }
            .store(in: &cancellables)

        exerciseViewModel.$dailyExerciseMinutes365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Bei Änderung der History -> Day-Remapping
                Task { @MainActor in                                  // !!! NEW
                    await self.refreshForSelectedDay()
                }
            }
            .store(in: &cancellables)

        // 🔥 ACTIVE ENERGY (Basis: kcal)
        activeEnergyViewModel.$dailyActiveEnergy365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }

                // Nur für Today live aus dem Detail-VM übernehmen,
                // bei Yesterday/DayBefore remappen wir separat.       // !!! UPDATED
                if self.selectedDayOffset == 0 {
                    self.todayActiveEnergyKcal =
                        self.activeEnergyViewModel.todayActiveEnergyKcal
                    self.sevenDayAverageActiveEnergyKcal =
                        self.activeEnergyViewModel.sevenDayAverageActiveEnergyKcal
                    self.updateActivityInsight()
                } else {
                    Task { @MainActor in
                        await self.refreshForSelectedDay()
                    }
                }
            }
            .store(in: &cancellables)

        // 🟣 MOVEMENT SPLIT (Sleep / Active / Sedentary)
        movementSplitViewModel.$dailyMovementSplits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Immer auf den aktuell gewählten Tag mappen          // !!! UPDATED
                self.updateMovementSplitForSelectedDay()
                self.updateActivityInsight()
            }
            .store(in: &cancellables)
    }

    // MARK: - Day Selection API (für Pager)

    /// Wird vom Pager (ActivityOverviewView) aufgerufen,
    /// wenn der User auf Yesterday / DayBefore / Today swiped.
    @MainActor
    func applySelectedDayOffset(_ offset: Int) async {
        selectedDayOffset = offset
        await refreshForSelectedDay()
    }

    /// Mapped alle Overview-Werte auf das aktuell gewählte Datum.
    @MainActor
    private func refreshForSelectedDay() async {

        let date = selectedDate
        let calendar = Calendar.current

        // ============================================================
        // 1) STEPS für gewählten Tag
        // ============================================================

        let allSteps = stepsViewModel.dailySteps365

        // Tagesschritte für das ausgewählte Datum
        let stepsForDay = allSteps.first(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        })?.steps ?? 0

        todaySteps = stepsForDay

        // 7-Tage-Ø Steps relativ zum gewählten Tag
        stepsSevenDayAverage = computeSevenDayAverageSteps(
            allSteps: allSteps,
            endingOn: date,
            calendar: calendar
        )

        // Distanz aus Steps ableiten
        updateDistanceForSelectedDay()                                 // !!! NEW

        // 7-Tage-Mini-Trend relativ zum gewählten Tag
        lastSevenDaysSteps = buildLastSevenDaysSteps(
            allSteps: allSteps,
            endingOn: date,
            calendar: calendar
        )

        // ============================================================
        // 2) EXERCISE & ACTIVE ENERGY (CACHE-ONLY via HealthStore helpers)
        // ============================================================

        let exerciseForDay = (selectedDayOffset == 0)
            ? healthStore.todayExerciseMinutes
            : healthStore.exerciseMinutes(for: date)

        let activeEnergyForDay = (selectedDayOffset == 0)
            ? healthStore.todayActiveEnergy
            : healthStore.activeEnergyKcal(for: date)

        todayExerciseMinutes = exerciseForDay
        todayActiveEnergyKcal = activeEnergyForDay

        // ✅ FAST: 7-day averages from cache (no HealthKit query)
        sevenDayAverageExerciseMinutes = healthStore.sevenDayAverageExerciseMinutesFromCache(endingOn: date)
        sevenDayAverageActiveEnergyKcal = healthStore.sevenDayAverageActiveEnergyKcalFromCache(endingOn: date)

        // ============================================================
        // 3) Movement Split für gewählten Tag
        // ============================================================

        updateMovementSplitForSelectedDay()                             // !!! NEW

        // ============================================================
        // 4) Insight & Score
        // ============================================================

        updateActivityInsight()
    }

    // MARK: - Steps-Hilfen (für beliebiges Datum)                     // !!! NEW

    /// 7-Tage-Ø Steps relativ zu einem Datum (inkl. dieses Tages).
    private func computeSevenDayAverageSteps(
        allSteps: [DailyStepsEntry],
        endingOn endDate: Date,
        calendar: Calendar
    ) -> Int {
        let endDay = calendar.startOfDay(for: endDate)
        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else {
            return 0
        }

        let window = allSteps.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= startDay && day <= endDay
        }

        guard !window.isEmpty else { return 0 }

        let sum = window.reduce(0) { $0 + $1.steps }
        return sum / window.count
    }

    /// Baut 7 Einträge (endingOn endDate) für den Mini-Trend.
    private func buildLastSevenDaysSteps(
        allSteps: [DailyStepsEntry],
        endingOn endDate: Date,
        calendar: Calendar
    ) -> [DailyStepsEntry] {
        let endDay = calendar.startOfDay(for: endDate)

        var result: [DailyStepsEntry] = []
        // sieben Tage: endDay - 6 ... endDay
        for offset in (0..<7).reversed() {            // −6 ... 0
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                continue
            }

            let steps = allSteps.first(where: {
                calendar.isDate($0.date, inSameDayAs: date)
            })?.steps ?? 0

            result.append(DailyStepsEntry(date: date, steps: steps))
        }
        return result
    }

    /// Distanz HEUTE (für den gewählten Tag, basierend auf todaySteps).
    private func updateDistanceForSelectedDay() {
        let kmPerStep: Double = 0.0008    // ~0,8 m pro Schritt
        distanceTodayKm = Double(todaySteps) * kmPerStep

        // Distance-7d-Ø aus stepsSevenDayAverage ableiten
        distanceSevenDayAverageKm = Double(stepsSevenDayAverage) * kmPerStep
    }

    /// Hilfsfunktion für Live-Update Today (wenn selectedDayOffset == 0)
    private func updateStepsAggregatesForSelectedDay() {               // !!! NEW
        let calendar = Calendar.current
        let all = stepsViewModel.dailySteps365
        let date = selectedDate
        stepsSevenDayAverage = computeSevenDayAverageSteps(
            allSteps: all,
            endingOn: date,
            calendar: calendar
        )
        lastSevenDaysSteps = buildLastSevenDaysSteps(
            allSteps: all,
            endingOn: date,
            calendar: calendar
        )
        updateDistanceForSelectedDay()
    }

    // MARK: - Last Exercises Mapping

    @MainActor
    private func loadLastExercises() async {
        // echte Workouts aus HealthStore holen
        let workouts = await healthStore.fetchRecentWorkouts(limit: 3)

        // erstes Workout für Insight/ScoreEngine merken
        lastWorkoutForInsight = workouts.first

        let calendar = Calendar.current

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let mapped: [(name: String, detail: String, date: String, time: String)] = workouts.map { workout in

            // Name aus Workout-Typ, einfach gehalten
            let name = workout.workoutActivityType.simpleName

            // Dauer in Minuten
            let durationMinutes = Int(workout.duration / 60)
            let durationText = "\(durationMinutes) min"

            // Distanz (optional, wenn vorhanden)
            var distanceText: String? = nil
            if let distanceQuantity = workout.totalDistance {
                let meters = distanceQuantity.doubleValue(for: .meter())
                if meters >= 1000 {
                    let km = meters / 1000
                    distanceText = String(format: "%.1f km", km)
                } else if meters > 0 {
                    distanceText = "\(Int(meters)) m"
                }
            }

            // Active Energy (optional)
            var energyText: String? = nil
            if let energyQuantity = workout.totalEnergyBurned {
                let kcal = Int(energyQuantity.doubleValue(for: .kilocalorie()))
                energyText = "\(kcal) kcal"
            }

            // Detail-String zusammenbauen: "35 min · 5,2 km · 430 kcal"
            let detailParts = [durationText, distanceText, energyText].compactMap { $0 }
            let detail = detailParts.joined(separator: " · ")

            // Datum / Uhrzeit für rechte Spalte
            let start = workout.startDate

            let dateString: String
            if calendar.isDateInYesterday(start) {
                dateString = "Yesterday"
            } else {
                dateString = dateFormatter.string(from: start)
            }

            let timeString = timeFormatter.string(from: start)

            return (name: name, detail: detail, date: dateString, time: timeString)
        }

        self.lastExercisesDisplay = mapped

        // Insight & Score after workouts loaded
        updateActivityInsight()
    }

    // MARK: - Movement Split für ausgewählten Tag                     // !!! UPDATED / NEW

    /// Mapped MovementSplitViewModel.dailyMovementSplits
    /// auf das ausgewählte Datum (Today / Yesterday / DayBefore).
    private func updateMovementSplitForSelectedDay() {                 // !!! NEW
        let calendar = Calendar.current
        let now = Date()
        let selected = selectedDate
        let selectedStart = calendar.startOfDay(for: selected)

        // passenden Eintrag für den gewählten Tag finden
        guard let entry = movementSplitViewModel.dailyMovementSplits.first(where: {
            calendar.isDate($0.date, inSameDayAs: selectedStart)
        }) else {
            movementSleepMinutesToday = 0
            movementActiveMinutesToday = 0
            movementSedentaryMinutesToday = 0
            movementSplitFillFractionOfDay = 0
            movementSplitPercentages = (0, 0, 0)
            return
        }

        let totalSleep = entry.sleepMorningMinutes + entry.sleepEveningMinutes
        let totalActive = entry.activeMinutes

        if calendar.isDateInToday(selected) {
            // HEUTE → nur bis jetzt, wie bisherige Logik
            let minutesSinceMidnight = max(
                0,
                Int(now.timeIntervalSince(selectedStart) / 60.0)
            )

            let sedentaryMinutes = max(
                0,
                minutesSinceMidnight - totalSleep - totalActive
            )

            movementSleepMinutesToday = max(0, totalSleep)
            movementActiveMinutesToday = max(0, totalActive)
            movementSedentaryMinutesToday = sedentaryMinutes

            let elapsed = max(0, totalSleep + totalActive + sedentaryMinutes)
            let totalMinutesPerDay = 1440.0
            movementSplitFillFractionOfDay = min(
                1.0,
                Double(elapsed) / totalMinutesPerDay
            )

            if elapsed > 0 {
                let total = Double(elapsed)
                let sleepPct = Double(movementSleepMinutesToday) / total
                let movePct = Double(movementActiveMinutesToday) / total
                let sedPct = Double(movementSedentaryMinutesToday) / total
                movementSplitPercentages = (sleepPct, movePct, sedPct)
            } else {
                movementSplitPercentages = (0, 0, 0)
            }
        } else {
            // GESTERN / VORGESTERN → kompletter Tag, 24h-Fenster
            let sedentaryMinutes = max(
                0,
                1440 - totalSleep - totalActive
            )

            movementSleepMinutesToday = max(0, totalSleep)
            movementActiveMinutesToday = max(0, totalActive)
            movementSedentaryMinutesToday = sedentaryMinutes

            movementSplitFillFractionOfDay = 1.0

            let elapsed = max(0, totalSleep + totalActive + sedentaryMinutes)
            if elapsed > 0 {
                let total = Double(elapsed)
                let sleepPct = Double(movementSleepMinutesToday) / total
                let movePct = Double(movementActiveMinutesToday) / total
                let sedPct = Double(movementSedentaryMinutesToday) / total
                movementSplitPercentages = (sleepPct, movePct, sedPct)
            } else {
                movementSplitPercentages = (0, 0, 0)
            }
        }
    }
    
    // MARK: - Activity Insight Engine binding

    private func updateActivityInsight(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        // Last workout info, if available
        let lastWorkoutInfo: ActivityLastWorkoutInfo?

        if let workout = lastWorkoutForInsight {
            let durationMinutes = Int(workout.duration / 60)
            var distanceKm: Double? = nil
            if let distanceQuantity = workout.totalDistance {
                let meters = distanceQuantity.doubleValue(for: .meter())
                if meters > 0 {
                    distanceKm = meters / 1000.0
                }
            }

            var energyKcal: Int? = nil
            if let energyQuantity = workout.totalEnergyBurned {
                let kcal = Int(energyQuantity.doubleValue(for: .kilocalorie()))
                energyKcal = kcal
            }

            lastWorkoutInfo = ActivityLastWorkoutInfo(
                name: workout.workoutActivityType.simpleName,
                minutes: durationMinutes,
                distanceKm: distanceKm,
                energyKcal: energyKcal,
                startDate: workout.startDate
            )
        } else {
            lastWorkoutInfo = nil
        }

        let input = ActivityInsightInput(
            now: now,
            calendar: calendar,
            stepsToday: todaySteps,
            stepsGoal: stepsGoal,
            steps7DayAverage: stepsSevenDayAverage,
            distanceTodayKm: distanceTodayKm,
            distance7DayAverageKm: distanceSevenDayAverageKm,
            exerciseMinutesToday: todayExerciseMinutes,
            exerciseMinutes7DayAverage: sevenDayAverageExerciseMinutes,
            activeEnergyTodayKcal: todayActiveEnergyKcal,
            activeEnergy7DayAverageKcal: sevenDayAverageActiveEnergyKcal,
            sleepMinutesToday: movementSleepMinutesToday,
            activeMinutesTodayFromSplit: movementActiveMinutesToday,
            sedentaryMinutesToday: movementSedentaryMinutesToday,
            lastWorkout: lastWorkoutInfo
        )

        let output = ActivityInsightEngine.generateInsight(from: input)

        activityInsightText = output.primaryText
        activityInsightCategory = output.category

        // Score should always follow den gleichen Zustand
        updateActivityScore(now: now, calendar: calendar)
    }

    // MARK: - Activity Score Engine binding

    private func updateActivityScore(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let lastWorkoutInfo: ActivityLastWorkoutInfo?

        if let workout = lastWorkoutForInsight {
            let durationMinutes = Int(workout.duration / 60)
            var distanceKm: Double? = nil
            if let distanceQuantity = workout.totalDistance {
                let meters = distanceQuantity.doubleValue(for: .meter())
                if meters > 0 {
                    distanceKm = meters / 1000.0
                }
            }

            var energyKcal: Int? = nil
            if let energyQuantity = workout.totalEnergyBurned {
                let kcal = Int(energyQuantity.doubleValue(for: .kilocalorie()))
                energyKcal = kcal
            }

            lastWorkoutInfo = ActivityLastWorkoutInfo(
                name: workout.workoutActivityType.simpleName,
                minutes: durationMinutes,
                distanceKm: distanceKm,
                energyKcal: energyKcal,
                startDate: workout.startDate
            )
        } else {
            lastWorkoutInfo = nil
        }

        let scoreInput = ActivityScoreInput(
            now: now,
            calendar: calendar,
            stepsToday: todaySteps,
            stepsGoal: stepsGoal,
            steps7DayAverage: stepsSevenDayAverage,
            exerciseMinutesToday: todayExerciseMinutes,
            exerciseMinutes7DayAverage: sevenDayAverageExerciseMinutes,
            activeEnergyTodayKcal: todayActiveEnergyKcal,
            activeEnergy7DayAverageKcal: sevenDayAverageActiveEnergyKcal,
            sleepMinutesToday: movementSleepMinutesToday,
            activeMinutesTodayFromSplit: movementActiveMinutesToday,
            sedentaryMinutesToday: movementSedentaryMinutesToday,
            lastWorkout: lastWorkoutInfo
        )

        let score = activityScoreEngine.makeScore(from: scoreInput)
        activityScore = score
    }

    // MARK: - Public API

    /// Wird von ActivityOverviewView in `.task {}` und `.refreshable {}` benutzt.
    @MainActor
    func refresh() async {
        // Basisdaten (History) aus den Child-VMs nachladen
        Task { @MainActor in
            await healthStore.refreshActivity(.pullToRefresh)
        }
        exerciseViewModel.refresh()
        activeEnergyViewModel.refresh()
        movementSplitViewModel.refresh()
        await loadLastExercises()

        // Danach die passenden Werte für den aktuell
        // ausgewählten Tag in die Overview-Outputs mappen.
        await refreshForSelectedDay()
    }
}

// MARK: - HKWorkoutActivityType → einfacher Anzeigename

private extension HKWorkoutActivityType {
    var simpleName: String {
        switch self {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .functionalStrengthTraining:
            return "Functional Training"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .yoga:
            return "Yoga"
        case .pilates:
            return "Pilates"
        case .coreTraining:
            return "Core Training"
        case .elliptical:
            return "Elliptical"
        case .swimming:
            return "Swimming"
        case .rowing:
            return "Rowing"
        case .hiking:
            return "Hiking"
        case .dance:
            return "Dance"
        case .martialArts:
            return "Martial Arts"
        default:
            return "Workout"
        }
    }
}
