//
//  ActivityOverviewViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import HealthKit

@MainActor
final class ActivityOverviewViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Dependencies (SSoT)
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Engines / Internal Helpers
    // ============================================================

    private let activityScoreEngine = ActivityScoreEngine()
    private var lastWorkoutForInsight: HKWorkout? = nil

    // ============================================================
    // MARK: - Remap Coalescing
    // ============================================================

    private var remapTask: Task<Void, Never>? = nil
    private var remapToken: Int = 0

    // ============================================================
    // MARK: - Today Monotone Cache (Steps dürfen intraday nicht sinken)
    // ============================================================

    private var lastStepsAnchorDay: Date = Calendar.current.startOfDay(for: Date())
    private var lastKnownGoodTodaySteps: Int = 0

    // ============================================================
    // MARK: - Day Selection (Pager)
    // ============================================================

    /// 0 = Today, -1 = Yesterday, -2 = DayBeforeYesterday
    @Published var selectedDayOffset: Int = 0

    var selectedDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: selectedDayOffset, to: today) ?? today
    }

    // ============================================================
    // MARK: - Published Output (für ActivityOverviewViewV1)
    // ============================================================

    @Published var todaySteps: Int = 0
    @Published var stepsGoal: Int = 0
    @Published var stepsSevenDayAverage: Int = 0
    @Published var distanceTodayKm: Double = 0
    @Published var distanceSevenDayAverageKm: Double = 0
    @Published var lastSevenDaysSteps: [DailyStepsEntry] = []

    @Published var todayWorkoutMinutes: Int = 0
    @Published var sevenDayAverageWorkoutMinutes: Int = 0

    @Published var todayExerciseMinutes: Int = 0
    @Published var sevenDayAverageExerciseMinutes: Int = 0

    @Published var todayActiveEnergyKcal: Int = 0
    @Published var sevenDayAverageActiveEnergyKcal: Int = 0

    @Published var movementSleepMinutesToday: Int = 0
    @Published var movementActiveMinutesToday: Int = 0
    @Published var movementSedentaryMinutesToday: Int = 0
    @Published var movementSplitFillFractionOfDay: Double = 0
    @Published var movementSplitPercentages: (sleep: Double, move: Double, sedentary: Double) = (0, 0, 0)

    @Published var lastExercisesDisplay: [(name: String, badgeName: String, detail: String, date: String, time: String)] = [] // UPDATED

    @Published var activityInsightText: String = ""
    @Published var activityInsightCategory: ActivityInsightCategory = .neutral

    @Published var activityScore: Int = 0

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bindStores()
        syncInitialState()
    }

    // ============================================================
    // MARK: - Bindings
    // ============================================================

    private func bindStores() {

        healthStore.$todaySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$stepsDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayWorkoutMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$workoutMinutesDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$activeTimeDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayActiveEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$last90DaysActiveEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$movementSplitDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todayMoveMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        healthStore.$todaySleepSplitMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.selectedDayOffset == 0 else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        settings.$dailyStepGoal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleRemap()
            }
            .store(in: &cancellables)

        settings.$distanceUnit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadLastExercises()
                    self.scheduleRemap()
                }
            }
            .store(in: &cancellables)
    }

    // ============================================================
    // MARK: - Remap Scheduling
    // ============================================================

    private func scheduleRemap() {
        remapToken += 1
        let token = remapToken

        remapTask?.cancel()
        remapTask = Task { @MainActor in
            await Task.yield()
            guard token == self.remapToken else { return }
            self.refreshForSelectedDay()
        }
    }

    // ============================================================
    // MARK: - Initial Sync
    // ============================================================

    private func syncInitialState() {

        selectedDayOffset = 0

        let todayAnchor = Calendar.current.startOfDay(for: Date())
        lastStepsAnchorDay = todayAnchor
        lastKnownGoodTodaySteps = max(0, healthStore.todaySteps)

        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Day Selection API (Pager)
    // ============================================================

    func applySelectedDayOffset(_ offset: Int) async {
        selectedDayOffset = offset
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Public API (Overview Refresh)
    // ============================================================

    func refresh() async {
        guard selectedDayOffset == 0 else { return }

        await healthStore.refreshActivity(.pullToRefresh)
        await loadLastExercises()

        refreshForSelectedDay()
    }

    func refreshOnNavigation() async {
        guard selectedDayOffset == 0 else {
            await loadLastExercises()
            refreshForSelectedDay()
            return
        }

        await healthStore.refreshActivity(.navigation)
        await loadLastExercises()
        refreshForSelectedDay()
    }

    // ============================================================
    // MARK: - Core Mapping for selected day
    // ============================================================

    private func refreshForSelectedDay() {

        let date = selectedDate
        let calendar = Calendar.current

        stepsGoal = settings.dailyStepGoal

        let todayAnchor = calendar.startOfDay(for: Date())
        if todayAnchor != lastStepsAnchorDay {
            lastStepsAnchorDay = todayAnchor
            lastKnownGoodTodaySteps = 0
        }

        let allSteps = healthStore.stepsDaily365

        if selectedDayOffset == 0 {
            let live = max(0, healthStore.todaySteps)
            lastKnownGoodTodaySteps = max(lastKnownGoodTodaySteps, live)
            todaySteps = lastKnownGoodTodaySteps
        } else {
            let cached = allSteps.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.steps ?? 0
            todaySteps = max(0, cached)
        }

        updateStepsAggregatesForSelectedDay()

        let wmSeries = healthStore.workoutMinutesDaily365
        if selectedDayOffset == 0 {
            todayWorkoutMinutes = max(0, healthStore.todayWorkoutMinutes)
        } else {
            todayWorkoutMinutes = max(0, valueForDay(
                from: wmSeries,
                date: date,
                dateKey: \.date,
                value: { $0.minutes },
                calendar: calendar
            ))
        }

        sevenDayAverageWorkoutMinutes = computeSevenDayAverageFixed7(
            values: wmSeries,
            endingOn: date,
            calendar: calendar,
            dateKey: \.date,
            value: { $0.minutes }
        )

        let exSeries = healthStore.activeTimeDaily365
        todayExerciseMinutes = max(0, valueForDay(
            from: exSeries,
            date: date,
            dateKey: \.date,
            value: { $0.minutes },
            calendar: calendar
        ))

        sevenDayAverageExerciseMinutes = computeSevenDayAverageFixed7(
            values: exSeries,
            endingOn: date,
            calendar: calendar,
            dateKey: \.date,
            value: { $0.minutes }
        )

        todayActiveEnergyKcal = (selectedDayOffset == 0)
            ? max(0, healthStore.todayActiveEnergy)
            : max(0, valueForDay(from: healthStore.last90DaysActiveEnergy, date: date, dateKey: \.date, value: { $0.activeEnergy }))

        sevenDayAverageActiveEnergyKcal = computeSevenDayAverageFixed7(
            values: healthStore.last90DaysActiveEnergy,
            endingOn: date,
            calendar: calendar,
            dateKey: \.date,
            value: { $0.activeEnergy }
        )

        updateMovementSplitForSelectedDay()

        let scoreNow = scoreReferenceNow(for: date, calendar: calendar)

        if selectedDayOffset == 0 {
            updateActivityInsight(now: scoreNow, calendar: calendar)
        } else {
            activityInsightText = ""
            activityInsightCategory = .neutral
        }

        updateActivityScore(now: scoreNow, calendar: calendar)
    }

    // ============================================================
    // MARK: - Local Aggregates (Steps)
    // ============================================================

    private func updateStepsAggregatesForSelectedDay() {

        let calendar = Calendar.current

        // 🟨 UPDATED (Rule A):
        // Mini-trend ALWAYS shows the last 7 FULL days BEFORE the displayed day.
        // Therefore: endDay = selectedDate - 1 day (for ALL offsets).
        let endDate: Date = {
            let selectedStart = calendar.startOfDay(for: selectedDate)
            return calendar.date(byAdding: .day, value: -1, to: selectedStart) ?? selectedStart
        }()

        let dict = buildStepsDictionary(healthStore.stepsDaily365, calendar: calendar)

        stepsSevenDayAverage = computeSevenDayAverageStepsFromDict(
            dict: dict,
            endingOn: endDate,
            calendar: calendar
        )

        lastSevenDaysSteps = buildLastSevenDaysStepsFromDict(
            dict: dict,
            endingOn: endDate,
            calendar: calendar
        )

        updateDistanceForSelectedDay()
    }

    // ============================================================
    // MARK: - Steps (FAST, dict-based)
    // ============================================================

    private func buildStepsDictionary(
        _ allSteps: [DailyStepsEntry],
        calendar: Calendar
    ) -> [Date: Int] {
        var dict: [Date: Int] = [:]
        dict.reserveCapacity(allSteps.count)

        for entry in allSteps {
            let day = calendar.startOfDay(for: entry.date)
            dict[day] = max(dict[day] ?? 0, entry.steps)
        }
        return dict
    }

    private func computeSevenDayAverageStepsFromDict(
        dict: [Date: Int],
        endingOn endDate: Date,
        calendar: Calendar
    ) -> Int {
        let endDay = calendar.startOfDay(for: endDate)
        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else { return 0 }

        var sum = 0
        var count = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            sum += max(0, dict[calendar.startOfDay(for: day)] ?? 0)
            count += 1
        }

        guard count > 0 else { return 0 }
        return sum / count
    }

    private func buildLastSevenDaysStepsFromDict(
        dict: [Date: Int],
        endingOn endDate: Date,
        calendar: Calendar
    ) -> [DailyStepsEntry] {

        let endDay = calendar.startOfDay(for: endDate)
        var result: [DailyStepsEntry] = []
        result.reserveCapacity(7)

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else { continue }
            let day = calendar.startOfDay(for: date)
            let steps = max(0, dict[day] ?? 0)
            result.append(DailyStepsEntry(date: day, steps: steps))
        }

        return result
    }

    private func updateDistanceForSelectedDay() {
        let kmPerStep: Double = 0.0008
        distanceTodayKm = Double(todaySteps) * kmPerStep
        distanceSevenDayAverageKm = Double(stepsSevenDayAverage) * kmPerStep
    }

    // ============================================================
    // MARK: - Generic helpers
    // ============================================================

    private func valueForDay<T>(
        from values: [T],
        date: Date,
        dateKey: KeyPath<T, Date>,
        value: (T) -> Int,
        calendar: Calendar = .current
    ) -> Int {
        values.first(where: { calendar.isDate($0[keyPath: dateKey], inSameDayAs: date) })
            .map(value) ?? 0
    }

    private func computeSevenDayAverageFixed7<T>(
        values: [T],
        endingOn endDate: Date,
        calendar: Calendar,
        dateKey: KeyPath<T, Date>,
        value: (T) -> Int
    ) -> Int {

        let endDay = calendar.startOfDay(for: endDate)
        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else { return 0 }

        var dict: [Date: Int] = [:]
        dict.reserveCapacity(values.count)

        for item in values {
            let day = calendar.startOfDay(for: item[keyPath: dateKey])
            dict[day] = max(dict[day] ?? 0, value(item))
        }

        var sum = 0
        var count = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            sum += max(0, dict[calendar.startOfDay(for: day)] ?? 0)
            count += 1
        }

        guard count > 0 else { return 0 }
        return Int((Double(sum) / Double(count)).rounded())
    }

    // ============================================================
    // MARK: - Movement Split mapping (unverändert)
    // ============================================================

    private func updateMovementSplitForSelectedDay() {
        let calendar = Calendar.current
        let now = Date()
        let selected = selectedDate
        let selectedStart = calendar.startOfDay(for: selected)

        if calendar.isDateInToday(selected) {

            let sleep = max(0, healthStore.todaySleepSplitMinutes)
            let move  = max(0, healthStore.todayMoveMinutes)

            let minutesSinceMidnight = max(0, Int(now.timeIntervalSince(selectedStart) / 60.0))
            let elapsed = min(1440, minutesSinceMidnight)

            let sedentary = max(0, elapsed - sleep - move)

            movementSleepMinutesToday = sleep
            movementActiveMinutesToday = move
            movementSedentaryMinutesToday = sedentary

            movementSplitFillFractionOfDay = min(1.0, Double(elapsed) / 1440.0)

            let used = max(0, sleep + move + sedentary)
            if used > 0 {
                let total = Double(used)
                movementSplitPercentages = (
                    Double(sleep) / total,
                    Double(move) / total,
                    Double(sedentary) / total
                )
            } else {
                movementSplitPercentages = (0, 0, 0)
            }
            return
        }

        guard let entry = healthStore.movementSplitDaily365.first(where: {
            calendar.isDate($0.date, inSameDayAs: selectedStart)
        }) else {
            movementSleepMinutesToday = 0
            movementActiveMinutesToday = 0
            movementSedentaryMinutesToday = 0
            movementSplitFillFractionOfDay = 1.0
            movementSplitPercentages = (0, 0, 0)
            return
        }

        let totalSleep = max(0, entry.sleepMorningMinutes + entry.sleepEveningMinutes)
        let totalActive = max(0, entry.activeMinutes)
        let totalSedentary = max(0, 1440 - totalSleep - totalActive)

        movementSleepMinutesToday = totalSleep
        movementActiveMinutesToday = totalActive
        movementSedentaryMinutesToday = totalSedentary

        movementSplitFillFractionOfDay = 1.0

        let used = max(0, totalSleep + totalActive + totalSedentary)
        if used > 0 {
            let total = Double(used)
            movementSplitPercentages = (
                Double(totalSleep) / total,
                Double(totalActive) / total,
                Double(totalSedentary) / total
            )
        } else {
            movementSplitPercentages = (0, 0, 0)
        }
    }

    // ============================================================
    // MARK: - Workouts / Insight / Score (unverändert)
    // ============================================================

    private func scoreReferenceNow(for selectedDate: Date, calendar: Calendar) -> Date {
        if calendar.isDateInToday(selectedDate) { return Date() }
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            .map { $0.addingTimeInterval(-1) }
            ?? start
        return end
    }

    private func loadLastExercises() async {
        let workouts = await healthStore.fetchRecentWorkouts(limit: 200)
        lastWorkoutForInsight = workouts.first

        let calendar = Calendar.current

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let mapped: [(name: String, badgeName: String, detail: String, date: String, time: String)] = workouts.map { workout in // UPDATED

            let name = workout.workoutActivityType.simpleName
            let badgeName = workout.workoutActivityType.badgeName // UPDATED

            let durationMinutes = Int(workout.duration / 60)
            let durationText = "\(durationMinutes) min"

            var distanceText: String? = nil
            if let distanceQuantity = workout.totalDistance {
                let meters = distanceQuantity.doubleValue(for: .meter())
                let km = max(0, meters / 1000.0)
                distanceText = settings.distanceUnit.formatted(fromKm: km, fractionDigits: 1)
            }

            var energyText: String? = nil
            if let energyQuantity = workout.totalEnergyBurned {
                let kcal = Int(energyQuantity.doubleValue(for: .kilocalorie()))
                energyText = "\(kcal) kcal"
            }

            let detailParts = [durationText, distanceText, energyText].compactMap { $0 }
            let detail = detailParts.joined(separator: " · ")

            let start = workout.startDate

            let dateString: String
            if calendar.isDateInToday(start) {
                dateString = L10n.ActivityOverview.today
            } else if calendar.isDateInYesterday(start) {
                dateString = L10n.ActivityOverview.yesterday
            } else {
                dateString = dateFormatter.string(from: start)
            }

            let timeString = timeFormatter.string(from: start)

            return (name: name, badgeName: badgeName, detail: detail, date: dateString, time: timeString) // UPDATED
        }

        lastExercisesDisplay = mapped
        updateActivityInsight()
    }

    private func updateActivityInsight(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard selectedDayOffset == 0 else {
            activityInsightText = ""
            activityInsightCategory = .neutral
            return
        }

        // (rest unchanged)
        let lastWorkoutInfo: ActivityLastWorkoutInfo? = {
            guard let workout = lastWorkoutForInsight else { return nil }
            guard workout.startDate <= now else { return nil }

            let durationMinutes = Int(workout.duration / 60)

            var distanceKm: Double? = nil
            if let distanceQuantity = workout.totalDistance {
                let meters = distanceQuantity.doubleValue(for: .meter())
                if meters > 0 { distanceKm = meters / 1000.0 }
            }

            var energyKcal: Int? = nil
            if let energyQuantity = workout.totalEnergyBurned {
                let kcal = Int(energyQuantity.doubleValue(for: .kilocalorie()))
                energyKcal = kcal
            }

            return ActivityLastWorkoutInfo(
                name: workout.workoutActivityType.simpleName,
                minutes: durationMinutes,
                distanceKm: distanceKm,
                energyKcal: energyKcal,
                startDate: workout.startDate
            )
        }()

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
    }

    private func updateActivityScore(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        // unchanged
        let lastWorkoutInfo: ActivityLastWorkoutInfo?

        if let workout = lastWorkoutForInsight {
            if workout.startDate > now {
                lastWorkoutInfo = nil
            } else {
                let durationMinutes = Int(workout.duration / 60)

                var distanceKm: Double? = nil
                if let distanceQuantity = workout.totalDistance {
                    let meters = distanceQuantity.doubleValue(for: .meter())
                    if meters > 0 { distanceKm = meters / 1000.0 }
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
            }
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

        activityScore = activityScoreEngine.makeScore(from: scoreInput)
    }
}

private extension HKWorkoutActivityType {
    var simpleName: String {
        switch self {
        case .walking: return L10n.ActivityOverview.workoutTypeWalking // UPDATED
        case .running: return L10n.ActivityOverview.workoutTypeRunning
        case .cycling: return L10n.ActivityOverview.workoutTypeCycling
        case .highIntensityIntervalTraining: return L10n.ActivityOverview.workoutTypeHIIT
        case .functionalStrengthTraining: return L10n.ActivityOverview.workoutTypeFunctionalTraining
        case .traditionalStrengthTraining: return L10n.ActivityOverview.workoutTypeStrengthTraining
        case .yoga: return L10n.ActivityOverview.workoutTypeYoga
        case .pilates: return L10n.ActivityOverview.workoutTypePilates
        case .coreTraining: return L10n.ActivityOverview.workoutTypeCoreTraining
        case .elliptical: return L10n.ActivityOverview.workoutTypeElliptical
        case .swimming: return L10n.ActivityOverview.workoutTypeSwimming
        case .rowing: return L10n.ActivityOverview.workoutTypeRowing
        case .hiking: return L10n.ActivityOverview.workoutTypeHiking
        case .dance: return L10n.ActivityOverview.workoutTypeDance
        case .martialArts: return L10n.ActivityOverview.workoutTypeMartialArts
        default: return L10n.ActivityOverview.workoutTypeGeneric
        }
    }

    var badgeName: String { // UPDATED
        switch self {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .highIntensityIntervalTraining: return "HIIT"
        case .functionalStrengthTraining: return "Functional Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .coreTraining: return "Core Training"
        case .elliptical: return "Elliptical"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .martialArts: return "Martial Arts"
        default: return "Workout"
        }
    }
}
