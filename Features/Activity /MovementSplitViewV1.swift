//
//  MovementSplitViewV1.swift
//  GluVibProbe
//
//  Activity V1 — Movement Split Detail Screen
//
//  Purpose
//  - Renders the movement split metric detail screen for the Activity domain.
//  - Shows the combined movement split hint state, KPI content, daily chart,
//    and the shared activity metric chip navigation.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → MovementSplitViewModelV1 (mapping / formatting) → MovementSplitViewV1 (render only)
//
//  Key Connections
//  - MovementSplitViewModelV1: provides today hint state, KPI texts, chart input data and active-source hint text.
//  - HealthStore: provides the central activity badge / attention sources and refresh entry points.
//  - AppState: handles navigation and metric routing.
//  - ActivitySectionCardScaledV2: shared activity card shell for chips, KPIs and charts.
//  - MovementSplitDailyChart: renders the custom daily stacked chart for the metric.
//  - L10n: localized titles and labels for the movement split metric.
//

import SwiftUI

struct MovementSplitViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: MovementSplitViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: MovementSplitViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: MovementSplitViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? { // 🟨 UPDATED
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.MovementSplit.hintNoDataOrPermission
        case .noTodayData:
            return L10n.MovementSplit.hintNoToday
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetricDetailScaffold(
            headerTitle: L10n.Common.activity,
            headerTint: Color.Glu.activityDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshActivity(.pullToRefresh)
            },
            showsPermissionBadge: settings.showPermissionWarnings && healthStore.movementSplitAnyAttentionForBadgesV1, // 🟨 UPDATED
            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.activityDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {

                // Today info / hint text from ViewModel
                if let hint = localizedTodayHint { // 🟨 UPDATED
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                // Shared Activity metric card shell
                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.MovementSplit.title,
                    kpiTitle: L10n.MovementSplit.kpiToday,
                    kpiTargetText: "–",
                    kpiCurrentText: "–",
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,
                    last90DaysData: viewModel.movementSplitDaily365.map { entry in
                        DailyStepsEntry(date: entry.date, steps: max(0, entry.activeMinutes))
                    },
                    periodAverages: [],
                    monthlyData: [],
                    dailyScale: MetricScaleHelper.scale([], for: .exerciseMinutes),
                    periodScale: MetricScaleHelper.scale([], for: .exerciseMinutes),
                    monthlyScale: MetricScaleHelper.scale([], for: .exerciseMinutes),
                    goalValue: nil,
                    onMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: false,
                    showsMonthlyChart: false,
                    customKpiContent: AnyView(
                        HStack(alignment: .top, spacing: 10) {
                            KPICard(title: L10n.MovementSplit.sleepToday, valueText: viewModel.kpiSleepText, unit: nil, domain: .activity)
                            KPICard(title: L10n.MovementSplit.activeToday, valueText: viewModel.kpiActiveText, unit: nil, domain: .activity)
                            KPICard(title: L10n.MovementSplit.notActive, valueText: viewModel.kpiSedentaryText, unit: nil, domain: .activity)
                        }
                        .padding(.bottom, 10)
                    ),
                    customChartContent: nil,
                    customDailyChartBuilder: { period, filtered in
                        let calendar = Calendar.current
                        let allowedDays = Set(filtered.map { calendar.startOfDay(for: $0.date) })

                        let slice = viewModel.movementSplitDaily365
                            .filter { allowedDays.contains(calendar.startOfDay(for: $0.date)) }
                            .sorted { $0.date < $1.date }

                        let barWidth: CGFloat = {
                            switch period {
                            case .days7:  return 16
                            case .days14: return 12
                            case .days30: return 8
                            case .days90: return 4
                            }
                        }()

                        return AnyView(
                            MovementSplitDailyChart(data: slice, barWidth: barWidth)
                        )
                    },
                    dailyScaleType: nil,
                    showsWarningBadgeForMetric: { metric in
                        guard settings.showPermissionWarnings else { return false }

                        switch metric {
                        case L10n.Steps.title:
                            return healthStore.stepsAnyAttentionForBadgesV1
                        case L10n.WorkoutMinutes.title:
                            return healthStore.workoutMinutesAnyAttentionForBadgesV1
                        case L10n.ActivityEnergy.title:
                            return healthStore.activeEnergyAnyAttentionForBadgesV1
                        case L10n.MovementSplit.title:
                            return healthStore.movementSplitAnyAttentionForBadgesV1 // 🟨 UPDATED
                        default:
                            return false
                        }
                    }
                )

                if let hint = viewModel.activeSourceHintText {
                    MovementSplitHintOutsideCard(text: hint)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

// ============================================================
// MARK: - Helper View
// ============================================================

private struct MovementSplitHintOutsideCard: View {

    let text: String

    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            guard !isVisible else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                isVisible = true
            }
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("MovementSplitViewV1 – Activity (Hint: Exercise)") {
    let previewStore = HealthStore(isPreview: true)

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let entries: [DailyMovementSplitEntry] = [
        DailyMovementSplitEntry(
            date: calendar.date(byAdding: .day, value: -2, to: today)!,
            sleepMorningMinutes: 0,
            sleepEveningMinutes: 420,
            sedentaryMinutes: 600,
            activeMinutes: 120
        ),
        DailyMovementSplitEntry(
            date: calendar.date(byAdding: .day, value: -1, to: today)!,
            sleepMorningMinutes: 0,
            sleepEveningMinutes: 390,
            sedentaryMinutes: 720,
            activeMinutes: 90
        ),
        DailyMovementSplitEntry(
            date: today,
            sleepMorningMinutes: 0,
            sleepEveningMinutes: 360,
            sedentaryMinutes: 780,
            activeMinutes: 60
        )
    ]

    previewStore.movementSplitDaily365 = entries
    previewStore.todaySleepSplitMinutes = 360
    previewStore.todayMoveMinutes = 60
    previewStore.todaySedentaryMinutes = 780
    previewStore.movementSplitActiveSourceTodayV1 = .exerciseMinutes

    let previewVM = MovementSplitViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return MovementSplitViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
