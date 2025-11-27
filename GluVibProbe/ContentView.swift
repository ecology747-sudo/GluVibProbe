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
                    BodyActivityDashboardView()
                case .nutrition:
                    Text("Nutrition View")   // Platzhalter
                case .home:
                    Text("Home View")        // Platzhalter
                case .history:
                    Text("History View")     // Platzhalter
                case .settings:
                    SettingsView()           // deine Settings-Seite
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
        .previewDevice("iPhone 15 Pro")
}

#Preview("ContentView – Steps (Activity) Tab") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()                  // 🔹 NEU

    ContentView(startTab: .activity)
        .environmentObject(previewStore)
        .environmentObject(previewState)           // 🔹 NEU
        .previewDevice("iPhone 15 Pro")
}
//Test Git
