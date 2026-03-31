//
//  GluVibApp.swift
//  GluVib
//
//  Area: App / Entry
//  File Role:
//  - Main application entry point for GluVib.
//  - Builds and injects the global app-wide runtime objects.
//
//  Purpose:
//  - Keep the app composition root centralized and easy to understand.
//  - Provide HealthStore, AppState, SettingsModel, and the new
//    EntitlementManager as shared environment objects.
//
//  System Role:
//  - This file is the correct place to attach the monetization runtime
//    to the app without mixing that setup into Views.
//  - Trial / premium / free resolution is now prepared centrally here,
//    while the rest of the app can migrate step by step.
//
//  Key Connections:
//  - HealthStore.shared
//  - AppState
//  - SettingsModel.shared
//  - EntitlementManager
//

import SwiftUI
import OSLog // 🟨 UPDATED

@main
struct GluVibApp: App {

    // ============================================================
    // MARK: - Global Runtime Objects
    // ============================================================

    @StateObject private var healthStore = HealthStore.shared
    @StateObject private var appState = AppState()
    @StateObject private var settings = SettingsModel.shared
    @StateObject private var entitlementManager = EntitlementManager.shared

    // ============================================================
    // MARK: - Init
    // ============================================================

    init() {
        GluLog.app.notice("GluVibApp initialized") // 🟨 UPDATED
    }

    // ============================================================
    // MARK: - Scene
    // ============================================================

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color("SystemForeground"))
                .environmentObject(healthStore)
                .environmentObject(appState)
                .environmentObject(settings)
                .environmentObject(entitlementManager) // 🟨 UPDATED
                .task { // 🟨 UPDATED
                    entitlementManager.ensureTrialStartedIfEligible()
                    await entitlementManager.refresh()
                }
        }
    }
}
