//
//  NutritionOverviewViewV1.swift
//  GluVibProbe
//
//  V1: Nutrition Overview
//  - Pager (3 Tage) + Sticky Header + PageDots wie ActivityOverviewViewV1
//  - Daten kommen aus NutritionOverviewViewModelV1 (SSoT: HealthStore)
//  - Pull-to-Refresh nur sinnvoll für TODAY (VM gated)
//  - Navigation: Tap auf Cards -> AppState StatsScreen
//

import SwiftUI
import Charts

// MARK: - Scroll Offset Preference (für Sticky-Header)

private struct NutritionScrollOffsetKeyV1: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - PageDots (muss im Scope sein)

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

struct NutritionOverviewViewV1: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    // @EnvironmentObject var healthStore: HealthStore                                // !!! UPDATED (entfernt, View nutzt nur VM)

    // MARK: - ViewModel

    @StateObject private var viewModel: NutritionOverviewViewModelV1

    // MARK: - Sticky Header

    @State private var hasScrolled: Bool = false

    // MARK: - Pager State

    /// 0 = DayBefore (-2), 1 = Yesterday (-1), 2 = Today (0)
    @State private var selectedPage: Int = 2
    @State private var didInitialLoad = false
    @State private var isProgrammaticPageUpdate = false

    // MARK: - Init

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

    // MARK: - Body

    var body: some View {
        ZStack {

            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.nutritionDomain.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ZStack(alignment: .top) {

                TabView(selection: $selectedPage) {
                    dayScrollView.tag(0)
                    dayScrollView.tag(1)
                    dayScrollView.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
                    // ✅ Initiales Setzen der Page darf KEIN onChange-Remap auslösen
                    isProgrammaticPageUpdate = true
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)
                    DispatchQueue.main.async {
                        isProgrammaticPageUpdate = false
                    }
                }

                OverviewHeader(
                    title: "Nutrition Overview",
                    subtitle: headerSubtitle,
                    tintColor: Color.Glu.nutritionDomain,
                    hasScrolled: hasScrolled
                )

                VStack {
                    Spacer()
                    NutritionPageDotsV1(                                                  // !!! UPDATED
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
            // Wenn wir aus Detail-Metriken zurückkommen → Overview neu mappen
            if newScreen == .nutritionOverview || newScreen == .none {
                Task { @MainActor in
                    await viewModel.refreshOnNavigation()
                }
            }
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

// MARK: - Shared Card Background

private extension NutritionOverviewViewV1 {

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

// MARK: - Day ScrollView

private extension NutritionOverviewViewV1 {

    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {

                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: NutritionScrollOffsetKeyV1.self,
                            value: geo.frame(in: .global).minY
                        )
                }
                .frame(height: 0)

                // 1) SCORE
                scoreSection

                // 2) MACRO TARGET BARS
                macroTargetsSection

                // 3) MACRO DISTRIBUTION PIE
                macroDistributionSection

                // 4) DAILY ENERGY BALANCE
                energyRingSection

                // 5) INSIGHT (nur TODAY wie Activity)
                if viewModel.selectedDayOffset == 0 {                                    // !!! NEW
                    insightSection                                                       // !!! NEW
                }                                                                        // !!! NEW
            }
            .padding(.top, 30)
            .padding(.horizontal, 16)
            .padding(.bottom, 60)
        }
        .refreshable {
            await viewModel.refresh()                                                    // ✅ VM gated (TODAY only)
        }
    }
}

// MARK: - Score Section

private extension NutritionOverviewViewV1 {

    var scoreSection: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Text("Nutrition Score")
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

// MARK: - Macro Targets

private extension NutritionOverviewViewV1 {

    var macroTargetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 10) {

                macroTargetRow(
                    label: "Carbs",
                    todayValue: viewModel.todayCarbsGrams,
                    targetValue: viewModel.targetCarbsGrams,
                    percentOfGoal: viewModel.carbsGoalPercent,
                    color: Color.Glu.nutritionDomain
                ) {
                    appState.currentStatsScreen = .carbs
                }

                macroTargetRow(
                    label: "Protein",
                    todayValue: viewModel.todayProteinGrams,
                    targetValue: viewModel.targetProteinGrams,
                    percentOfGoal: viewModel.proteinGoalPercent,
                    color: Color.Glu.metabolicDomain
                ) {
                    appState.currentStatsScreen = .protein
                }

                macroTargetRow(
                    label: "Fat",
                    todayValue: viewModel.todayFatGrams,
                    targetValue: viewModel.targetFatGrams,
                    percentOfGoal: viewModel.fatGoalPercent,
                    color: Color.Glu.bodyDomain
                ) {
                    appState.currentStatsScreen = .fat
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

                let todayText  = "\(todayValue) g"
                let targetText = targetValue > 0 ? "\(targetValue) g" : "–"

                Text("\(todayText) / \(targetText)  (\(percentOfGoal)%)")
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
}

// MARK: - Macro Distribution Pie

private extension NutritionOverviewViewV1 {

    var macroDistributionSection: some View {
        HStack(spacing: 12) {

            if #available(iOS 17.0, *) {
                Chart {
                    if viewModel.todayCarbsGrams > 0 {
                        SectorMark(
                            angle: .value("Carbs", viewModel.carbsShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.nutritionDomain)
                    }
                    if viewModel.todayProteinGrams > 0 {
                        SectorMark(
                            angle: .value("Protein", viewModel.proteinShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.metabolicDomain)
                    }
                    if viewModel.todayFatGrams > 0 {
                        SectorMark(
                            angle: .value("Fat", viewModel.fatShare),
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
                    appState.currentStatsScreen = .carbs
                }
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06))
                    Text("iOS 17 Pie only")
                        .font(.caption2)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.6))
                }
                .frame(width: 110, height: 110)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentStatsScreen = .carbs
                }
            }

            VStack(alignment: .leading, spacing: 8) {

                macroLegendRow(
                    label: "Carbs",
                    grams: viewModel.todayCarbsGrams,
                    share: viewModel.carbsShare,
                    color: Color.Glu.nutritionDomain
                ) { appState.currentStatsScreen = .carbs }

                macroLegendRow(
                    label: "Protein",
                    grams: viewModel.todayProteinGrams,
                    share: viewModel.proteinShare,
                    color: Color.Glu.metabolicDomain
                ) { appState.currentStatsScreen = .protein }

                macroLegendRow(
                    label: "Fat",
                    grams: viewModel.todayFatGrams,
                    share: viewModel.fatShare,
                    color: Color.Glu.bodyDomain
                ) { appState.currentStatsScreen = .fat }
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

            Text("\(grams) g (\(percentage)%)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Daily Energy Balance

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
                        Text("\(viewModel.formattedEnergyBalanceValue) kcal")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(viewModel.isEnergyRemaining ? .green : .red)

                        let label = viewModel.energyBalanceLabelText
                            .replacingOccurrences(of: "kcal ", with: "")
                            .capitalized

                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(
                                viewModel.isEnergyRemaining
                                ? .green.opacity(0.9)
                                : .red.opacity(0.9)
                            )
                    }
                }
                .frame(width: 110, height: 110)

                VStack(spacing: 10) {

                    // Burned
                    VStack(alignment: .leading, spacing: 8) {

                        HStack {
                            Text("Burned")
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

                        Text("\(totalBurned.formatted(.number.grouping(.automatic))) kcal")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.Glu.primaryBlue)

                        HStack {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                            Spacer()
                            Text(viewModel.formattedActiveEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }

                        HStack {
                            Text("Resting")
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

                    // Intake
                    VStack(alignment: .leading, spacing: 8) {

                        HStack {
                            Text("Intake")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
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
                            Text("Nutrition")
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
                                        Color(.systemGray6),
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
            appState.currentStatsScreen = .calories
        }
    }
}

// MARK: - Insight (TODAY only)

private extension NutritionOverviewViewV1 {

    var insightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insight")
                .font(.headline)
                .foregroundStyle(Color.Glu.primaryBlue)

            Text(
                viewModel.insightText.isEmpty
                ? "No nutrition data recorded yet today."
                : viewModel.insightText
            )
            .font(.subheadline)
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

// MARK: - Preview (minimal, ohne zusätzliche Layout-Mods)

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
