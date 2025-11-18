//  ContentView.swift
//  GluVibProbe

import SwiftUI

struct ContentView: View {
    
    @State private var selectedTab: GluTab = .home   // Start-Tab
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Hauptbereich: je nach Tab andere View
            ZStack {
                switch selectedTab {
                case .activity:
                    StepsView()              // ← deine bestehende StepsView
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

#Preview {
    ContentView()
        .environmentObject(HealthStore())   // 👈 hinzufügen
}
