//
//  ContentView.swift
//  GluVibProbe
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @State private var selectedTab: GluTab

    private let settings = SettingsModel.shared
    @State private var showUnsavedAlert: Bool = false

    // Standard-Init
    init(startTab: GluTab = .home) {
        _selectedTab = State(initialValue: startTab)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Oberer Inhaltsbereich
            ZStack {
                switch selectedTab {

                case .activity:
                    activityRootView          // 👈 Activity: Overview ODER Dashboard

                case .body:
                    bodyRootView              // 👈 Body: Overview ODER Dashboard

                case .nutrition:
                    nutritionRootView         // 👈 Nutrition: Overview ODER Dashboard

                case .home:
                    HomeView()

                case .history:
                    HistoryView()

                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Untere Tab-Bar
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

    // MARK: - Activity Root Handling

    /// Steuert, ob im Activity-Tab die Overview oder das Dashboard angezeigt wird
    @ViewBuilder
    private var activityRootView: some View {
        switch appState.currentStatsScreen {

        case .steps, .activityEnergy:
            // 👉 Detail-Screen (Steps/Activity Energy)
            ActivityDashboardView()

        default:
            // 👉 Einstieg: Activity Overview
            ActivityOverviewView()
        }
    }

    // MARK: - Body Root Handling

    /// Steuert, ob im Body-Tab die Overview oder das Dashboard angezeigt wird
    @ViewBuilder
    private var bodyRootView: some View {
        switch appState.currentStatsScreen {

        case .sleep,
             .weight,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            // 👉 Alle Body-Detail-Screens (5 Metriken)
            BodyDashboardView()

        default:
            // 👉 Einstieg: Body Overview
            BodyOverviewView()
        }
    }

    // MARK: - Nutrition Root Handling

    /// Steuert, ob im Nutrition-Tab die Overview oder das Nutrition-Dashboard angezeigt wird
    @ViewBuilder
    private var nutritionRootView: some View {
        switch appState.currentStatsScreen {

        case .nutritionOverview, .none:
            // 👉 Overview
            NutritionOverviewView()

        case .carbs, .protein, .fat, .calories:
            // 👉 Detail-Dashboard mit SectionCardScaled etc.
            NutritionDashboardView()

        default:
            // Fallback – sicherheitshalber Overview
            NutritionOverviewView()
        }
    }

    // MARK: - Tab Handling

    private func handleTabSelection(_ newTab: GluTab) {

        // Block: Settings mit unsaved changes verlassen?
        if selectedTab == .settings,
           newTab != .settings,
           settings.hasUnsavedChanges {
            showUnsavedAlert = true
            return
        }

        // Tab wechseln
        selectedTab = newTab

        // Domain-spezifische "Start-Screens" setzen
        switch newTab {

        case .nutrition:
            // 👉 Immer mit Overview starten
            appState.currentStatsScreen = .nutritionOverview

        case .activity:
            // 🔹 ÄNDERUNG:
            // Bisher: appState.currentStatsScreen = .steps
            // → hat direkt das Activity-Dashboard geöffnet.
            // Jetzt: Activity startet wie Body/Nutrition mit Overview.
            appState.currentStatsScreen = .none

        case .body:
            // 👉 Immer mit Overview starten (jede andere Case ⇒ Overview)
            appState.currentStatsScreen = .none

        default:
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
}
