//
//  ActivityOverviewViewV1.swift
//  GluVibProbe
//
//  V1: Activity Overview
//  - Design + Pager bleiben wie aktuell
//  - Daten kommen aus ActivityOverviewViewModelV1 (SSoT: HealthStore)
//
//  ✅ FINAL GOAL (Exercise Time Card):
//  - Diese Kachel zeigt NUR Exercise Minutes (HK: appleExerciseTime).
//  - Quelle ist IMMER: viewModel.todayExerciseMinutes + viewModel.sevenDayAverageExerciseMinutes
//  - KEIN MoveTime / StandTime / MovementSplit als Quelle für diese Kachel.
//
//  ✅ UPDATED (Movement Split Hint):
//  - Hinweistext nur auf TODAY (selectedDayOffset == 0)
//  - Reihenfolge in der Card: Title → Horizontal Bar → Hint (optional) → Legend
//  - Hint basiert auf Active-Source (Stand vs Exercise vs Workout) wie MovementSplitViewModelV1
//

import SwiftUI
import Charts

// MARK: - Scroll Offset Preference (für Sticky-Header)

private struct ActivityScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ActivityOverviewViewV1: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - Settings (Units)                                         // !!! NEW
    @ObservedObject private var settings = SettingsModel.shared         // !!! NEW

    // MARK: - ViewModel

    @StateObject private var viewModel: ActivityOverviewViewModelV1

    // MARK: - Sticky Header

    @State private var hasScrolled: Bool = false

    // MARK: - Pager State

    /// 0 = DayBefore (-2), 1 = Yesterday (-1), 2 = Today (0)
    @State private var selectedPage: Int = 2
    @State private var didInitialLoad = false

    @State private var isProgrammaticPageUpdate = false

    // MARK: - Init

    init(viewModel: ActivityOverviewViewModelV1? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: ActivityOverviewViewModelV1(
                    healthStore: .shared,
                    settings: .shared
                )
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.activityDomain.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ZStack(alignment: .top) {

                TabView(selection: $selectedPage) {

                    dayScrollView
                        .tag(0)

                    dayScrollView
                        .tag(1)

                    dayScrollView
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onPreferenceChange(ActivityScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                .onChange(of: selectedPage) { newIndex in
                    guard !isProgrammaticPageUpdate else { return }
                    let newOffset = dayOffset(for: newIndex)
                    Task { @MainActor in
                        await viewModel.applySelectedDayOffset(newOffset)
                    }
                }
                .onAppear {
                    // ✅ Initiales Setzen der Page darf KEIN onChange-Remap auslösen
                    isProgrammaticPageUpdate = true
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)

                    // Nächster Runloop: ab dann sind Swipe-Changes "echt"
                    DispatchQueue.main.async {
                        isProgrammaticPageUpdate = false
                    }
                }

                OverviewHeader(
                    title: "Activity Overview",
                    subtitle: headerSubtitle,
                    tintColor: Color.Glu.activityDomain,
                    hasScrolled: hasScrolled
                )

                VStack {
                    Spacer()
                    PageDots(
                        selected: selectedPage,
                        total: 3,
                        color: Color.Glu.activityDomain
                    )
                    .padding(.bottom, 12)
                }
            }
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await viewModel.refreshOnNavigation()
        }
    }

    // MARK: - Header Subtitle

    private var headerSubtitle: String {
        switch viewModel.selectedDayOffset {
        case 0: return "TODAY"
        case -1: return "YESTERDAY"
        default: return dateString(for: viewModel.selectedDate)
        }
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func dayOffset(for pageIndex: Int) -> Int {
        switch pageIndex {
        case 0: return -2
        case 1: return -1
        default: return 0
        }
    }

    private func pageIndex(for offset: Int) -> Int {
        switch offset {
        case -2: return 0
        case -1: return 1
        default: return 2
        }
    }
}

// MARK: - Day ScrollView

private extension ActivityOverviewViewV1 {

    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {

                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ActivityScrollOffsetKey.self,
                            value: geo.frame(in: .global).minY
                        )
                }
                .frame(height: 0)

                // SCORE-BADGE
                HStack {
                    Spacer()
                    ActivityOverviewScoreBadge(score: viewModel.activityScore)
                }
                .padding(.horizontal, 16)

                // MAIN STEPS CARD
                ActivityOverviewStepsMainCard(
                    todaySteps: viewModel.todaySteps,
                    stepsGoal: viewModel.stepsGoal,
                    stepsAverage7d: viewModel.stepsSevenDayAverage,
                    distanceTodayKm: viewModel.distanceTodayKm,
                    distanceAverage7dKm: viewModel.distanceSevenDayAverageKm,
                    last7DaysSteps: viewModel.lastSevenDaysSteps,
                    distanceUnit: settings.distanceUnit,                         // !!! NEW
                    onTapSteps: {
                        appState.currentStatsScreen = .steps
                    }
                )
                .padding(.horizontal, 16)

                // WORKOUT TIME
                HStack(spacing: 12) {

                    // ✅ Exercise Time Card (HK: appleExerciseTime)
                    ActivityOverviewExerciseCard(
                        todayWorkoutMinutes: viewModel.todayWorkoutMinutes,
                        avgWorkoutMinutes7d: viewModel.sevenDayAverageWorkoutMinutes,
                        onTap: {
                            appState.currentStatsScreen = .activityExerciseMinutes
                        }
                    )

                    ActivityOverviewActiveEnergyCard(
                        todayKcal: viewModel.todayActiveEnergyKcal,
                        avgKcal7d: viewModel.sevenDayAverageActiveEnergyKcal,
                        onTap: {
                            appState.currentStatsScreen = .activityEnergy
                        }
                    )
                }
                .padding(.horizontal, 16)

                // MOVEMENT SPLIT
                movementSplitCard
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.currentStatsScreen = .movementSplit
                    }

                // LAST EXERCISE
                ActivityOverviewLastExerciseCard(
                    workouts: viewModel.lastExercisesDisplay
                )
                .padding(.horizontal, 16)

                // INSIGHT
                ActivityOverviewInsightCard(
                    insightText: viewModel.activityInsightText,
                    category: viewModel.activityInsightCategory,
                    selectedDayOffset: viewModel.selectedDayOffset
                )
                .padding(.horizontal, 16)
            }
            .padding(.top, 30)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Movement Split Card (24h-Balken)

private extension ActivityOverviewViewV1 {

    var movementSplitCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Movement split")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {

                // 1) Horizontal Bar
                GeometryReader { geo in
                    let width = geo.size.width
                    let totalFraction = viewModel.movementSplitFillFractionOfDay
                    let percentages = viewModel.movementSplitPercentages

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.Glu.bodyDomain)                         // Sleep
                            .frame(width: width * totalFraction * percentages.sleep)

                        Rectangle()
                            .fill(Color.Glu.activityDomain)                      // Active
                            .frame(width: width * totalFraction * percentages.move)

                        Rectangle()
                            .fill(Color.gray.opacity(0.35))                      // Rest (Sedentary)
                            .frame(width: width * totalFraction * percentages.sedentary)

                        Spacer(minLength: 0)                                     // Remaining day (background shows through)
                    }
                    .frame(height: 14)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.Glu.backgroundSurface)                  // ✅ Rest des Tages = Kartenhintergrund
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.Glu.primaryBlue.opacity(0.85), lineWidth: 1.0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .frame(height: 14)

                // 2) Hint (optional) — zwischen Bar und Legend
                if let hint = movementSplitHintText {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.80))

                        Text(hint)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }

                // 3) Legend
                HStack(alignment: .top, spacing: 5) {
                    movementLegendItem(
                        color: Color.Glu.bodyDomain,
                        title: "Sleep",
                        minutes: viewModel.movementSleepMinutesToday
                    )
                    movementLegendItem(
                        color: Color.Glu.activityDomain,
                        title: "Active",
                        minutes: viewModel.movementActiveMinutesToday
                    )
                    movementLegendItem(
                        color: Color.gray.opacity(0.65),
                        title: "Not Active",
                        minutes: viewModel.movementSedentaryMinutesToday
                    )
                }
            }
        }
        .padding(12)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
    }

    // ============================================================
    // MARK: - Hint Logic (Activity Overview only)
    // ============================================================

    private var movementSplitHintText: String? {
        // ✅ Only show on TODAY
        guard viewModel.selectedDayOffset == 0 else { return nil }

        // ✅ Quelle ist die echte Active-Source aus HealthStore (wie MovementSplitViewModelV1)
        switch healthStore.movementSplitActiveSourceTodayV1 {
        case .exerciseMinutes:
            return "Active time based on Exercise Minutes"
        case .workoutMinutes:
            return "Active time estimated from Workout Minutes"
        case .standTime, .none:
            return nil
        }
    }

    private func movementLegendItem(
        color: Color,
        title: String,
        minutes: Int
    ) -> some View {
        let hours = minutes / 60
        let mins = minutes % 60

        let timeText: String
        if hours > 0 && mins > 0 { timeText = "\(hours) h \(mins) min" }
        else if hours > 0 { timeText = "\(hours) h" }
        else { timeText = "\(mins) min" }

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)
            }

            Text("(\(timeText))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Score Badge

private struct ActivityOverviewScoreBadge: View {

    let score: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("Activity score")
                .font(.caption2.weight(.semibold))
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

            Text("\(score)")
                .font(.caption.weight(.bold))
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.Glu.activityDomain.opacity(0.9),
                                    Color.Glu.activityDomain.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .foregroundColor(.white)
        }
    }
}

// MARK: - MAIN STEPS CARD (Overview)

private struct ActivityOverviewStepsMainCard: View {

    let todaySteps: Int
    let stepsGoal: Int
    let stepsAverage7d: Int

    let distanceTodayKm: Double
    let distanceAverage7dKm: Double
    let last7DaysSteps: [DailyStepsEntry]

    let distanceUnit: DistanceUnit                                     // !!! NEW
    let onTapSteps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Label {
                    Text("Steps")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Color.Glu.activityDomain)
                }

                Spacer()

                Image(systemName: trendArrowSymbol())
                    .font(.title2.weight(.bold))
                    .foregroundColor(trendArrowColor())
                    .padding(.trailing, 2)
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(formattedSteps(todaySteps))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                HStack(spacing: 4) {
                    Spacer()
                    Text("Remaining")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(formattedSteps(max(stepsGoal - todaySteps, 0)))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                }

                GeometryReader { geo in
                    let width = geo.size.width
                    let goal = max(Double(stepsGoal), 1.0)
                    let clampedSteps = max(0.0, min(Double(todaySteps), goal))
                    let fraction = clampedSteps / goal

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.Glu.primaryBlue.opacity(0.06))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.Glu.activityDomain)
                            .frame(width: width * fraction)

                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.7)
                    }
                }
                .frame(height: 10)

                HStack(spacing: 4) {
                    Spacer()
                    Text("Target")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(formattedSteps(stepsGoal))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 6) {

                HStack(spacing: 6) {
                    Image(systemName: "ruler")
                        .foregroundColor(Color.Glu.bodyDomain)

                    Text("Distance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                }

                HStack {
                    Text("")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Spacer()

                    Text("7-day avg")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                }

                GeometryReader { geo in
                    let width = geo.size.width
                    let avg = max(distanceAverage7dKm, 0.1)
                    let fraction = min(max(distanceTodayKm / avg, 0), 1)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.Glu.primaryBlue.opacity(0.06))

                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.Glu.bodyDomain)
                            .frame(width: width * fraction)

                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(formattedDistance(distanceTodayKm))                   // !!! UPDATED
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))

                    Spacer()

                    Text(formattedDistance(distanceAverage7dKm))               // !!! UPDATED
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                }
            }

            let chartData = last7DaysSteps.isEmpty ? placeholderLastSevenDays() : last7DaysSteps

            ActivityOverviewStepsMiniTrendChart(data: chartData)
                .frame(height: 60)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        .contentShape(Rectangle())
        .onTapGesture { onTapSteps() }
    }

    private func placeholderLastSevenDays() -> [DailyStepsEntry] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: Date())

        var result: [DailyStepsEntry] = []
        result.reserveCapacity(7)

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else { continue }
            let day = calendar.startOfDay(for: date)
            result.append(DailyStepsEntry(date: day, steps: 0))
        }
        return result
    }

    private func formattedSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedDistance(_ km: Double) -> String {                   // !!! NEW
        distanceUnit.formatted(fromKm: km, fractionDigits: 1)                  // !!! NEW
    }

    private func trendArrowSymbol() -> String {
        guard last7DaysSteps.count >= 2 else { return "arrow.right" }

        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        let count = sorted.count
        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else { return "arrow.right" }

        let yesterdaySteps = sorted[yesterdayIndex].steps
        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else { return "arrow.right" }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)
        let diff = Double(yesterdaySteps) - avgPrev
        let threshold: Double = 1_000

        if diff > threshold { return "arrow.up.right" }
        if diff < -threshold { return "arrow.down.right" }
        return "arrow.right"
    }

    private func trendArrowColor() -> Color {
        guard last7DaysSteps.count >= 2 else { return Color.Glu.primaryBlue }

        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        let count = sorted.count
        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else { return Color.Glu.primaryBlue }

        let yesterdaySteps = sorted[yesterdayIndex].steps
        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else { return Color.Glu.primaryBlue }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)
        let diff = Double(yesterdaySteps) - avgPrev

        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color.Glu.primaryBlue
    }
}

// MARK: - Mini Steps Trend Chart

private struct ActivityOverviewStepsMiniTrendChart: View {

    let data: [DailyStepsEntry]

    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Steps", entry.steps)
            )
            .cornerRadius(4)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.Glu.activityDomain.opacity(0.25),
                        Color.Glu.activityDomain
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }
}

// MARK: - Workout Minutes Card (Workout Minutes)

private struct ActivityOverviewExerciseCard: View {

    // ✅ UPDATED: Workout Minutes statt Exercise Minutes
    let todayWorkoutMinutes: Int
    let avgWorkoutMinutes7d: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Label {
                    Text("Workout time")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.Glu.activityDomain)
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("\(todayWorkoutMinutes)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                let avg = max(Double(avgWorkoutMinutes7d), 1.0)
                let ratio = min(max(Double(todayWorkoutMinutes) / avg, 0.0), 1.0)

                VStack(alignment: .center, spacing: 4) {

                    ZStack {
                        Circle()
                            .stroke(Color.Glu.primaryBlue.opacity(0.15), lineWidth: 7)

                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(
                                Color.Glu.activityDomain,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("Ø")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)

                            Text("7d")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(width: 50, height: 50)

                    Text("\(avgWorkoutMinutes7d) min")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Active Energy Card (Overview)

private struct ActivityOverviewActiveEnergyCard: View {

    let todayKcal: Int
    let avgKcal7d: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Label {
                    Text("Active energy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.Glu.nutritionDomain)
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {

                VStack(alignment: .leading, spacing: 2) {

                    Text("\(todayKcal)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("kcal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                let avg = max(Double(avgKcal7d), 1.0)
                let ratio = min(max(Double(todayKcal) / avg, 0.0), 1.0)

                VStack(alignment: .center, spacing: 4) {

                    ZStack {
                        Circle()
                            .stroke(Color.Glu.primaryBlue.opacity(0.15), lineWidth: 7)

                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(
                                Color.Glu.nutritionDomain,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("Ø")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)

                            Text("7d")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(width: 50, height: 50)

                    Text("\(avgKcal7d) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Last Exercise (Overview)

private struct ActivityOverviewLastExerciseCard: View {

    let workouts: [(name: String, detail: String, date: String, time: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Label {
                    Text("Last exercise")
                        .font(.headline)
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color.Glu.activityDomain)
                }

                Spacer()
            }

            if workouts.isEmpty {
                HStack(spacing: 8) {
                    Text("No workout tracked yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(workouts.prefix(3).enumerated()), id: \.offset) { _, workout in
                        HStack(alignment: .top, spacing: 10) {

                            workoutBadge(for: workout.name)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color.Glu.primaryBlue)

                                Text(workout.detail)
                                    .font(.caption)
                                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(workout.date)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Color.Glu.primaryBlue)

                                Text(workout.time)
                                    .font(.caption2)
                                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
    }

    @ViewBuilder
    private func workoutBadge(for name: String) -> some View {
        let symbol = WorkoutBadgeHelper.symbolName(for: name)
        let isFallbackDrop = (symbol == "drop.fill")

        ZStack {
            Circle()
                .fill(Color.Glu.activityDomain.opacity(0.10))

            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundColor(
                    isFallbackDrop ? Color.Glu.nutritionDomain : Color.Glu.activityDomain
                )
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Insight (Overview)

private struct ActivityOverviewInsightCard: View {

    let insightText: String
    let category: ActivityInsightCategory
    let selectedDayOffset: Int

    var body: some View {

        guard selectedDayOffset == 0 else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Activity insight")
                        .font(.headline)
                        .foregroundColor(Color.Glu.primaryBlue)
                    Spacer()
                }

                Text(
                    insightText.isEmpty
                    ? "Not enough activity data is available yet. This insight will automatically adapt to your movement pattern as the day progresses."
                    : insightText
                )
                .font(.subheadline)
                .foregroundColor(Color.Glu.primaryBlue)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .gluVibCardFrame(domainColor: Color.Glu.activityDomain)
        )
    }
}

// MARK: - PageDots

private struct PageDots: View {
    let selected: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == selected ? color : color.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview (minimal, ohne zusätzliche Layout-Mods)
#Preview("Activity Overview V1") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    // !!! NEW: Preview-Szenario → Hint erzwingen (Exercise Minutes Fallback)
    previewStore.movementSplitActiveSourceTodayV1 = .exerciseMinutes  // !!! NEW

    let previewVM = ActivityOverviewViewModelV1(
        healthStore: previewStore,
        settings: .shared
    )

    return ActivityOverviewViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
