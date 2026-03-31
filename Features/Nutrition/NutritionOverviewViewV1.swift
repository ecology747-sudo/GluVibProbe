//
//  NutritionOverviewViewV1.swift
//  GluVibProbe
//
//  Nutrition — Overview (V1)
//
//  Purpose
//  - UI-only overview for the Nutrition domain.
//  - Renders score, macro targets, macro distribution, energy balance and insight.
//  - Follows the shared GluVib overview pattern with sticky header, 3-day pager,
//    page dots and pull-to-refresh.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → NutritionOverviewViewModelV1 → NutritionOverviewViewV1
//
//  Architecture Rules
//  - View is render-only.
//  - No direct HealthKit access.
//  - No fetching logic inside the View.
//  - All state comes from the ViewModel.
//

import SwiftUI
import Charts

// ============================================================
// MARK: - Scroll Offset Preference
// ============================================================

private struct NutritionScrollOffsetKeyV1: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ============================================================
// MARK: - Pager Dots
// ============================================================

private struct NutritionPageDotsV1: View {
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
// MARK: - Nutrition Overview View
// ============================================================

struct NutritionOverviewViewV1: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var settings: SettingsModel

    @StateObject private var viewModel: NutritionOverviewViewModelV1

    // ============================================================
    // MARK: - UI State
    // ============================================================

    @State private var hasScrolled: Bool = false
    @State private var selectedPage: Int = 2
    @State private var didInitialLoad = false
    @State private var isProgrammaticPageUpdate = false

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(viewModel: NutritionOverviewViewModelV1? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: NutritionOverviewViewModelV1(
                    healthStore: .shared,
                    settings: .shared
                )
            )
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ZStack(alignment: .top) {
                TabView(selection: $selectedPage) {
                    dayScrollView.tag(0)
                    dayScrollView.tag(1)
                    dayScrollView.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.clear)
                .ignoresSafeArea(edges: .bottom)
                .onPreferenceChange(NutritionScrollOffsetKeyV1.self) { offset in
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
                    title: L10n.Common.nutritionOverviewTitle,
                    subtitle: headerSubtitle,
                    tintColor: Color.Glu.nutritionDomain,
                    hasScrolled: hasScrolled,
                    permissionBadgeScope: .nutrition
                )

                VStack {
                    Spacer()
                    NutritionPageDotsV1(
                        selected: selectedPage,
                        total: 3,
                        color: Color.Glu.nutritionDomain
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
        .onChange(of: appState.currentStatsScreen) { newScreen in
            if newScreen == .nutritionOverview || newScreen == .none {
                Task { @MainActor in
                    await viewModel.refreshOnNavigation()
                }
            }
        }
    }
}

// ============================================================
// MARK: - Pager / Header Helpers
// ============================================================

private extension NutritionOverviewViewV1 {

    var headerSubtitle: String {
        switch viewModel.selectedDayOffset {
        case 0: return L10n.Common.todayUpper
        case -1: return L10n.Common.yesterdayUpper
        default: return dateString(for: viewModel.selectedDate)
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
// MARK: - Reusable Visual Styling
// ============================================================

private extension NutritionOverviewViewV1 {

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white,
                Color.Glu.nutritionDomain.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.Glu.nutritionDomain.opacity(0.80), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(0.08),
                radius: 10,
                x: 0,
                y: 6
            )
    }
}

// ============================================================
// MARK: - Main Day Scroll Container
// ============================================================

private extension NutritionOverviewViewV1 {

    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                scrollOffsetProbe

                scoreSection
                macroTargetsSection
                macroDistributionSection
                energyRingSection
                energyBalance7DSection

                if viewModel.selectedDayOffset == 0 {
                    insightSection
                }
            }
            .padding(.top, 30)
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

    var scrollOffsetProbe: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: NutritionScrollOffsetKeyV1.self,
                    value: geo.frame(in: .global).minY
                )
        }
        .frame(height: 0)
    }
}

// ============================================================
// MARK: - Score Section
// ============================================================

private extension NutritionOverviewViewV1 {

    var scoreSection: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Text(L10n.NutritionOverview.scoreLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))

                Text("\(viewModel.nutritionScore)")
                    .font(.caption.weight(.bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        viewModel.scoreColor.opacity(0.9),
                                        viewModel.scoreColor.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundStyle(Color.white)
            }
        }
    }
}

// ============================================================
// MARK: - Macro Target Section
// ============================================================

private extension NutritionOverviewViewV1 {

    var macroTargetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 10) {
                macroTargetRow(
                    label: L10n.Carbs.title,
                    todayValue: viewModel.todayCarbsGrams,
                    targetValue: viewModel.targetCarbsGrams,
                    percentOfGoal: viewModel.carbsGoalPercent,
                    color: Color.Glu.nutritionDomain
                ) {
                    appState.handleMetricTap(metricName: L10n.Carbs.title, settings: settings)
                }

                macroSubTargetRow(
                    label: L10n.Sugar.title,
                    todayValue: viewModel.todaySugarGrams,
                    targetValue: viewModel.targetSugarGrams,
                    percentOfGoal: viewModel.sugarGoalPercent,
                    color: Color.Glu.activityDomain.opacity(0.75)
                ) {
                    appState.handleMetricTap(metricName: L10n.Sugar.title, settings: settings)
                }

                macroTargetRow(
                    label: L10n.Protein.title,
                    todayValue: viewModel.todayProteinGrams,
                    targetValue: viewModel.targetProteinGrams,
                    percentOfGoal: viewModel.proteinGoalPercent,
                    color: Color.Glu.metabolicDomain
                ) {
                    appState.handleMetricTap(metricName: L10n.Protein.title, settings: settings)
                }

                macroTargetRow(
                    label: L10n.Fat.title,
                    todayValue: viewModel.todayFatGrams,
                    targetValue: viewModel.targetFatGrams,
                    percentOfGoal: viewModel.fatGoalPercent,
                    color: Color.Glu.bodyDomain
                ) {
                    appState.handleMetricTap(metricName: L10n.Fat.title, settings: settings)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    func macroTargetRow(
        label: String,
        todayValue: Int,
        targetValue: Int,
        percentOfGoal: Int,
        color: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer()

                let todayText = String.localizedStringWithFormat(
                    L10n.NutritionOverviewFormat.gramsValue,
                    todayValue
                )

                let targetText = targetValue > 0
                    ? String.localizedStringWithFormat(
                        L10n.NutritionOverviewFormat.gramsValue,
                        targetValue
                    )
                    : "–"

                Text(
                    String.localizedStringWithFormat(
                        L10n.NutritionOverviewFormat.macroTargetProgress,
                        todayText,
                        targetText,
                        percentOfGoal
                    )
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.Glu.primaryBlue.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.Glu.primaryBlue.opacity(0.20), lineWidth: 0.6)
                    )

                GeometryReader { geo in
                    let width = geo.size.width
                    let ratio = min(max(CGFloat(percentOfGoal) / 100.0, 0), 1.0)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.90),
                                    color.opacity(0.70)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.5)
                        )
                        .frame(width: width * ratio)
                }
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }

    func macroSubTargetRow(
        label: String,
        todayValue: Int,
        targetValue: Int,
        percentOfGoal: Int,
        color: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.55))

                Text(L10n.NutritionOverview.sugarOfCarbsLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.88))

                Spacer()

                let todayText = String.localizedStringWithFormat(
                    L10n.NutritionOverviewFormat.gramsValue,
                    todayValue
                )

                let targetText = targetValue > 0
                    ? String.localizedStringWithFormat(
                        L10n.NutritionOverviewFormat.gramsValue,
                        targetValue
                    )
                    : "–"

                Text(
                    String.localizedStringWithFormat(
                        L10n.NutritionOverviewFormat.macroTargetProgress,
                        todayText,
                        targetText,
                        percentOfGoal
                    )
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.Glu.primaryBlue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.Glu.primaryBlue.opacity(0.18), lineWidth: 0.55)
                    )

                GeometryReader { geo in
                    let width = geo.size.width
                    let ratio = min(max(CGFloat(percentOfGoal) / 100.0, 0), 1.0)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.80),
                                    color.opacity(0.55)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.Glu.primaryBlue.opacity(0.30), lineWidth: 0.45)
                        )
                        .frame(width: width * ratio)
                }
            }
            .frame(height: 10)
        }
        .padding(.leading, 10)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// ============================================================
// MARK: - Macro Distribution Section
// ============================================================

private extension NutritionOverviewViewV1 {

    var macroDistributionSection: some View {
        HStack(spacing: 12) {
            if #available(iOS 17.0, *) {
                Chart {
                    if viewModel.todayCarbsGrams > 0 {
                        SectorMark(
                            angle: .value(L10n.NutritionOverview.carbsShort, viewModel.carbsShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.nutritionDomain)
                    }

                    if viewModel.todayProteinGrams > 0 {
                        SectorMark(
                            angle: .value(L10n.Protein.title, viewModel.proteinShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.metabolicDomain)
                    }

                    if viewModel.todayFatGrams > 0 {
                        SectorMark(
                            angle: .value(L10n.Fat.title, viewModel.fatShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.bodyDomain)
                    }
                }
                .chartLegend(.hidden)
                .frame(width: 110, height: 110)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.handleMetricTap(metricName: L10n.Carbs.title, settings: settings)
                }
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                    Text(L10n.NutritionOverview.pieIOS17Only)
                        .font(.caption2)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.6))
                }
                .frame(width: 110, height: 110)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.handleMetricTap(metricName: L10n.Carbs.title, settings: settings)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                macroLegendRow(
                    label: L10n.NutritionOverview.carbsShort,
                    grams: viewModel.todayCarbsGrams,
                    share: viewModel.carbsShare,
                    color: Color.Glu.nutritionDomain
                ) {
                    appState.handleMetricTap(metricName: L10n.Carbs.title, settings: settings)
                }

                macroLegendRow(
                    label: L10n.Protein.title,
                    grams: viewModel.todayProteinGrams,
                    share: viewModel.proteinShare,
                    color: Color.Glu.metabolicDomain
                ) {
                    appState.handleMetricTap(metricName: L10n.Protein.title, settings: settings)
                }

                macroLegendRow(
                    label: L10n.Fat.title,
                    grams: viewModel.todayFatGrams,
                    share: viewModel.fatShare,
                    color: Color.Glu.bodyDomain
                ) {
                    appState.handleMetricTap(metricName: L10n.Fat.title, settings: settings)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    func macroLegendRow(
        label: String,
        grams: Int,
        share: Double,
        color: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        let percentage = Int((share * 100).rounded())

        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Spacer()

            Text(
                String.localizedStringWithFormat(
                    L10n.NutritionOverviewFormat.macroShare,
                    grams,
                    percentage
                )
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// ============================================================
// MARK: - Energy Ring Section
// ============================================================

private extension NutritionOverviewViewV1 {

    var energyRingSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    let ringColor: Color = viewModel.isEnergyRemaining
                        ? Color.Glu.nutritionDomain
                        : .red

                    Circle()
                        .stroke(
                            ringColor.opacity(0.22),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )

                    Circle()
                        .trim(from: 0, to: viewModel.energyProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    ringColor.opacity(0.95),
                                    ringColor.opacity(0.55),
                                    ringColor.opacity(0.95)
                                ]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: viewModel.energyProgress)

                    VStack(spacing: 2) {
                        Text(
                            String.localizedStringWithFormat(
                                L10n.NutritionOverviewFormat.kcalValue,
                                Int(viewModel.formattedEnergyBalanceValue) ?? 0
                            )
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(viewModel.isEnergyRemaining ? Color.Glu.successGreen : .red)

                        Text(energyRingStatusLabel) // 🟨 UPDATED
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(
                                viewModel.isEnergyRemaining
                                ? Color.Glu.successGreen
                                : .red.opacity(0.9)
                            )
                    }
                }
                .frame(width: 110, height: 110)

                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.NutritionOverviewEnergy.burned)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.98))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.Glu.nutritionDomain, lineWidth: 0.6)
                                        )
                                )
                            Spacer()
                        }

                        let totalBurned = viewModel.todayActiveEnergyKcal + viewModel.restingEnergyKcal

                        Text(
                            String.localizedStringWithFormat(
                                L10n.NutritionOverviewFormat.kcalValue,
                                totalBurned
                            )
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.Glu.primaryBlue)

                        HStack {
                            Text(L10n.NutritionOverviewEnergy.active)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                            Spacer()
                            Text(viewModel.formattedActiveEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }

                        HStack {
                            Text(L10n.NutritionOverviewEnergy.resting)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                            Spacer()
                            Text(viewModel.formattedRestingEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        Color.Glu.nutritionDomain.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.Glu.nutritionDomain.opacity(0.9), lineWidth: 0.6)
                            )
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.NutritionOverviewEnergy.intake)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.98))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.Glu.nutritionDomain, lineWidth: 0.6)
                                        )
                                )
                            Spacer()
                        }

                        Text(viewModel.formattedNutritionEnergyKcal)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.Glu.primaryBlue)

                        HStack {
                            Text(L10n.NutritionOverviewEnergy.nutrition)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                            Spacer()
                            Text(viewModel.formattedNutritionEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        Color.Glu.nutritionDomain.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.Glu.nutritionDomain.opacity(0.9), lineWidth: 0.6)
                            )
                    )
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.handleMetricTap(metricName: L10n.NutritionEnergy.title, settings: settings)
        }
    }

    var energyRingStatusLabel: String { // 🟨 UPDATED
        let rawLabel = viewModel.isEnergyRemaining
            ? L10n.NutritionOverviewEnergy.remaining
            : L10n.NutritionOverviewEnergy.over

        let kcalPrefix = L10n.Common.kcalUnit + " "
        return rawLabel
            .replacingOccurrences(of: kcalPrefix, with: "")
            .capitalized
    }
}

// ============================================================
// MARK: - Energy Balance 7D Section
// ============================================================

private extension NutritionOverviewViewV1 {

    var energyBalance7DSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.NutritionOverviewEnergy.sectionTitle)
                    .font(.headline)
                    .foregroundStyle(Color.Glu.primaryBlue)
                Spacer()
            }

            EnergyBalance7DMiniBarChartV1(data: viewModel.last7DaysEnergyBalance)
                .frame(height: 90)
        }
        .padding(12)
        .background(cardBackground)
    }
}

// ============================================================
// MARK: - Energy Balance Mini Chart
// ============================================================

private struct EnergyBalance7DMiniBarChartV1: View {

    let data: [EnergyBalanceTrendPointV1]

    var body: some View {
        Chart {
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.8))
                .foregroundStyle(Color.Glu.nutritionDomain.opacity(0.95))

            ForEach(data, id: \.date) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Balance", point.balanceKcal)
                )
                .cornerRadius(4)
                .opacity(point.hasData ? 1.0 : 0.0)
                .foregroundStyle(barGradient(for: point.balanceKcal))
                .annotation(position: point.balanceKcal >= 0 ? .top : .bottom, alignment: .center) {
                    if point.hasData {
                        Text(formatKcal(point.balanceKcal))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .padding(point.balanceKcal >= 0 ? .bottom : .top, 2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisTick().foregroundStyle(Color.clear)
                AxisValueLabel {
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

    private func barGradient(for balance: Int) -> LinearGradient {
        let c: Color = balance > 0 ? .red : Color.Glu.successGreen
        return LinearGradient(
            colors: [
                c.opacity(0.25),
                c
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func weekday2(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EE"
        return f.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func formatKcal(_ v: Int) -> String {
        let absV = abs(v)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        let s = nf.string(from: NSNumber(value: absV)) ?? "\(absV)"
        return v >= 0 ? "+\(s)" : "−\(s)"
    }
}

// ============================================================
// MARK: - Insight Section
// ============================================================

private extension NutritionOverviewViewV1 {

    var insightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.NutritionOverviewInsight.title)
                .font(.headline)
                .foregroundStyle(Color.Glu.primaryBlue)

            Text(
                viewModel.insightText.isEmpty
                ? L10n.NutritionOverviewInsight.emptyToday
                : viewModel.insightText
            )
            .font(.subheadline)
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)

            if !viewModel.insightSecondaryText.isEmpty { // 🟨 UPDATED
                Text(viewModel.insightSecondaryText)
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Nutrition Overview V1") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM = NutritionOverviewViewModelV1(
        healthStore: previewStore,
        settings: .shared
    )

    return NutritionOverviewViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
