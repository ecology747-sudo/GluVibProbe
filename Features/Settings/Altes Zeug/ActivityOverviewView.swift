//
//  ActivityOverviewView.swift
//  GluVibProbe
//
//  Echte Activity Overview mit ActivityOverviewViewModel
//  - Steps Today + 7-Tage-Ø + Distanz + Mini-Trend
//  - Exercise Minutes Today + 7-Tage-Ø
//  - Active Energy Today + 7-Tage-Ø
//  - Movement Split Today (24h-Balken, echte Daten)
//  - Last Exercise (Dummy)
//  - Activity Insight (Dummy)
//

import SwiftUI
import Charts

// MARK: - Scroll Offset Preference (für Sticky-Header)
/// Wie in NutritionOverview:
/// misst die vertikale Position des Inhalts (global),
/// damit der Header weiß, ob gescrollt wurde.
private struct ActivityScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ActivityOverviewView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - ViewModel

    @StateObject private var viewModel: ActivityOverviewViewModel

    // MARK: - Sticky-Header-State
    /// Steuert, ob der Header seinen Blur/„angescrollten“ Zustand zeigt,
    /// analog zu `hasScrolled` in der NutritionOverviewView.
    @State private var hasScrolled: Bool = false

    // MARK: - Pager-State (DayBefore / Yesterday / Today)           // !!! NEW
    /// 0 = DayBefore (-2), 1 = Yesterday (-1), 2 = Today (0)        // !!! NEW
    @State private var selectedPage: Int = 2                         // !!! NEW

    // MARK: - Init

    init(viewModel: ActivityOverviewViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: ActivityOverviewViewModel(
                    healthStore: .shared,
                    settings: .shared
                )
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Hintergrund-Gradient wie im Design
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.activityDomain.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 🔝 Struktur wie in NutritionOverview:
            //  - unten Pager mit 3 Tages-Views
            //  - oben drüber der Overlay-Header
            ZStack(alignment: .top) {

                // MARK: - Horizontaler Pager (DayBefore / Yesterday / Today)   // !!! NEW
                TabView(selection: $selectedPage) {                             // !!! NEW

                    // 0 = DayBefore (2 Tage zurück)                            // !!! NEW
                    dayScrollView                                               // !!! NEW
                        .tag(0)                                                 // !!! NEW

                    // 1 = Yesterday                                           // !!! NEW
                    dayScrollView                                               // !!! NEW
                        .tag(1)                                                 // !!! NEW

                    // 2 = Today                                               // !!! NEW
                    dayScrollView                                               // !!! NEW
                        .tag(2)                                                 // !!! NEW
                }
                .tabViewStyle(.page(indexDisplayMode: .never))                  // !!! NEW
                // Scroll-Offset → hasScrolled, mit leichter Animation
                .onPreferenceChange(ActivityScrollOffsetKey.self) { offset in   // !!! NEW
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                // Reaktion auf Pager-Wechsel → ViewModel-Tages-Offset setzen   // !!! NEW
                .onChange(of: selectedPage) { newIndex in                       // !!! NEW
                    let newOffset = dayOffset(for: newIndex)                    // !!! NEW
                    Task {                                                      // !!! NEW
                        await viewModel.applySelectedDayOffset(newOffset)       // !!! NEW
                        await viewModel.refresh()                               // !!! NEW
                    }                                                           // !!! NEW
                }
                .onAppear {                                                     // !!! NEW
                    // Pager-Index an aktuell gesetzten Offset anpassen         // !!! NEW
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)  // !!! NEW
                }

                // MARK: Sticky OverviewHeader (Overlay, wie in Nutrition)
                OverviewHeader(
                    title: "Activity Overview",
                    subtitle: headerSubtitle,               // !!! CHANGED: dynamischer Untertitel
                    tintColor: Color.Glu.activityDomain,
                    hasScrolled: hasScrolled
                )

                // OPTIONAL: PageDots unten, wenn du magst wie in Nutrition      // !!! NEW
                VStack {                                                        // !!! NEW
                    Spacer()                                                    // !!! NEW
                    PageDots(                                                   // !!! NEW
                        selected: selectedPage,                                 // !!! NEW
                        total: 3,                                               // !!! NEW
                        color: Color.Glu.activityDomain                         // !!! NEW
                    )                                                           // !!! NEW
                    .padding(.bottom, 12)                                       // !!! NEW
                }                                                               // !!! NEW
            }
        }
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Header-Subtitle & Datum (analog Nutrition)             // !!! NEW

    /// Liefert den Text für den Header:
    /// - TODAY      für offset 0
    /// - YESTERDAY  für offset -1
    /// - Datum      für offset ≤ -2
    private var headerSubtitle: String {                             // !!! NEW
        switch viewModel.selectedDayOffset {
        case 0:
            return "TODAY"
        case -1:
            return "YESTERDAY"
        default:
            return dateString(for: viewModel.selectedDate)
        }
    }

    private func dateString(for date: Date) -> String {               // !!! NEW
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Mapping Pager-Index → DayOffset (in Tagen relativ zu heute)   // !!! NEW
    /// 0 = DayBefore (-2), 1 = Yesterday (-1), 2 = Today (0)
    private func dayOffset(for pageIndex: Int) -> Int {               // !!! NEW
        switch pageIndex {
        case 0: return -2
        case 1: return -1
        default: return 0
        }
    }

    /// Mapping DayOffset → Pager-Index                               // !!! NEW
    ///  0 → 2 (Today)
    /// -1 → 1 (Yesterday)
    /// -2 → 0 (DayBefore)
    private func pageIndex(for offset: Int) -> Int {                  // !!! NEW
        switch offset {
        case -2: return 0
        case -1: return 1
        default: return 2
        }
    }
}

// MARK: - Tages-ScrollView (wird für alle 3 Pager-Seiten genutzt)    // !!! NEW

private extension ActivityOverviewView {                              // !!! NEW

    /// Eine „Maske“ für alle Tage – die Zahlen ändern sich,
    /// weil das ViewModel je nach selectedDayOffset andere Daten liefert.
    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {

                // GLOBALER OFFSET-MESSER (wie in Nutrition dayScrollView)
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
                    onTapSteps: {
                        appState.currentStatsScreen = .steps
                    }
                )
                .padding(.horizontal, 16)

                // EXERCISE + ACTIVE ENERGY
                HStack(spacing: 12) {

                    ActivityOverviewExerciseCard(
                        todayExerciseMinutes: viewModel.todayExerciseMinutes,
                        avgExerciseMinutes7d: viewModel.sevenDayAverageExerciseMinutes,
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

                // MOVEMENT SPLIT – 24h-Balken mit echten Daten
                movementSplitCard
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.currentStatsScreen = .movementSplit
                    }

                // LAST EXERCISE – echte Daten aus ViewModel
                ActivityOverviewLastExerciseCard(
                    workouts: viewModel.lastExercisesDisplay
                )
                .padding(.horizontal, 16)

                // INSIGHT – Logik aus ActivityInsightEngine
                ActivityOverviewInsightCard(
                    insightText: viewModel.activityInsightText,
                    category: viewModel.activityInsightCategory
                )
                .padding(.horizontal, 16)
            }
            // Platz nach oben, damit der Inhalt sauber UNTER dem Overlay-Header startet
            .padding(.top, 30)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Movement Split Card (24h-Balken, echte Daten)

private extension ActivityOverviewView {  // !!! CHANGED: in Extension gepackt, Logik unverändert

    var movementSplitCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Movement split")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let totalFraction = viewModel.movementSplitFillFractionOfDay
                    let percentages = viewModel.movementSplitPercentages

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.Glu.metabolicDomain)
                            .frame(width: width * totalFraction * percentages.sleep)

                        Rectangle()
                            .fill(Color.Glu.activityDomain)
                            .frame(width: width * totalFraction * percentages.move)

                        Rectangle()
                            .fill(Color.Glu.bodyDomain.opacity(0.85))
                            .frame(width: width * totalFraction * percentages.sedentary)

                        Spacer(minLength: 0)
                    }
                    .frame(height: 14)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.Glu.primaryBlue.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .frame(height: 14)

                HStack(alignment: .top, spacing: 12) {
                    movementLegendItem(
                        color: Color.Glu.metabolicDomain,
                        title: "Sleep",
                        minutes: viewModel.movementSleepMinutesToday
                    )
                    movementLegendItem(
                        color: Color.Glu.activityDomain,
                        title: "Active",
                        minutes: viewModel.movementActiveMinutesToday
                    )
                    movementLegendItem(
                        color: Color.Glu.bodyDomain.opacity(0.85),
                        title: "Rest",
                        minutes: viewModel.movementSedentaryMinutesToday
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.6)
                )
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }

    private func movementLegendItem(
        color: Color,
        title: String,
        minutes: Int
    ) -> some View {
        let hours = minutes / 60
        let mins = minutes % 60
        let timeText: String
        if hours > 0 && mins > 0 {
            timeText = "\(hours) h \(mins) min"
        } else if hours > 0 {
            timeText = "\(hours) h"
        } else {
            timeText = "\(mins) min"
        }

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

// MARK: - Score Badge (wie im Design, leicht umbenannt)

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

    let onTapSteps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Title row with trend arrow on the right
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

                // kleiner, ruhigerer Trendpfeil
                Image(systemName: trendArrowSymbol())
                    .font(.title2.weight(.bold))
                    .foregroundColor(trendArrowColor())
                    .padding(.trailing, 2)
            }

            // Big KPI Steps + Remaining/Target rund um den Bar
            VStack(alignment: .leading, spacing: 4) {

                // große KPI-Zahl
                Text(formattedSteps(todaySteps))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                // Remaining über dem Balken – enger gesetzt
                HStack(spacing: 4) {
                    Spacer()
                    Text("Remaining")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(formattedSteps(max(stepsGoal - todaySteps, 0)))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                }

                // kompakter Horizontal-Bar
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

                // Target unter dem Balken – enger
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

            // Distance row – simple Horizontal Bar like Steps-bar
            VStack(alignment: .leading, spacing: 6) {

                // Distance-Label mit Ruler-Icon in Grün
                HStack(spacing: 6) {
                    Image(systemName: "ruler")
                        .foregroundColor(Color.Glu.bodyDomain)

                    Text("Distance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                }

                // Labels über dem Balken
                HStack {
                    Text("")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Spacer()

                    Text("7-day avg")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                }

                // Horizontaler Balken (Skala = 7-day average)
                GeometryReader { geo in
                    let width = geo.size.width
                    let avg = max(distanceAverage7dKm, 0.1)
                    let fraction = min(max(distanceTodayKm / avg, 0), 1)

                    ZStack(alignment: .leading) {

                        // Hintergrund-Bar (Skala)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.Glu.primaryBlue.opacity(0.06))

                        // Gefüllter Anteil (heutige Distanz)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.Glu.bodyDomain)
                            .frame(width: width * fraction)

                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.8)
                    }
                }
                .frame(height: 8)

                // Werte unter dem Balken
                HStack {
                    Text(formattedKm(distanceTodayKm))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))

                    Spacer()

                    Text(formattedKm(distanceAverage7dKm))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                }
            }

            // Mini 7-Day Steps Trend
            if !last7DaysSteps.isEmpty {
                ActivityOverviewStepsMiniTrendChart(data: last7DaysSteps)
                    .frame(height: 60)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.6)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTapSteps()
        }
    }

    // MARK: - Helpers

    private func formattedSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedKm(_ value: Double) -> String {
        String(format: "%.1f km", value)
    }

    private func trendArrowSymbol() -> String {
        guard last7DaysSteps.count >= 2 else {
            return "arrow.right"
        }

        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        let count = sorted.count

        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else {
            return "arrow.right"
        }

        let yesterdaySteps = sorted[yesterdayIndex].steps

        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else {
            return "arrow.right"
        }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)

        let diff = Double(yesterdaySteps) - avgPrev
        let threshold: Double = 1_000

        if diff > threshold {
            return "arrow.up.right"
        } else if diff < -threshold {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }

    private func trendArrowColor() -> Color {
        guard last7DaysSteps.count >= 2 else {
            return Color.Glu.primaryBlue
        }

        let sorted = last7DaysSteps.sorted { $0.date < $1.date }
        let count = sorted.count

        let yesterdayIndex = count - 2
        guard yesterdayIndex > 0 else {
            return Color.Glu.primaryBlue
        }

        let yesterdaySteps = sorted[yesterdayIndex].steps

        let startIndex = max(0, yesterdayIndex - 3)
        let previousSlice = sorted[startIndex..<yesterdayIndex]
        guard !previousSlice.isEmpty else {
            return Color.Glu.primaryBlue
        }

        let sumPrev = previousSlice.reduce(0) { $0 + $1.steps }
        let avgPrev = Double(sumPrev) / Double(previousSlice.count)

        let diff = Double(yesterdaySteps) - avgPrev

        if diff > 0 {
            return .green
        } else if diff < 0 {
            return .red
        } else {
            return Color.Glu.primaryBlue
        }
    }
}

// MARK: - Mini Steps Trend Chart (Overview)

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

// MARK: - Active Card (Exercise Minutes)

private struct ActivityOverviewExerciseCard: View {

    let todayExerciseMinutes: Int
    let avgExerciseMinutes7d: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header: "Active time" + Icon
            HStack {
                Label {
                    Text("Active time")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "figure.run")
                        .font(.system(size: 13))
                        .foregroundColor(Color.Glu.metabolicDomain)
                }

                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {

                // Linke Seite: große Zahl + Einheit (kein "Today")          // !!! UPDATED
                VStack(alignment: .leading, spacing: 2) {

                    Text("\(todayExerciseMinutes)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Kein zusätzliches Label → entfernt                     // !!! REMOVED
                }

                Spacer()

                // Rechte Seite: Ringchart + Ø-7d-Wert darunter               // !!! UPDATED
                let avg = max(Double(avgExerciseMinutes7d), 1.0)
                let ratio = min(max(Double(todayExerciseMinutes) / avg, 0.0), 1.0)

                VStack(alignment: .center, spacing: 4) {                      // !!! UPDATED

                    ZStack {
                        Circle()
                            .stroke(
                                Color.Glu.primaryBlue.opacity(0.15),
                                lineWidth: 7
                            )

                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(
                                Color.Glu.metabolicDomain,
                                style: StrokeStyle(
                                    lineWidth: 7,
                                    lineCap: .round
                                )
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

                    // NEW: Ø-7d-Wert unter dem Ringchart                     // !!! NEW
                    Text("\(avgExerciseMinutes7d) min")
                        .font(.caption.weight(.semibold))                    // kleiner, klarer
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.6)
                )
        )
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

            // Header: "Active energy" + Icon
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

                // Linke Seite: Zahl / Einheit (kein "Today" mehr)          // !!! UPDATED
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

                    // Kein "Today"-Label, damit es für gestern/vorgestern   // !!! REMOVED
                    // nicht verwirrend ist.                                 // !!! REMOVED
                }

                Spacer()

                // Rechte Seite: Ringchart + Ø-7d-Zahl direkt darunter      // !!! UPDATED
                let avg = max(Double(avgKcal7d), 1.0)
                let ratio = min(max(Double(todayKcal) / avg, 0.0), 1.0)

                VStack(alignment: .center, spacing: 4) {                   // !!! UPDATED (center)

                    // Ring zeigt Verhältnis Today / 7-Tage-Ø
                    ZStack {
                        Circle()
                            .stroke(
                                Color.Glu.primaryBlue.opacity(0.15),
                                lineWidth: 7
                            )

                        Circle()
                            .trim(from: 0, to: ratio)
                            .stroke(
                                Color.Glu.nutritionDomain,
                                style: StrokeStyle(
                                    lineWidth: 7,
                                    lineCap: .round
                                )
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

                    // Nur die 7-Tage-Ø-Zahl unter dem Ring                 // !!! NEW
                    Text("\(avgKcal7d) kcal")                               // !!! NEW
                        .font(.caption.weight(.semibold))                   // kleiner als große Today-Zahl
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.6)
                )
        )
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.6)
                )
        )
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
                    isFallbackDrop
                    ? Color.Glu.nutritionDomain
                    : Color.Glu.activityDomain
                )
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Insight (Overview)

private struct ActivityOverviewInsightCard: View {

    let insightText: String
    let category: ActivityInsightCategory

    var body: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.Glu.activityDomain.opacity(0.55), lineWidth: 1.6)
                )
        )
    }
}

// MARK: - PageDots (optional, wie in NutritionOverview)             // !!! NEW

private struct PageDots: View {                                      // !!! NEW
    let selected: Int                                                // !!! NEW
    let total: Int                                                   // !!! NEW
    let color: Color                                                 // !!! NEW

    var body: some View {                                            // !!! NEW
        HStack(spacing: 8) {                                         // !!! NEW
            ForEach(0..<total, id: \.self) { index in                // !!! NEW
                Circle()                                             // !!! NEW
                    .fill(index == selected ? color                  // !!! NEW
                          : color.opacity(0.35))                     // !!! NEW
                    .frame(width: 8, height: 8)                      // !!! NEW
            }                                                        // !!! NEW
        }                                                            // !!! NEW
        .padding(.horizontal, 16)                                    // !!! NEW
    }                                                                // !!! NEW
}

// MARK: - Preview

#Preview("Activity Overview – Live VM") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM = ActivityOverviewViewModel(
        healthStore: previewStore,
        settings: .shared
    )

    return ActivityOverviewView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
