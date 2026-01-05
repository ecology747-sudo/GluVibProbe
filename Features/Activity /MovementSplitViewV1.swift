//
//  MovementSplitViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct MovementSplitViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: MovementSplitViewModelV1

    let onMetricSelected: (String) -> Void

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

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Activity",
            headerTint: Color.Glu.activityDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                await healthStore.refreshActivity(.pullToRefresh)
            },
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

                // ------------------------------------------------------------
                // Card
                // ------------------------------------------------------------
                ActivitySectionCardScaledV2(
                    sectionTitle: "",
                    title: "Movement Split",

                    // Standard KPI-Inputs bleiben "neutral", weil wir customKpiContent nutzen
                    kpiTitle: "Today",
                    kpiTargetText: "–",
                    kpiCurrentText: "–",
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    // ✅ TRICK wie Steps: Period Picker braucht "daily series" → wir geben Dates mit (activeMinutes als steps)
                    last90DaysData: viewModel.movementSplitDaily365.map { entry in
                        DailyStepsEntry(date: entry.date, steps: max(0, entry.activeMinutes))
                    },
                    periodAverages: [],
                    monthlyData: [],
                    dailyScale: MetricScaleHelper.scale([], for: .exerciseMinutes),
                    periodScale: MetricScaleHelper.scale([], for: .exerciseMinutes),
                    monthlyScale: MetricScaleHelper.scale([], for: .exerciseMinutes),
                    goalValue: nil,

                    onMetricSelected: onMetricSelected,
                    metrics: AppState.activityVisibleMetrics,
                    showsDailyChart: true,
                    showsPeriodChart: false,
                    showsMonthlyChart: false,

                    // ✅ KPI: nur KPIs (Hint ist OUTSIDE Card)
                    customKpiContent: AnyView(
                        HStack(alignment: .top, spacing: 10) {
                            KPICard(title: "Sleep Today",  valueText: viewModel.kpiSleepText,     unit: nil, domain: .activity)
                            KPICard(title: "Active Today", valueText: viewModel.kpiActiveText,    unit: nil, domain: .activity)
                            KPICard(title: "Not Active",   valueText: viewModel.kpiSedentaryText, unit: nil, domain: .activity)
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

                    dailyScaleType: nil
                )

                // ------------------------------------------------------------
                // ✅ Hint OUTSIDE Card (linksbündig zur Card-Kante)
                // ------------------------------------------------------------
                if let hint = viewModel.activeSourceHintText {
                    MovementSplitHintOutsideCard(text: hint)
                        .padding(.top, 2)
                }
            }
            // ✅ Wichtig: erzwingt “hart” linksbündig für ALLE Kinder (Card + Hint)
            .frame(maxWidth: .infinity, alignment: .leading) // !!! FIX
        }
        .task {
            await healthStore.refreshActivity(.navigation)
        }
    }
}

// MARK: - Hint (Outside Card + Fade-In)

private struct MovementSplitHintOutsideCard: View {

    let text: String
    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))

            Text(text)
                .font(.subheadline.weight(.semibold))          // ✅ etwas größer
                .foregroundStyle(Color.Glu.primaryBlue)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)                               // ✅ hält’s links ruhig
        }
        .frame(maxWidth: .infinity, alignment: .leading)       // ✅ harte Leading-Führung
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            guard !isVisible else { return }
            withAnimation(.easeInOut(duration: 0.28)) {        // ✅ leichtes Fade-In
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview("MovementSplitViewV1 – Activity (Hint: Exercise)") {
    // ✅ Preview-Store (keine echten HK-Queries)
    let previewStore = HealthStore(isPreview: true)

    // ✅ Dummy-Day (Today) + ein bisschen History, damit dein Chart/Picker was sieht
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

    // ✅ SSoT: Series + Today KPIs
    previewStore.movementSplitDaily365 = entries
    previewStore.todaySleepSplitMinutes = 360
    previewStore.todayMoveMinutes = 60
    previewStore.todaySedentaryMinutes = 780

    // ✅ Hint erzwingen (nicht StandTime)
    previewStore.movementSplitActiveSourceTodayV1 = .exerciseMinutes

    let previewVM = MovementSplitViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return MovementSplitViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
