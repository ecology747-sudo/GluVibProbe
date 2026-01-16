//
//  HistoryOverviewViewV1.swift
//  GluVibProbe
//
//  HISTORY — Overview Wrapper (V1)
//  - NO Pager
//  - Neutral theme: White + PrimaryBlue
//  - Header: "History" only (no subtitle)
//  - Content: embeds HistoryView (rows-only)
//  - Uses OverviewHeader for exact project-consistent header placement
//

import SwiftUI

// MARK: - Scroll Offset Preference (Sticky Header)

private struct HistoryScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - History Overview (V1)

struct HistoryOverviewViewV1: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @StateObject private var viewModel = HistoryViewModelV1()

    // Sticky Header
    @State private var hasScrolled: Bool = false
    @State private var didInitialLoad: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.primaryBlue.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ZStack(alignment: .top) {

                ScrollView {
                    VStack(spacing: 16) {

                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: HistoryScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)

                        // ✅ Embedding the rows-only HistoryView (no duplicated layout/UI logic elsewhere)
                        HistoryView(
                            sections: sectionedEvents,
                            isChartEnabled: settings.hasCGM,
                            onTapDayChart: { dayStart in
                                routeToMainChart(for: dayStart)
                            },
                            onTapMetric: { route in
                                routeToMetric(route)
                            },
                            onTapOverview: { route in
                                routeToOverview(route)
                            }
                        )
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await healthStore.refreshHistory(.pullToRefresh)
                }
                .onPreferenceChange(HistoryScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }

                OverviewHeader(
                    title: "History",
                    subtitle: nil,
                    tintColor: Color.Glu.primaryBlue,
                    hasScrolled: hasScrolled
                )
            }
        }
        .onAppear {
            viewModel.attach(to: healthStore)
        }
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            await healthStore.refreshHistory(.navigation)
        }
    }

    // MARK: - Routing

    private func routeToMainChart(for dayStart: Date) {
        guard settings.hasCGM else { return }

        let offset = dayOffsetRelativeToToday(dayStart: dayStart)
        healthStore.mainChartSelectedDayOffsetV1 = offset

        appState.currentStatsScreen = .none
        appState.requestedTab = .home
    }

    private func routeToOverview(_ route: HistoryOverviewRoute) {
        switch route {
        case .activityOverview:
            appState.currentStatsScreen = .none
            appState.requestedTab = .activity

        case .bodyOverview:
            appState.currentStatsScreen = .none
            appState.requestedTab = .body

        case .nutritionOverview:
            appState.currentStatsScreen = .nutritionOverview
            appState.requestedTab = .nutrition

        case .metabolicPremiumOverview:
            guard settings.hasCGM else { return }
            appState.currentStatsScreen = .none
            appState.requestedTab = .home
        }
    }

    private func routeToMetric(_ route: HistoryMetricRoute) {
        switch route {
        case .workoutMinutes:
            appState.currentStatsScreen = .workoutMinutes
            appState.requestedTab = .activity

        case .carbs:
            appState.currentStatsScreen = .carbs
            appState.requestedTab = .nutrition

        case .bolus:
            guard settings.hasCGM else { return }
            appState.currentStatsScreen = .bolus
            appState.requestedTab = .home

        case .basal:
            guard settings.hasCGM else { return }
            appState.currentStatsScreen = .basal
            appState.requestedTab = .home

        case .weight:                          // ✅ NEW
                    appState.currentStatsScreen = .weight
                    appState.requestedTab = .body
        }
    }

    private func dayOffsetRelativeToToday(dayStart: Date) -> Int {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: dayStart)
        let delta = cal.dateComponents([.day], from: todayStart, to: target).day ?? 0
        return min(0, max(-9, delta))
    }

    // MARK: - Sectioning (10 days)

    private var sectionedEvents: [HistoryDaySection] {

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        let grouped = Dictionary(grouping: viewModel.events) { e in
            cal.startOfDay(for: e.timestamp)
        }

        return grouped.keys
            .sorted(by: >)
            .compactMap { day in
                guard let items = grouped[day], !items.isEmpty else { return nil }

                let title: String
                if day == today { title = "Today" }
                else if day == yesterday { title = "Yesterday" }
                else {
                    let df = DateFormatter()
                    df.dateStyle = .medium
                    df.timeStyle = .none
                    title = df.string(from: day)
                }

                return HistoryDaySection(
                    date: day,
                    title: title,
                    items: items.sorted { $0.timestamp > $1.timestamp }
                )
            }
    }
}

// MARK: - Preview

#Preview("History Overview V1") {
    HistoryOverviewViewV1()
        .environmentObject(AppState())
        .environmentObject(HealthStore.preview())
        .environmentObject(SettingsModel.shared)
}
