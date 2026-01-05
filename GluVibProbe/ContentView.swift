//
//  ContentView.swift
//  GluVibProbe
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @State private var selectedTab: GluTab

    private let settings = SettingsModel.shared
    @State private var showUnsavedAlert: Bool = false

    // Orientation detection am Root (iOS 16 safe)
    @Environment(\.verticalSizeClass) private var vSizeClass
    private var isLandscape: Bool { vSizeClass == .compact }

    // Root rule – wann darf MainChart-Landscape übernehmen?
    // - Nur im Home-Tab
    // - Nur wenn kein Metabolic Router Screen aktiv ist
    private var shouldShowMainChartLandscape: Bool {
        isLandscape && selectedTab == .home && appState.currentStatsScreen == .none
    }

    // MARK: - Init
    init(startTab: GluTab = .home) {
        _selectedTab = State(initialValue: startTab)
    }

    // MARK: - Body
    var body: some View {

        // ============================================================
        // Root Landscape takeover (TabBar wird NICHT gerendert)
        // ============================================================
        if shouldShowMainChartLandscape {

            MainChartLandscapeViewV1()
                .environmentObject(settings)
                .tint(Color.Glu.primaryBlue)

        } else {

            VStack(spacing: 0) {

                ZStack {

                    // ---------------------------------------------------------
                    // Global Router by StatsScreen (Metabolic entry)
                    // ---------------------------------------------------------
                    switch appState.currentStatsScreen {

                    // !!! UPDATED: include .timeInRange + .gmi
                    case .metabolicOverview,
                         .bolus,
                         .basal,
                         .bolusBasalRatio,
                         .carbsBolusRatio,
                         .timeInRange,
                         .gmi:
                        MetabolicDashboardView()

                    default:
                        // -----------------------------------------------------
                        // Existing Tab Content
                        // -----------------------------------------------------
                        switch selectedTab {
                        case .activity:  activityRootView
                        case .body:      bodyRootView
                        case .nutrition: nutritionRootView
                        case .home:      HomeView()
                        case .history:   HistoryView()
                        case .settings:  SettingsView(startDomain: .units)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ---------------------------------------------------------
                // BottomTabBar nur im "normal mode"
                // ---------------------------------------------------------
                GluBottomTabBar(
                    selectedTab: Binding(
                        get: { selectedTab },
                        set: { newValue in handleTabSelection(newValue) }
                    )
                )
            }
            .alert(
                "Unsaved Settings",
                isPresented: $showUnsavedAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("""
                You have unsaved changes.
                Please tap “Save Settings” before leaving this screen.
                """)
            }
            .tint(Color.Glu.primaryBlue)
        }
    }

    // MARK: - Activity Root

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

        // Metabolic States ignorieren (compile-safe)
        // !!! UPDATED: include .timeInRange + .gmi
        case .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,
             .gmi:
            ActivityOverviewViewV1()

        default:
            ActivityOverviewViewV1()
        }
    }

    // MARK: - Body Root

    @ViewBuilder
    private var bodyRootView: some View {
        switch appState.currentStatsScreen {

        case .sleep,
             .weight,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            BodyDashboardView()

        // Metabolic States ignorieren (compile-safe)
        // !!! UPDATED: include .timeInRange + .gmi
        case .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,
             .gmi:
            BodyOverviewViewV1()

        default:
            BodyOverviewViewV1()
        }
    }

    // MARK: - Nutrition Root

    @ViewBuilder
    private var nutritionRootView: some View {
        switch appState.currentStatsScreen {

        case .nutritionOverview, .none:
            NutritionOverviewViewV1()

        case .carbs, .protein, .fat, .calories:
            NutritionDashboardView()

        // Metabolic States ignorieren (compile-safe)
        // !!! UPDATED: include .timeInRange + .gmi
        case .metabolicOverview,
             .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,
             .gmi:
            NutritionOverviewViewV1()

        default:
            NutritionOverviewViewV1()
        }
    }

    // MARK: - Tab Handling

    private func handleTabSelection(_ newTab: GluTab) {

        // Block leaving Settings with unsaved changes
        if selectedTab == .settings,
           newTab != .settings,
           settings.hasUnsavedChanges {
            showUnsavedAlert = true
            return
        }

        selectedTab = newTab

        // Domain start screens
        switch newTab {

        case .nutrition:
            appState.currentStatsScreen = .nutritionOverview

        case .activity:
            appState.currentStatsScreen = .none

        case .body:
            appState.currentStatsScreen = .none

        case .home:
            appState.currentStatsScreen = .none

        case .history:
            appState.currentStatsScreen = .none

        case .settings:
            break
        }
    }
}

// MARK: - Preview

#Preview("ContentView – Home Tab") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    ContentView(startTab: .home)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
