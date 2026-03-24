//
//  ContentView.swift
//  GluVibProbe
//

import SwiftUI
import UIKit
import OSLog

struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: GluTab
    @State private var showStartupScreen = true
    @State private var hasFinishedStartupDelay = false

    @Environment(\.verticalSizeClass) private var vSizeClass
    private var isLandscape: Bool { vSizeClass == .compact }

    private var showsHomeTab: Bool { settings.hasCGM && settings.hasMetabolicPremiumEffective }

    private var shouldShowMainChartLandscape: Bool {
        isLandscape &&
        selectedTab == .home &&
        appState.currentStatsScreen == .none &&
        showsHomeTab &&
        !appState.isMetabolicReportPresented
    }

    @State private var accountSheetDetent: PresentationDetent = .large

    init(startTab: GluTab = .home) {
        _selectedTab = State(initialValue: startTab)
    }

    var body: some View {

        ZStack {

            Group {

                if !settings.hasCompletedOnboarding {
                    OnboardingFlowView()
                } else {

                    if shouldShowMainChartLandscape {

                        MainChartLandscapeViewV1()
                            .environmentObject(settings)
                            .tint(Color.Glu.primaryBlue)

                    } else {

                        VStack(spacing: 0) {

                            ZStack {

                                switch appState.currentStatsScreen {

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

                            .onChange(of: settings.hasCGM) { _ in
                                GluLog.ui.notice("settings.hasCGM changed | showsHomeTab=\(showsHomeTab, privacy: .public)")
                                if !showsHomeTab, selectedTab == .home {
                                    selectedTab = .activity
                                    appState.currentStatsScreen = .none
                                    GluLog.ui.notice("home tab fallback applied | reason=hasCGMChanged")
                                }
                            }

                            .onChange(of: settings.isPremiumEnabled) { _ in
                                GluLog.ui.notice("settings.isPremiumEnabled changed | showsHomeTab=\(showsHomeTab, privacy: .public)")
                                if !showsHomeTab, selectedTab == .home {
                                    selectedTab = .activity
                                    appState.currentStatsScreen = .none
                                    GluLog.ui.notice("home tab fallback applied | reason=isPremiumEnabledChanged")
                                }
                            }

                            .onChange(of: settings.trialStartDate) { _ in
                                GluLog.ui.notice("settings.trialStartDate changed | showsHomeTab=\(showsHomeTab, privacy: .public)")
                                if !showsHomeTab, selectedTab == .home {
                                    selectedTab = .activity
                                    appState.currentStatsScreen = .none
                                    GluLog.ui.notice("home tab fallback applied | reason=trialStartDateChanged")
                                }
                            }

                            .onChange(of: appState.requestedTab) { newTab in
                                guard let newTab else { return }

                                GluLog.ui.notice("requestedTab received | tab=\(String(describing: newTab), privacy: .public)")

                                if newTab == .home, !showsHomeTab {
                                    selectedTab = .activity
                                    appState.currentStatsScreen = .none
                                    appState.requestedTab = nil
                                    GluLog.ui.notice("requestedTab rerouted | requested=home actual=activity")
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
                                GluLog.ui.notice("requestedTab applied | selectedTab=\(String(describing: selectedTab), privacy: .public)")
                            }

                        }
                        .tint(Color.Glu.systemForeground)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            GluBottomTabBar(
                                selectedTab: Binding(
                                    get: { selectedTab },
                                    set: { handleTabSelection($0) }
                                ),
                                showsHomeTab: showsHomeTab
                            )
                        }
                    }
                }
            }

            if showStartupScreen {
                AppStartupScreenView()
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            hasFinishedStartupDelay = true

            withAnimation(.easeInOut(duration: 1.10)) {
                showStartupScreen = false
            }
        }

        .onAppear {
            guard settings.hasCompletedOnboarding else {
                GluLog.ui.notice("ContentView appeared | onboardingIncomplete=true")
                return
            }
            GluLog.ui.notice("ContentView appeared | onboardingComplete=true selectedTab=\(String(describing: selectedTab), privacy: .public)")
            settings.ensureTrialStartedIfEligible()
        }

        .sheet(isPresented: $appState.isAccountSheetPresented) {
            AccountSheetRootView()
                .environmentObject(appState)
                .environmentObject(healthStore)
                .environmentObject(settings)
                .tint(Color.Glu.systemForeground)
                .presentationDetents([.medium, .large], selection: $accountSheetDetent)
                .presentationDragIndicator(.visible)
        }

        .onChange(of: appState.isAccountSheetPresented) { isPresented in
            guard isPresented == false else { return }
            guard let pending = appState.pendingSettingsStartDomain else { return }

            appState.settingsStartDomain = pending
            appState.pendingSettingsStartDomain = nil

            DispatchQueue.main.async {
                appState.isSettingsSheetPresented = true
            }
        }

        .sheet(isPresented: $appState.isSettingsSheetPresented) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(healthStore)
                .environmentObject(settings)
                .tint(Color.Glu.systemForeground)
        }
    }

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

    @ViewBuilder
    private var nutritionRootView: some View {
        switch appState.currentStatsScreen {

        case .nutritionOverview, .none:
            NutritionOverviewViewV1()

        case .carbs, .carbsDayparts, .sugar, .protein, .fat, .calories:
            NutritionDashboardView()

        default:
            NutritionOverviewViewV1()
        }
    }

    private func handleTabSelection(_ newTab: GluTab) {

        GluLog.ui.notice("tab selection requested | tab=\(String(describing: newTab), privacy: .public)")

        if newTab == .home, !showsHomeTab {
            selectedTab = .activity
            appState.currentStatsScreen = .none
            GluLog.ui.notice("tab selection rerouted | requested=home actual=activity")
            return
        }

        selectedTab = newTab

        switch newTab {
        case .nutrition:
            appState.currentStatsScreen = .nutritionOverview
        case .activity, .body, .home, .history:
            appState.currentStatsScreen = .none
        }

        GluLog.ui.notice("tab selection applied | selectedTab=\(String(describing: selectedTab), privacy: .public) currentStatsScreen=\(String(describing: appState.currentStatsScreen), privacy: .public)")
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ContentView – Activity") { // 🟨 UPDATED
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .activity)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
}

#Preview("ContentView – Body") { // 🟨 UPDATED
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .body)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
}

#Preview("ContentView – Nutrition") { // 🟨 UPDATED
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .nutrition)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
}

#Preview("ContentView – History") { // 🟨 UPDATED
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .history)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
}

#Preview("ContentView – Home Premium") { // 🟨 UPDATED
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared

    previewSettings.hasCompletedOnboarding = true
    previewSettings.hasCGM = true
    previewSettings.isPremiumEnabled = true

    return ContentView(startTab: .home)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
}
