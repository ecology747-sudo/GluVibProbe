//
//  ContentView.swift
//  GluVib
//
//  Area: App / Root Navigation
//  File Role:
//  - Central root container for GluVib tab navigation and top-level screen switching.
//  - Connects the existing app flow to the new monetization runtime.
//
//  Purpose:
//  - Keep onboarding, startup screen, tab navigation, account/settings sheets,
//    and root dashboard switching in one controlled place.
//  - Start consuming the new EntitlementManager without breaking the current
//    TestFlight / product-iteration flow.
//
//  Monetization Integration:
//  - This file now reads the new central monetization status from EntitlementManager.
//  - The Home tab visibility is no longer based on legacy premium flags directly.
//  - Trial refresh and monetization refresh are triggered centrally here when needed.
//
//  Current Transition Scope:
//  - This file is only partially migrated.
//  - AppState still contains legacy gating logic for metric taps.
//  - ContentView is now prepared so later capability-driven migration can continue
//    without another root-level restructuring.
//

import SwiftUI
import UIKit
import OSLog

struct ContentView: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var entitlementManager: EntitlementManager // 🟨 UPDATED

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var vSizeClass

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var selectedTab: GluTab
    @State private var showStartupScreen = true
    @State private var hasFinishedStartupDelay = false
    @State private var accountSheetDetent: PresentationDetent = .large

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(startTab: GluTab = .home) {
        _selectedTab = State(initialValue: startTab)
    }

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var isLandscape: Bool {
        vSizeClass == .compact
    }

    /// 🟨 UPDATED
    /// Home visibility is now driven by the central monetization status
    /// plus the current user intent for CGM visibility.
    ///
    /// Current transition behavior:
    /// - full commercial access (trial / premium) is required
    /// - CGM intent must still be enabled for the current Home experience
    private var showsHomeTab: Bool {
        entitlementManager.hasFullAppAccess && settings.hasCGM
    }

    private var shouldShowMainChartLandscape: Bool {
        isLandscape &&
        selectedTab == .home &&
        appState.currentStatsScreen == .none &&
        showsHomeTab &&
        !appState.isMetabolicReportPresented
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

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
                                applyHomeFallbackIfNeeded(reason: "hasCGMChanged") // 🟨 UPDATED
                            }

                            .onChange(of: entitlementManager.entitlementStatus) { _ in // 🟨 UPDATED
                                GluLog.ui.notice(
                                    "entitlementStatus changed | showsHomeTab=\(showsHomeTab, privacy: .public) status=\(String(describing: entitlementManager.entitlementStatus), privacy: .public)"
                                )
                                applyHomeFallbackIfNeeded(reason: "entitlementStatusChanged")
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
        .task(id: settings.hasCompletedOnboarding) { // 🟨 UPDATED
            guard settings.hasCompletedOnboarding else { return }
            entitlementManager.ensureTrialStartedIfEligible()
            await entitlementManager.refresh()
        }
        .onChange(of: scenePhase) { newPhase in // 🟨 UPDATED
            guard newPhase == .active else { return }
            Task {
                entitlementManager.ensureTrialStartedIfEligible()
                await entitlementManager.refresh()
            }
        }
        .onAppear {
            guard settings.hasCompletedOnboarding else {
                GluLog.ui.notice("ContentView appeared | onboardingIncomplete=true")
                return
            }

            GluLog.ui.notice(
                "ContentView appeared | onboardingComplete=true selectedTab=\(String(describing: selectedTab), privacy: .public)"
            )

            entitlementManager.ensureTrialStartedIfEligible() // 🟨 UPDATED

            Task {
                await entitlementManager.refresh() // 🟨 UPDATED
            }
        }

        .sheet(isPresented: $appState.isAccountSheetPresented) {
            AccountSheetRootView()
                .environmentObject(appState)
                .environmentObject(healthStore)
                .environmentObject(settings)
                .environmentObject(entitlementManager) // 🟨 UPDATED
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
                .environmentObject(entitlementManager) // 🟨 UPDATED
                .tint(Color.Glu.systemForeground)
        }
    }

    // ============================================================
    // MARK: - Root Views
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

    // ============================================================
    // MARK: - Navigation Helpers
    // ============================================================

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

        GluLog.ui.notice(
            "tab selection applied | selectedTab=\(String(describing: selectedTab), privacy: .public) currentStatsScreen=\(String(describing: appState.currentStatsScreen), privacy: .public)"
        )
    }

    private func applyHomeFallbackIfNeeded(reason: String) { // 🟨 UPDATED
        guard !showsHomeTab, selectedTab == .home else { return }

        selectedTab = .activity
        appState.currentStatsScreen = .none

        GluLog.ui.notice(
            "home tab fallback applied | reason=\(reason, privacy: .public)"
        )
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ContentView – Activity") {
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared
    let previewEntitlementManager = EntitlementManager() // 🟨 UPDATED

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .activity)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
        .environmentObject(previewEntitlementManager) // 🟨 UPDATED
}

#Preview("ContentView – Body") {
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared
    let previewEntitlementManager = EntitlementManager() // 🟨 UPDATED

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .body)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
        .environmentObject(previewEntitlementManager) // 🟨 UPDATED
}

#Preview("ContentView – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared
    let previewEntitlementManager = EntitlementManager() // 🟨 UPDATED

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .nutrition)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
        .environmentObject(previewEntitlementManager) // 🟨 UPDATED
}

#Preview("ContentView – History") {
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared
    let previewEntitlementManager = EntitlementManager() // 🟨 UPDATED

    previewSettings.hasCompletedOnboarding = true

    return ContentView(startTab: .history)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
        .environmentObject(previewEntitlementManager) // 🟨 UPDATED
}

#Preview("ContentView – Home Premium") {
    let previewStore = HealthStore.preview()
    let previewAppState = AppState()
    let previewSettings = SettingsModel.shared
    let previewEntitlementManager = EntitlementManager() // 🟨 UPDATED

    previewSettings.hasCompletedOnboarding = true
    previewSettings.hasCGM = true
    previewSettings.isPremiumEnabled = true

    return ContentView(startTab: .home)
        .environmentObject(previewStore)
        .environmentObject(previewAppState)
        .environmentObject(previewSettings)
        .environmentObject(previewEntitlementManager) // 🟨 UPDATED
}
