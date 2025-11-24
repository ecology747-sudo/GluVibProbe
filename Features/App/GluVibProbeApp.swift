//
//  GluVibProbeApp.swift
//  GluVibProbe
//

import SwiftUI

@main
struct GluVibProbeApp: App {

    @StateObject private var healthStore = HealthStore()  // HealthKit-Datenquelle
    @StateObject private var appState   = AppState()      // 🔹 globaler App-Zustand

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)           // HealthStore für alle Views
                .environmentObject(appState)              // 🔹 AppState für alle Views
        }
    }
}
