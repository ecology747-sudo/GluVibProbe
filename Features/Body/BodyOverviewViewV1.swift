//
//  BodyOverviewViewV1.swift
//  GluVibProbe
//
//  V1: Body Overview
//  - Design/Hierarchie basiert 1:1 auf alter BodyOverviewView (Cards/Content)
//  - Mechanik (Pager/InitialLoad/Refresh) 1:1 wie ActivityOverviewViewV1
//  - Daten kommen aus BodyOverviewViewModelV1 (SSoT: HealthStore)
//

import SwiftUI
import Charts

// MARK: - Scroll Offset Preference (für Sticky-Header)

private struct BodyScrollOffsetKeyV1: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BodyOverviewViewV1: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - ViewModel

    @StateObject private var viewModel: BodyOverviewViewModelV1

    // MARK: - Sticky Header

    @State private var hasScrolled: Bool = false

    // MARK: - Pager State

    /// 0 = DayBefore (-2), 1 = Yesterday (-1), 2 = Today (0)
    @State private var selectedPage: Int = 2
    @State private var didInitialLoad = false
    @State private var isProgrammaticPageUpdate = false                // !!! NEW (wie Activity)

    // MARK: - Init

    init(viewModel: BodyOverviewViewModelV1? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: BodyOverviewViewModelV1(
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
                    Color.Glu.bodyDomain.opacity(0.55)
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
                .onPreferenceChange(BodyScrollOffsetKeyV1.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                .onChange(of: selectedPage) { newIndex in
                    guard !isProgrammaticPageUpdate else { return }     // !!! NEW (wie Activity)
                    let newOffset = dayOffset(for: newIndex)
                    Task { @MainActor in
                        await viewModel.applySelectedDayOffset(newOffset)
                    }
                }
                .onAppear {
                    // ✅ Initiales Setzen der Page darf KEIN onChange-Remap auslösen // !!! NEW (wie Activity)
                    isProgrammaticPageUpdate = true                     // !!! NEW
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)

                    DispatchQueue.main.async {                          // !!! NEW
                        isProgrammaticPageUpdate = false                // !!! NEW
                    }
                }

                OverviewHeader(
                    title: "Body Overview",
                    subtitle: headerSubtitle,
                    tintColor: Color.Glu.bodyDomain,
                    hasScrolled: hasScrolled
                )

                VStack {
                    Spacer()
                    PageDots(
                        selected: selectedPage,
                        total: 3,
                        color: Color.Glu.bodyDomain
                    )
                    .padding(.bottom, 12)
                }
            }
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await viewModel.refreshOnNavigation()                       // !!! NEW (wie Activity)
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

private extension BodyOverviewViewV1 {

    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {

                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: BodyScrollOffsetKeyV1.self,
                            value: geo.frame(in: .global).minY
                        )
                }
                .frame(height: 0)

                // 1:1 Content aus alter BodyOverviewView (nur mit V1-VM)

                WeightMainCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.currentStatsScreen = .weight }

                HStack(spacing: 12) {
                    SleepSmallCard(viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.currentStatsScreen = .sleep }

                    HeartSmallCard(viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.currentStatsScreen = .restingHeartRate }
                }

                HStack(spacing: 12) {
                    BMISmallCard(viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.currentStatsScreen = .bmi }

                    BodyFatSmallCard(viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture { appState.currentStatsScreen = .bodyFat }
                }

                BodyInsightCardV1(viewModel: viewModel)                              // !!! CHANGED
                    .contentShape(Rectangle())
            }
            .padding(.top, 52)            // 1:1 wie alte BodyOverviewView
            .padding(.horizontal, 16)     // 1:1 wie alte BodyOverviewView
            .padding(.bottom, 60)         // 1:1 wie alte BodyOverviewView (Platz für Dots)
        }
        .refreshable {
            await viewModel.refresh()     // ✅ Pull-to-refresh wird im VM TODAY-guarded (wie Activity)
        }
    }
}

// MARK: - PageDots (1:1 aus alter BodyOverviewView)

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

// ============================================================
// MARK: - Cards (1:1 aus alter BodyOverviewView, nur VM-Typ angepasst)
// ============================================================

// MARK: - Weight main card

private struct WeightMainCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1

    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Label {
                    Text("Weight")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "figure.stand")
                        .foregroundColor(Color.Glu.bodyDomain)
                }

                Spacer()

                Image(systemName: viewModel.trendArrowSymbol())
                    .font(.title2.weight(.bold))
                    .foregroundColor(viewModel.trendArrowColor())
                    .padding(.trailing, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedWeight(viewModel.todayWeightKg))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                HStack(spacing: 8) {
                    Text("Target: \(viewModel.formattedWeight(viewModel.targetWeightKg))")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text("·")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text(viewModel.formattedDeltaKg(viewModel.weightDeltaKg))
                        .foregroundColor(viewModel.deltaColor(for: viewModel.weightDeltaKg))
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            if !viewModel.weightTrend.isEmpty {
                WeightMiniBarChart(data: viewModel.weightTrend)
                    .frame(height: 60)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain) // ✅ Regel: zentraler Modifier
    }
}

// MARK: - Sleep small tile

private struct SleepSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(accent)

                    Text("Sleep")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedSleep(minutes: viewModel.lastNightSleepMinutes))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Last night")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 4) {
                let rawRatio = viewModel.sleepGoalMinutes > 0
                    ? Double(viewModel.lastNightSleepMinutes) / Double(viewModel.sleepGoalMinutes)
                    : 0.0

                let ratio = max(0.0, min(rawRatio, 1.0))
                let percent = Int(rawRatio * 100)

                let goalMinutes = viewModel.sleepGoalMinutes
                let goalHours = Double(goalMinutes) / 60.0

                let goalString = goalHours.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f h", goalHours)
                    : String(format: "%.1f h", goalHours)

                ProgressView(value: ratio, total: 1.0)
                    .tint(accent)

                Text("\(percent)% of \(goalString)")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

// MARK: - Heart small tile

private struct HeartSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.nutritionDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)

                    Text("Heart")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.restingHeartRateBpm) bpm")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Resting heart rate")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 4) {

                ProgressView(value: 0.5)
                    .tint(accent)
                    .opacity(0)

                Text("\(viewModel.hrvMs) ms · HRV today")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

// MARK: - BMI tile

private struct BMISmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.metabolicDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.arms.open")
                        .foregroundColor(Color.Glu.nutritionDomain)

                    Text("BMI")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", viewModel.bmi))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(viewModel.bmiCategoryText(for: viewModel.bmi))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

// MARK: - Body fat tile

private struct BodyFatSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(accent)

                    Text("Body fat")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f %%", viewModel.bodyFatPercent))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Estimated body fat")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

// MARK: - Insight card

private struct BodyInsightCardV1: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1            // !!! NEW

    var body: some View {

        // ✅ Insight nur TODAY anzeigen (0 = today)                   // !!! NEW
        guard viewModel.selectedDayOffset == 0 else {                 // !!! NEW
            return AnyView(EmptyView())                               // !!! NEW
        }                                                             // !!! NEW

        return AnyView(                                               // !!! NEW
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Insight")
                        .font(.headline)
                        .foregroundColor(Color.Glu.primaryBlue)
                    Spacer()
                }

                Text(viewModel.bodyInsightText)                       // !!! CHANGED
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
        )
    }
}

// MARK: - Mini bar chart for weight (7 fixed days, gaps visible)

private struct WeightMiniBarChart: View {

    let data: [BodyWeightTrendPoint]

    var body: some View {
        Chart {
            ForEach(data.sorted { $0.date < $1.date }) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Weight", point.weightKg ?? 0)     // !!! FIX: 0 für Tage ohne Messung
                )
                .cornerRadius(4)
                .opacity(point.hasSample ? 1.0 : 0.0)            // !!! FIX: Lücke bleibt sichtbar
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.Glu.bodyDomain.opacity(0.25),
                            Color.Glu.bodyDomain
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }
}

// MARK: - Preview (minimal, ohne zusätzliche Layout-Mods)

#Preview("Body Overview V1 – Live VM") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM = BodyOverviewViewModelV1(
        healthStore: previewStore,
        settings: .shared
    )

    return BodyOverviewViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
