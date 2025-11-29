//  ContentView.swift
//  GluVibProbe

import SwiftUI

struct ContentView: View {
    
    @State private var selectedTab: GluTab
    
    /// Standard-Init für die App: startet auf .home
    init(startTab: GluTab = .home) {
        _selectedTab = State(initialValue: startTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Hauptbereich: je nach Tab andere View
            ZStack {
                switch selectedTab {
                case .activity:
                    ActivityDashboardView()

                case .body:
                    BodyDashboardView()

                case .nutrition:
                    NutritionDashboard()    // 👈 jetzt echte View

                case .home:
                    HomeView()

                case .history:
                    HistoryView()           // 👈 jetzt echte View

                case .settings:
                    SettingsView()
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Untere Tab-Bar (immer sichtbar)
            GluBottomTabBar(selectedTab: $selectedTab)
        }
    }
}

#Preview("ContentView – Home Tab") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()                  // 🔹 NEU

    ContentView(startTab: .home)
        .environmentObject(previewStore)
        .environmentObject(previewState)           // 🔹 NEU
        
}

#Preview("ContentView – Steps (Activity) Tab") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()                  // 🔹 NEU

    ContentView(startTab: .activity)
        .environmentObject(previewStore)
        .environmentObject(previewState)           // 🔹 NEU
        
}
//Test Git
