//
//  AccountSheetRootView.swift
//  GluVib
//
//  Area: Account / Root Navigation
//  File Role:
//  - Technical root coordinator for the account sheet flow.
//  - Owns account-sheet-local navigation and forwards shared runtime objects
//    into all routed account destinations.
//
//  Purpose:
//  - Keep the account navigation flow centralized and easy to maintain.
//  - Ensure that all account/status screens consume the same shared app state,
//    including the central EntitlementManager.
//  - Prevent monetization status from diverging across routed account screens.
//
//  System Role:
//  - This file is a navigation coordinator, not a business-logic layer.
//  - It does NOT calculate premium / trial / free locally.
//  - It does NOT define capability rules.
//  - It only routes to the correct destination views and injects shared objects.
//
//  Key Connections:
//  - AppState.AccountRoute
//  - AccountMenuSheetView
//  - AccountSettingsMenuView
//  - ManageAccountHomeView
//  - EntitlementManager
//

import SwiftUI

struct AccountSheetRootView: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var entitlementManager: EntitlementManager // 🟨 UPDATED

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var path: [AppState.AccountRoute] = []

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        NavigationStack(path: $path) {

            AccountMenuSheetView(
                onOpenSettingsMenu: {
                    path.append(.settingsMenu)
                },
                onOpenHelp: {
                    path.append(.help)
                },
                onOpenFAQ: {
                    path.append(.faq)
                },
                onOpenAppInfo: {
                    path.append(.appInfo)
                },
                onOpenLegal: {
                    path.append(.legal)
                }
            )
            .environmentObject(appState)
            .environmentObject(settings)
            .environmentObject(healthStore)
            .environmentObject(entitlementManager) // 🟨 UPDATED
            .navigationDestination(for: AppState.AccountRoute.self) { route in
                destinationView(for: route)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: appState.pendingAccountRoute) { _, newValue in
                guard let route = newValue else { return }
                path.append(route)
                appState.pendingAccountRoute = nil
            }
            .onAppear {
                if let route = appState.pendingAccountRoute {
                    path.append(route)
                    appState.pendingAccountRoute = nil
                }
            }
        }
        .tint(Color.Glu.systemForeground)
    }

    // ============================================================
    // MARK: - Destination Routing
    // ============================================================

    @ViewBuilder
    private func destinationView(for route: AppState.AccountRoute) -> some View {
        switch route {

        case .help:
            HelpAndFeedbackView()

        case .faq:
            FrequentlyAskedQuestionsView()
                .environmentObject(appState)
                .environmentObject(settings)

        case .appInfo:
            AppInfoView()

        case .legal:
            LegalInformationView()

        case .manage:
            ManageAccountHomeView()
                .environmentObject(appState)
                .environmentObject(settings)
                .environmentObject(healthStore)
                .environmentObject(entitlementManager) // 🟨 UPDATED

        case .settingsMenu:
            AccountSettingsMenuView(
                onOpenAppStatus: { path.append(.manage) },
                onOpenTargetsThresholds: { path.append(.targetsThresholdsMenu) },
                onOpenUnits: { path.append(.units) },
                onOpenHealthKitPermissions: { path.append(.healthKitPermissions) }
            )
            .environmentObject(appState)
            .environmentObject(settings)
            .environmentObject(healthStore)
            .environmentObject(entitlementManager) // 🟨 UPDATED

        case .targetsThresholdsMenu:
            TargetsThresholdsMenuView(
                onOpenMetabolic: { path.append(.targetsMetabolic) },
                onOpenActivity: { path.append(.targetsActivity) },
                onOpenBody: { path.append(.targetsBody) },
                onOpenNutrition: { path.append(.targetsNutrition) }
            )
            .environmentObject(settings)

        case .targetsMetabolic:
            SettingsDomainCardScreen(
                domain: .metabolic,
                onBackToSettingsHome: {
                    if !path.isEmpty { path.removeLast() }
                }
            )

        case .targetsActivity:
            SettingsDomainCardScreen(
                domain: .activity,
                onBackToSettingsHome: {
                    if !path.isEmpty { path.removeLast() }
                }
            )

        case .targetsBody:
            SettingsDomainCardScreen(
                domain: .body,
                onBackToSettingsHome: {
                    if !path.isEmpty { path.removeLast() }
                }
            )

        case .targetsNutrition:
            SettingsDomainCardScreen(
                domain: .nutrition,
                onBackToSettingsHome: {
                    if !path.isEmpty { path.removeLast() }
                }
            )

        case .units:
            SettingsDomainCardScreen(
                domain: .units,
                onBackToSettingsHome: {
                    if !path.isEmpty { path.removeLast() }
                }
            )

        case .healthKitPermissions:
            HealthKitPermissionsViewV1()
                .environmentObject(settings)
                .environmentObject(healthStore)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#if DEBUG
#Preview("AccountSheetRootView (DEV Routing Preview)") {
    AccountSheetRootView()
        .environmentObject(AppState())
        .environmentObject(SettingsModel.shared)
        .environmentObject(HealthStore.preview())
        .environmentObject(EntitlementManager()) // 🟨 UPDATED
}
#endif
