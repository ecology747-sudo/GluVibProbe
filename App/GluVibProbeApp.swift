//
//  GluVibProbeApp.swift
//  GluVibProbe
//

import SwiftUI

@main
struct GluVibProbeApp: App {

    @StateObject private var healthStore = HealthStore.shared      // HealthKit-Datenquelle
    @StateObject private var appState   = AppState()               // globaler App-Zustand

    // ------------------------------------------------------------
    // MARK: - Settings (Global)
    // ------------------------------------------------------------
    @StateObject private var settings = SettingsModel.shared       // global verfügbar (Scaffolding only)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color("GluPrimaryBlue"))                     // UPDATED: global Tint (icons, chevrons, links, controls)
                .environmentObject(healthStore)                    // HealthStore für alle Views
                .environmentObject(appState)                       // AppState für alle Views
                .environmentObject(settings)                       // SettingsModel für alle Views
                .onAppear {
                    healthStore.requestAuthorization()
                }
        }
    }
}
