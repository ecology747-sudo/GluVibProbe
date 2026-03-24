//
//  GluVibApp.swift
//  GluVib
//

import SwiftUI
import OSLog // 🟨 UPDATED

@main
struct GluVibApp: App {

    @StateObject private var healthStore = HealthStore.shared
    @StateObject private var appState   = AppState()

    // ------------------------------------------------------------
    // MARK: - Settings (Global)
    // ------------------------------------------------------------
    @StateObject private var settings = SettingsModel.shared

    init() {
        GluLog.app.notice("GluVibApp initialized") // 🟨 UPDATED
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color("SystemForeground"))
                .environmentObject(healthStore)
                .environmentObject(appState)
                .environmentObject(settings)
        }
    }
}
