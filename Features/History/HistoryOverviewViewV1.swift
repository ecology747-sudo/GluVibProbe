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

    // ============================================================
    // MARK: - History Metric Picker (MainChart-style)
    // ============================================================

    @State private var showActivity: Bool = true
    @State private var showCarbs: Bool = true
    @State private var showWeight: Bool = true
    @State private var showBolus: Bool = true
    @State private var showBasal: Bool = true
    @State private var showCGM: Bool = true              // controls glucose markers + CGM-dependent UI

    private var isTherapyEnabled: Bool {                 // matches MainChart gating
        settings.hasCGM && settings.isInsulinTreated
    }

    // UPDATED: must match OverviewHeader height so pinned header sticks BELOW it
    private let overviewHeaderHeight: CGFloat = 44

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
                    // Sticky Metric-Picker via pinned section header (Apple-conform)
                    LazyVStack(spacing: contentSpacing, pinnedViews: [.sectionHeaders]) {

                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: HistoryScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)

                        Section {
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
                        } header: {
                            historyMetricPicker
                                .padding(.horizontal, 16)
                                .padding(.top, 2)
                                .padding(.bottom, pickerBottomPadding)
                                .background(pinnedHeaderBackground)
                        }
                    }
                    // UPDATED: tighter top padding because safeAreaInset reserves the header height
                    .padding(.top, topContentPadding)
                    .padding(.bottom, 24)
                }
                // UPDATED: reserve space INSIDE the scroll view so pinned header never hides under OverviewHeader
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: overviewHeaderHeight)
                }
                .refreshable {
                    await healthStore.refreshHistory(.pullToRefresh)
                }
                .onPreferenceChange(HistoryScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                .onAppear {
                    applyGatingIfNeeded()
                }
                .onChange(of: settings.hasCGM) { _ in
                    applyGatingIfNeeded()
                }
                .onChange(of: settings.isInsulinTreated) { _ in
                    applyGatingIfNeeded()
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

    // ============================================================
    // MARK: - Layout Helpers (Sticky Picker + Tight Spacing)
    // ============================================================

    private var topContentPadding: CGFloat {
        // UPDATED: when only 1 picker row, move content up (less air above chips)
        settings.hasCGM ? 12 : 6
    }

    private var contentSpacing: CGFloat {
        // keep sections visually compact when CGM is OFF (1 row)
        settings.hasCGM ? 16 : 10
    }

    private var pickerBottomPadding: CGFloat {
        // remove “empty line” feeling when only 1 row
        settings.hasCGM ? 6 : 0
    }

    private var pinnedHeaderBackground: some View {
        Rectangle()
            .fill(Color.white.opacity(0.92))
            .blur(radius: 10)
    }

    // ============================================================
    // MARK: - Picker UI (MainChart-style)
    // ============================================================

    private var historyMetricPicker: some View {
        VStack(alignment: .leading, spacing: 12) {

            GeometryReader { geo in
                let spacing: CGFloat = 12
                let columns: CGFloat = 3
                let chipWidth = (geo.size.width - spacing * (columns - 1)) / columns

                VStack(alignment: .leading, spacing: 12) {

                    // Row 1 (3 fixed)
                    HStack(spacing: spacing) {
                        historyChip("Activity", isOn: $showActivity, accent: Color.Glu.activityDomain)
                            .frame(width: chipWidth)

                        historyChip("Carbs", isOn: $showCarbs, accent: Color.Glu.nutritionDomain)
                            .frame(width: chipWidth)

                        historyChip("Weight", isOn: $showWeight, accent: Color.Glu.bodyDomain)
                            .frame(width: chipWidth)
                    }

                    // Row 2 renders ONLY when CGM is enabled
                    if settings.hasCGM {
                        HStack(spacing: spacing) {

                            if isTherapyEnabled {

                                historyChip("Bolus", isOn: $showBolus, accent: Color("acidBolusDarkGreen"))
                                    .frame(width: chipWidth)

                                historyChip("Basal", isOn: $showBasal, accent: Color("GluBasalMagenta").opacity(0.5))
                                    .frame(width: chipWidth)

                                historyChip("CGM", isOn: $showCGM, accent: Color.Glu.acidCGMRed)
                                    .frame(width: chipWidth)

                            } else {

                                Color.clear.frame(width: chipWidth, height: 1)

                                historyChip("CGM", isOn: $showCGM, accent: Color.Glu.acidCGMRed)
                                    .frame(width: chipWidth)

                                Color.clear.frame(width: chipWidth, height: 1)
                            }
                        }
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
            }
            // Dynamic height (1 row when CGM OFF, 2 rows when CGM ON)
            .frame(height: settings.hasCGM ? 82 : 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyChip(_ title: String, isOn: Binding<Bool>, accent: Color) -> some View {
        let isActive = isOn.wrappedValue

        return Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(HistoryMetricChipLookalikeStyle(accent: accent, isActive: isActive))
    }

    private struct HistoryMetricChipLookalikeStyle: ButtonStyle {

        let accent: Color
        let isActive: Bool

        func makeBody(configuration: Configuration) -> some View {

            let visualActive = isActive || configuration.isPressed

            let strokeColor: Color = visualActive
            ? Color.white.opacity(0.90)
            : accent.opacity(0.90)

            let lineWidth: CGFloat = visualActive ? 1.6 : 1.2

            let backgroundFill: some ShapeStyle = visualActive
            ? LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            let shadowOpacity: Double = visualActive ? 0.25 : 0.15
            let shadowRadius: CGFloat = visualActive ? 4 : 2.5
            let shadowYOffset: CGFloat = visualActive ? 2 : 1.5

            return configuration.label
                .background(Capsule().fill(backgroundFill))
                .overlay(Capsule().stroke(strokeColor, lineWidth: lineWidth))
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
                .foregroundStyle(visualActive ? Color.white : Color.Glu.primaryBlue.opacity(0.95))
                .scaleEffect(visualActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: visualActive)
        }
    }

    // ============================================================
    // MARK: - Apply Gating (Display-only)
    // ============================================================

    // NEW: remembers if we forced CGM off due to hasCGM == false
    @State private var didForceDisableCGM: Bool = false

    @MainActor
    private func applyGatingIfNeeded() {

        // If CGM is OFF, force-disable CGM + therapy and remember it was forced
        if !settings.hasCGM {
            if showCGM { didForceDisableCGM = true }   // NEW
            showCGM = false
            showBolus = false
            showBasal = false
            return
        }

        // If CGM is back ON and we previously forced CGM off, restore default ON
        if settings.hasCGM, didForceDisableCGM {       // NEW
            showCGM = true
            didForceDisableCGM = false
        }

        // If Therapy is NOT enabled, force therapy chips OFF
        if !isTherapyEnabled {
            showBolus = false
            showBasal = false
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

        case .weight:
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

    // ============================================================
    // MARK: - Sectioning (10 days) + Metric Filtering
    // ============================================================

    private var sectionedEvents: [HistoryDaySection] {

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        // display-only filter (visibility) + CGM marker stripping
        let filtered = filteredEventsForDisplay(viewModel.events)

        let grouped = Dictionary(grouping: filtered) { e in
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

    private func filteredEventsForDisplay(_ input: [HistoryListEvent]) -> [HistoryListEvent] {

        let allowCGMMarkers = settings.hasCGM && showCGM

        return input.compactMap { e in

            // 1) Visibility per metric toggle + premium gating (DISPLAY ONLY)
            switch e.metricRoute {

            case .workoutMinutes:
                guard showActivity else { return nil }

            case .carbs:
                guard showCarbs else { return nil }

            case .weight:
                guard showWeight else { return nil }

            case .bolus:
                guard isTherapyEnabled, showBolus else { return nil }

            case .basal:
                guard isTherapyEnabled, showBasal else { return nil }
            }

            // 2) If CGM OFF (or CGM chip OFF), strip markers everywhere
            if allowCGMMarkers {
                return e
            } else {
                let m = e.cardModel
                let stripped = HistoryEventRowCardModel(
                    domain: m.domain,
                    titleText: m.titleText,
                    detailText: m.detailText,
                    timeText: m.timeText,
                    glucoseMarkers: [],
                    contextHint: m.contextHint
                )

                return HistoryListEvent(
                    timestamp: e.timestamp,
                    cardModel: stripped,
                    metricRoute: e.metricRoute,
                    overviewRoute: e.overviewRoute
                )
            }
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
