//
//  ContentView.swift
//  GluVibProbe
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @State private var selectedTab: GluTab

    @Environment(\.verticalSizeClass) private var vSizeClass
    private var isLandscape: Bool { vSizeClass == .compact }

    private var showsHomeTab: Bool { settings.hasCGM }

    private var shouldShowMainChartLandscape: Bool {
        isLandscape &&
        selectedTab == .home &&
        appState.currentStatsScreen == .none &&
        showsHomeTab
    }

    // UPDATED: kept locally for sheet detent selection (single account sheet presenter)
    @State private var accountSheetDetent: PresentationDetent = .large

    init(startTab: GluTab = .home) {
        _selectedTab = State(initialValue: startTab)
    }

    var body: some View {

        Group { // UPDATED: ensures modifiers attach to a concrete view instance

            if shouldShowMainChartLandscape {

                MainChartLandscapeViewV1()
                    .environmentObject(settings)
                    .tint(Color.Glu.primaryBlue)

            } else {

                VStack(spacing: 0) {

                    // ====================================================
                    // MARK: - Main Content Routing
                    // ====================================================

                    ZStack {

                        switch appState.currentStatsScreen {

                        // Metabolic Detail / Overview
                        case .metabolicOverview,
                             .bolus,
                             .basal,
                             .bolusBasalRatio,
                             .carbsBolusRatio,
                             .timeInRange,
                             .range,
                             .gmi,
                             .SD,
                             .ig,
                             .CV:
                            MetabolicDashboardView()

                        // Root per Tab
                        default:
                            switch selectedTab {

                            case .activity:
                                activityRootView

                            case .body:
                                bodyRootView

                            case .nutrition:
                                nutritionRootView

                            case .home:
                                if showsHomeTab {
                                    PremiumOverviewViewV1()
                                } else {
                                    activityRootView
                                }

                            case .history:
                                HistoryOverviewViewV1()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // ====================================================
                    // MARK: - Reactive Tab Adjustments
                    // ====================================================

                    .onChange(of: settings.hasCGM) { hasCGM in
                        if !hasCGM, selectedTab == .home {
                            selectedTab = .activity
                            appState.currentStatsScreen = .none
                        }
                    }

                    .onChange(of: appState.requestedTab) { newTab in
                        guard let newTab else { return }

                        if newTab == .home, !showsHomeTab {
                            selectedTab = .activity
                            appState.currentStatsScreen = .none
                            appState.requestedTab = nil
                            return
                        }

                        selectedTab = newTab

                        if appState.currentStatsScreen == .none {
                            switch newTab {
                            case .nutrition:
                                appState.currentStatsScreen = .nutritionOverview
                            case .activity, .body, .home, .history:
                                appState.currentStatsScreen = .none
                            }
                        }

                        appState.requestedTab = nil
                    }

                    // ====================================================
                    // MARK: - Bottom Tab Bar (NO Settings)
                    // ====================================================

                    GluBottomTabBar(
                        selectedTab: Binding(
                            get: { selectedTab },
                            set: { handleTabSelection($0) }
                        ),
                        showsHomeTab: showsHomeTab
                    )
                }
                .tint(Color.Glu.primaryBlue)
            }
        }
        // ============================================================
        // MARK: - Account Sheet Presenter (SINGLE ROOT STACK)
        // ============================================================
        .sheet(isPresented: $appState.isAccountSheetPresented) {
            AccountSheetRootView()
                .environmentObject(appState)
                .environmentObject(healthStore)
                .environmentObject(settings)
                .tint(Color("GluPrimaryBlue")) // UPDATED: force correct tint from first frame
                .presentationDetents([.medium, .large], selection: $accountSheetDetent)
                .presentationDragIndicator(.visible)
        }

        // ============================================================
        // MARK: - Serial Handoff: Account -> Settings (prevents "everything disappears")
        // ============================================================
        .onChange(of: appState.isAccountSheetPresented) { isPresented in // UPDATED
            guard isPresented == false else { return }                  // UPDATED
            guard let pending = appState.pendingSettingsStartDomain else { return } // UPDATED

            appState.settingsStartDomain = pending                      // UPDATED
            appState.pendingSettingsStartDomain = nil                   // UPDATED

            DispatchQueue.main.async {                                  // UPDATED
                appState.isSettingsSheetPresented = true                // UPDATED
            }
        }

        // ============================================================
        // MARK: - Settings Sheet Presenter (SINGLE ROOT STACK)
        // ============================================================
        .sheet(isPresented: $appState.isSettingsSheetPresented) {
            SettingsView()                             // ✅ keine Parameter
                .environmentObject(appState)
                .environmentObject(healthStore)
                .environmentObject(settings)
                .tint(Color.Glu.primaryBlue)
        }
    }

    // ============================================================
    // MARK: - Activity Root
    // ============================================================

    @ViewBuilder
    private var activityRootView: some View {
        switch appState.currentStatsScreen {

        case .steps,
             .activityEnergy,
             .activityExerciseMinutes,
             .movementSplit,
             .moveTime,
             .workoutMinutes:
            ActivityDashboardView()

        default:
            ActivityOverviewViewV1()
        }
    }

    // ============================================================
    // MARK: - Body Root
    // ============================================================

    @ViewBuilder
    private var bodyRootView: some View {
        switch appState.currentStatsScreen {

        case .sleep,
             .weight,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            BodyDashboardView()

        default:
            BodyOverviewViewV1()
        }
    }

    // ============================================================
    // MARK: - Nutrition Root
    // ============================================================

    @ViewBuilder
    private var nutritionRootView: some View {
        switch appState.currentStatsScreen {

        case .nutritionOverview, .none:
            NutritionOverviewViewV1()

        case .carbs, .protein, .fat, .calories:
            NutritionDashboardView()

        default:
            NutritionOverviewViewV1()
        }
    }

    // ============================================================
    // MARK: - Tab Handling
    // ============================================================

    private func handleTabSelection(_ newTab: GluTab) {

        if newTab == .home, !showsHomeTab {
            selectedTab = .activity
            appState.currentStatsScreen = .none
            return
        }

        selectedTab = newTab

        switch newTab {
        case .nutrition:
            appState.currentStatsScreen = .nutritionOverview
        case .activity, .body, .home, .history:
            appState.currentStatsScreen = .none
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ContentView – Home Tab") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    ContentView(startTab: .home)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
