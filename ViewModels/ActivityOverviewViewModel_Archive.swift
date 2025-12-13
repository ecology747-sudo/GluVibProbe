//
//  ActivityOverviewViewModel.swift
//  GluVibProbe
//
//  Aggregiert Steps / Exercise Minutes / Activity Energy / Movement Split
//  für die ActivityOverviewView.
//

import Foundation
import Combine
import HealthKit                                  // !!! NEW: für HKWorkout / HKWorkoutActivityType

final class ActivityOverviewViewModel: ObservableObject {

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private let stepsViewModel: StepsViewModel
    private let exerciseViewModel: ExerciseMinutesViewModel
    private let activeEnergyViewModel: ActivityEnergyViewModel
    private let movementSplitViewModel: MovementSplitViewModel      // !!! NEW
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Insight & Score Engines                               // !!! NEW
    private let activityScoreEngine = ActivityScoreEngine()         // !!! NEW
    
    // MARK: - Intern: Letztes Workout für Insight/ScoreEngine       // !!! NEW
    private var lastWorkoutForInsight: HKWorkout? = nil             // !!! NEW

    // MARK: - Last Exercise Display
    @Published var lastExercisesDisplay: [(name: String, detail: String, date: String, time: String)] = []
    
    // MARK: - Insight output for the card

    @Published var activityInsightText: String = ""       // !!! NEW
    @Published var activityInsightCategory: ActivityInsightCategory = .neutral // !!! NEW

    // MARK: - Activity Score (Overview header)

    @Published var activityScore: Int = 0                 // !!! NEW
    
    // MARK: - Published Output (für ActivityOverviewView)

    // Steps-Kachel
    @Published var todaySteps: Int = 0
    @Published var stepsGoal: Int = 0
    @Published var stepsSevenDayAverage: Int = 0

    @Published var distanceTodayKm: Double = 0
    @Published var distanceSevenDayAverageKm: Double = 0

    /// Mini-Trend für die letzten 7 Kalendertage (inkl. heute)
    @Published var lastSevenDaysSteps: [DailyStepsEntry] = []

    // Exercise-Kachel
    @Published var todayExerciseMinutes: Int = 0
    @Published var sevenDayAverageExerciseMinutes: Int = 0

    // Active-Energy-Kachel
    @Published var todayActiveEnergyKcal: Int = 0
    @Published var sevenDayAverageActiveEnergyKcal: Int = 0

    // Movement-Split-Today (24h-Balken)
    @Published var movementSleepMinutesToday: Int = 0
    @Published var movementActiveMinutesToday: Int = 0
    @Published var movementSedentaryMinutesToday: Int = 0

    /// Anteil des Tages, der bereits vergangen ist (0.0–1.0)
    @Published var movementSplitFillFractionOfDay: Double = 0

    /// Prozent-Anteile der bisher vergangenen Tageszeit
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
        self.stepsViewModel = StepsViewModel(
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
                self.todaySteps = value
                self.updateDistanceToday()
                self.updateLastSevenDaysSteps()
                self.updateActivityInsight()               // !!! NEW (Insight + Score)
            }
            .store(in: &cancellables)

        stepsViewModel.$dailyStepsGoalInt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.stepsGoal = value
                self?.updateActivityInsight()              // !!! NEW
            }
            .store(in: &cancellables)

        stepsViewModel.$dailySteps365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStepsAggregates()
                self?.updateActivityInsight()              // !!! NEW
            }
            .store(in: &cancellables)

        // 🟩 EXERCISE MINUTES
        exerciseViewModel.$todayExerciseMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.todayExerciseMinutes = value
                self?.updateActivityInsight()              // !!! NEW
            }
            .store(in: &cancellables)

        exerciseViewModel.$dailyExerciseMinutes365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.sevenDayAverageExerciseMinutes =
                    self.exerciseViewModel.sevenDayAverageExerciseMinutes
                self.updateActivityInsight()               // !!! NEW
            }
            .store(in: &cancellables)

        // 🔥 ACTIVE ENERGY (Basis: kcal)
        activeEnergyViewModel.$dailyActiveEnergy365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.todayActiveEnergyKcal =
                    self.activeEnergyViewModel.todayActiveEnergyKcal
                self.sevenDayAverageActiveEnergyKcal =
                    self.activeEnergyViewModel.sevenDayAverageActiveEnergyKcal
                self.updateActivityInsight()               // !!! NEW
            }
            .store(in: &cancellables)

        // 🟣 MOVEMENT SPLIT (Sleep / Active / Sedentary)
        movementSplitViewModel.$dailyMovementSplits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMovementSplitToday()
                self?.updateActivityInsight()              // !!! NEW
            }
            .store(in: &cancellables)
    }

    // MARK: - Last Exercises Mapping

    @MainActor
    private func loadLastExercises() async {
        // echte Workouts aus HealthStore holen
        let workouts = await healthStore.fetchRecentWorkouts(limit: 3)

        // erstes Workout für Insight/ScoreEngine merken
        lastWorkoutForInsight = workouts.first              // !!! NEW

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
        updateActivityInsight()                                      // !!! NEW
    }

    // MARK: - Aggregations-Updates

    /// Wird aufgerufen, wenn dailySteps365 aktualisiert wurde.
    private func updateStepsAggregates() {
        // 7-Tage-Durchschnitt direkt aus StepsViewModel
        stepsSevenDayAverage = stepsViewModel.avgStepsLast7Days

        updateDistanceSevenDayAverage()
        updateLastSevenDaysSteps()
    }

    /// Distanz HEUTE (km) – einfacher Approx. aus Steps.
    private func updateDistanceToday() {
        let kmPerStep: Double = 0.0008    // ~0,8 m pro Schritt
        distanceTodayKm = Double(todaySteps) * kmPerStep
    }

    /// Distanz 7-Tage-Durchschnitt (km) – gleicher Faktor.
    private func updateDistanceSevenDayAverage() {
        let kmPerStep: Double = 0.0008
        distanceSevenDayAverageKm = Double(stepsSevenDayAverage) * kmPerStep
    }

    /// Baut ein 7-Tage-Array für den Mini-Trend (inkl. heute).
    private func updateLastSevenDaysSteps() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let all = stepsViewModel.dailySteps365

        var result: [DailyStepsEntry] = []

        // letzte 7 Kalendertage: heute, gestern, ...
        for offset in (0..<7).reversed() {           // −6 ... 0
            guard let date = calendar.date(
                byAdding: .day,
                value: -offset,
                to: today
            ) else { continue }

            let steps = all.first(where: {
                calendar.isDate($0.date, inSameDayAs: date)
            })?.steps ?? 0

            result.append(DailyStepsEntry(date: date, steps: steps))
        }

        lastSevenDaysSteps = result
    }

    /// Movement Split HEUTE: Sleep / Active / Sedentary
    /// - nutzt die täglichen Einträge aus MovementSplitViewModel
    /// - berücksichtigt nur die Zeit bis jetzt (Fill-Fraction des Tages)
    private func updateMovementSplitToday() {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // passenden Eintrag für heute finden
        guard let entry = movementSplitViewModel.dailyMovementSplits.first(where: {
            calendar.isDate($0.date, inSameDayAs: todayStart)
        }) else {
            movementSleepMinutesToday = 0
            movementActiveMinutesToday = 0
            movementSedentaryMinutesToday = 0
            movementSplitFillFractionOfDay = 0
            movementSplitPercentages = (0, 0, 0)
            return
        }

        let minutesSinceMidnight = max(
            0,
            Int(now.timeIntervalSince(todayStart) / 60.0)
        )

        // Sleep & Active kommen direkt aus den Tageswerten (HealthKit fragt nur bis jetzt)
        let sleepMinutes = entry.sleepMorningMinutes + entry.sleepEveningMinutes
        let activeMinutes = entry.activeMinutes

        // Sedentary = "Zeit seit 0:00" − Sleep − Active
        let sedentaryMinutes = max(
            0,
            minutesSinceMidnight - sleepMinutes - activeMinutes
        )

        movementSleepMinutesToday = max(0, sleepMinutes)
        movementActiveMinutesToday = max(0, activeMinutes)
        movementSedentaryMinutesToday = sedentaryMinutes

        // Anteil des Tages, der bereits vergangen ist (für 24h-Balken)
        let elapsed = max(0, sleepMinutes + activeMinutes + sedentaryMinutes)
        let totalMinutesPerDay = 1440.0
        movementSplitFillFractionOfDay = min(
            1.0,
            Double(elapsed) / totalMinutesPerDay
        )

        // Prozent-Anteile innerhalb der bereits vergangenen Zeit
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

        // Score should always follow the same updated state
        updateActivityScore(now: now, calendar: calendar)      // !!! NEW
    }

    // MARK: - Activity Score Engine binding                         // !!! NEW

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
        stepsViewModel.refresh()
        exerciseViewModel.refresh()
        activeEnergyViewModel.refresh()
        movementSplitViewModel.refresh()
        await loadLastExercises()
        updateActivityInsight()     // Insight + Score
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
