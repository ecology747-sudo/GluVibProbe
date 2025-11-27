//
//  GluVibProbeApp.swift
//  GluVibProbe
//

import SwiftUI

@main
struct GluVibProbeApp: App {

    // 👉 Nutze den Singleton, den auch das StepsViewModel verwendet
    @StateObject private var healthStore = HealthStore.shared      // HealthKit-Datenquelle
    @StateObject private var appState   = AppState()               // globaler App-Zustand

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)                    // HealthStore für alle Views
                .environmentObject(appState)                       // AppState für alle Views
                .onAppear {
                    // 🔥 Hier starten wir HealthKit-Zugriff + Datenladen
                    healthStore.requestAuthorization()
                }
        }
    }
}
