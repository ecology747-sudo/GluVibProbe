//
//  BodyOverviewViewV1.swift
//  GluVibProbe
//
//  Body — Overview (V1)
//
//  Purpose
//  - UI-only overview for the Body domain (Sleep, Weight, Heart, BMI, Body Fat).
//  - Uses the standard GluVib Overview pattern: gradient background, sticky header, 3-day pager (DayBefore/Yesterday/Today),
//    page dots, and pull-to-refresh (TODAY only; guarded inside the ViewModel).
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BodyOverviewViewModelV1 (mapping/formatting) → BodyOverviewViewV1 (render only)
//
//  Notes
//  - Views never access HealthKit directly.
//  - This file is intentionally structured into readable sections (Pager/Header/Sections/Cards) without altering design or behavior.
//

import SwiftUI
import Charts

// ============================================================
// MARK: - Scroll Offset Preference (Sticky Header)
// ============================================================

private struct BodyScrollOffsetKeyV1: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ============================================================
// MARK: - Body Overview (V1)
// ============================================================

struct BodyOverviewViewV1: View {

    // ============================================================
    // MARK: Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    // ============================================================
    // MARK: ViewModel
    // ============================================================

    @StateObject private var viewModel: BodyOverviewViewModelV1

    // ============================================================
    // MARK: Sticky Header State
    // ============================================================

    @State private var hasScrolled: Bool = false

    // ============================================================
    // MARK: Pager State (3 days)
    // ============================================================

    @State private var selectedPage: Int = 2
    @State private var didInitialLoad = false
    @State private var isProgrammaticPageUpdate = false

    // ============================================================
    // MARK: Init
    // ============================================================

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

    // ============================================================
    // MARK: Body
    // ============================================================

    var body: some View {
        ZStack {
            backgroundGradient
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
                .background(Color.clear)
                .ignoresSafeArea(edges: .bottom)
                .onPreferenceChange(BodyScrollOffsetKeyV1.self) { offset in
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
                    isProgrammaticPageUpdate = true
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)

                    DispatchQueue.main.async {
                        isProgrammaticPageUpdate = false
                    }
                }

                OverviewHeader(
                    title: L10n.BodyOverview.title, // 🟨 UPDATED
                    subtitle: headerSubtitle,
                    tintColor: Color.Glu.bodyDomain,
                    hasScrolled: hasScrolled,
                    permissionBadgeScope: .body
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
            await viewModel.refreshOnNavigation()
        }
    }
}

// ============================================================
// MARK: - Header Subtitle / Pager Helpers
// ============================================================

private extension BodyOverviewViewV1 {

    var headerSubtitle: String {
        switch viewModel.selectedDayOffset {
        case 0:
            return L10n.Common.todayUpper // 🟨 UPDATED
        case -1:
            return L10n.Common.yesterdayUpper // 🟨 UPDATED
        default:
            return dateString(for: viewModel.selectedDate)
        }
    }

    func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func dayOffset(for pageIndex: Int) -> Int {
        switch pageIndex {
        case 0: return -2
        case 1: return -1
        default: return 0
        }
    }

    func pageIndex(for offset: Int) -> Int {
        switch offset {
        case -2: return 0
        case -1: return 1
        default: return 2
        }
    }
}

// ============================================================
// MARK: - Background
// ============================================================

private extension BodyOverviewViewV1 {

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white,
                Color.Glu.bodyDomain.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// ============================================================
// MARK: - Day ScrollView (Content)
// ============================================================

private extension BodyOverviewViewV1 {

    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {

                scrollOffsetProbe

                weightSection
                kpiTilesSection
                insightSection
            }
            .padding(.top, 52)
            .padding(.horizontal, 16)
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 90)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// ============================================================
// MARK: - Day ScrollView Building Blocks
// ============================================================

private extension BodyOverviewViewV1 {

    var scrollOffsetProbe: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: BodyScrollOffsetKeyV1.self,
                    value: geo.frame(in: .global).minY
                )
        }
        .frame(height: 0)
    }

    var weightSection: some View {
        WeightMainCard(viewModel: viewModel)
            .contentShape(Rectangle())
            .onTapGesture {
                appState.handleMetricTap(metricName: L10n.Weight.title, settings: settings)
            }
    }

    var kpiTilesSection: some View {
        VStack(spacing: 12) {

            HStack(spacing: 12) {
                SleepSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.handleMetricTap(metricName: L10n.Sleep.title, settings: settings)
                    }

                HeartSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.handleMetricTap(metricName: L10n.RestingHeartRate.title, settings: settings)
                    }
            }

            HStack(spacing: 12) {
                BMISmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.handleMetricTap(metricName: L10n.BMI.title, settings: settings)
                    }

                BodyFatSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.handleMetricTap(metricName: L10n.BodyFat.title, settings: settings)
                    }
            }
        }
    }

    var insightSection: some View {
        BodyInsightCardV1(viewModel: viewModel)
            .contentShape(Rectangle())
    }
}

// ============================================================
// MARK: - PageDots (Legacy 1:1)
// ============================================================

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
// MARK: - Cards (Legacy 1:1, only VM type adapted)
// ============================================================

private struct WeightMainCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Label {
                    Text(L10n.Weight.title) // 🟨 UPDATED
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
                    Text(
                        String.localizedStringWithFormat(
                            L10n.BodyOverviewFormat.targetValue,
                            viewModel.formattedWeight(viewModel.targetWeightKg)
                        )
                    ) // 🟨 UPDATED
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
                WeightMiniBarChart(
                    data: viewModel.weightTrend,
                    targetWeightKg: viewModel.targetWeightKg
                )
                .frame(height: 60)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

private struct SleepSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(accent)

                    Text(L10n.Sleep.title) // 🟨 UPDATED
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedSleep(minutes: viewModel.lastNightSleepMinutes))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(L10n.BodyOverview.lastNight) // 🟨 UPDATED
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 4) {
                let rawRatio = viewModel.sleepGoalMinutes > 0
                    ? Double(viewModel.lastNightSleepMinutes) / Double(viewModel.sleepGoalMinutes)
                    : 0.0

                let ratio = max(0.0, min(rawRatio, 1.0))
                let percent = Int(rawRatio * 100)

                ProgressView(value: ratio, total: 1.0)
                    .tint(accent)

                Text(
                    String.localizedStringWithFormat(
                        L10n.BodyOverview.sleepGoalProgressFormat,
                        Int64(percent),
                        viewModel.formattedSleep(minutes: viewModel.sleepGoalMinutes)
                    )
                ) // 🟨 UPDATED
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

private struct HeartSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.nutritionDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)

                    Text(L10n.RestingHeartRate.title) // 🟨 UPDATED
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.restingHeartRateBpm) bpm")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                //Text(L10n.BodyOverview.restingHeartRateSubtitle) // 🟨 UPDATED
                  //  .font(.footnote.weight(.semibold))
                    //.foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 4) {

                ProgressView(value: 0.5)
                    .tint(accent)
                    .opacity(0)

                Text(
                    String.localizedStringWithFormat(
                        L10n.BodyOverview.hrvTodayFormat,
                        Int64(viewModel.hrvMs)
                    )
                ) // 🟨 UPDATED
                .font(.footnote)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.25))
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

private struct BMISmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.arms.open")
                        .foregroundColor(Color.Glu.nutritionDomain)

                    Text(L10n.BMI.title) // 🟨 UPDATED
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", viewModel.bmi))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                //Text(viewModel.bmiCategoryText(for: viewModel.bmi))
                  //  .font(.footnote.weight(.semibold))
                    //.foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

private struct BodyFatSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(accent)

                    Text(L10n.BodyFat.title) // 🟨 UPDATED
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f %%", viewModel.bodyFatPercent))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                //Text(L10n.BodyOverview.estimatedBodyFat) // 🟨 UPDATED
                  //  .font(.footnote.weight(.semibold))
                    //.foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
    }
}

private struct BodyInsightCardV1: View {

    @ObservedObject var viewModel: BodyOverviewViewModelV1

    var body: some View {

        guard viewModel.selectedDayOffset == 0 else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.BodyOverview.insightTitle) // 🟨 UPDATED
                        .font(.headline)
                        .foregroundColor(Color.Glu.primaryBlue)
                    Spacer()
                }

                Text(viewModel.bodyInsightText)
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .gluVibCardFrame(domainColor: Color.Glu.bodyDomain)
        )
    }
}

// ============================================================
// MARK: - Weight Mini Bar Chart (7 Days, Full Days Only)
// ============================================================

private struct WeightMiniBarChart: View {

    let data: [BodyWeightTrendPoint]
    let targetWeightKg: Double

    var body: some View {
        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Weight", point.weightKg)
                )
                .cornerRadius(4)
                .opacity(point.hasSample ? 1.0 : 0.0)
                .foregroundStyle(barGradient(for: point.weightKg))
                .annotation(position: .top, alignment: .center) {
                    if point.hasSample, let kg = point.weightKgOrNil, kg > 0 {
                        Text(formatKgOneDecimal(kg))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .padding(.bottom, 2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
                AxisValueLabel(centered: true) { // 🟨 UPDATED
                    if let date = value.as(Date.self) {
                        Text(weekday2(date))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }

    private func barGradient(for kg: Double) -> LinearGradient {
        let isOnOrBelowTarget = targetWeightKg > 0 && kg > 0 && kg <= targetWeightKg
        let color = isOnOrBelowTarget ? Color.Glu.successGreen : Color.Glu.bodyDomain

        return LinearGradient(
            colors: [
                color.opacity(0.25),
                color
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func weekday2(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EE"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func formatKgOneDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// ============================================================
// MARK: - Preview (minimal, no extra layout modifiers)
// ============================================================

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
        .environmentObject(SettingsModel.shared)
}
