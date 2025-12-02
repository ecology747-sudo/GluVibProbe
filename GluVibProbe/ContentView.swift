//  ContentView.swift
//  GluVibProbe

import SwiftUI

struct ContentView: View {
    
    @State private var selectedTab: GluTab
    private let settings = SettingsModel.shared
    @State private var showUnsavedAlert: Bool = false
    
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
                    NutritionDashboardView()    // 👈 neues Nutrition-Dashboard

                case .home:
                    HomeView()     //ist Metabolic

                case .history:
                    HistoryView()           // 👈 jetzt echte View

                case .settings:
                    SettingsView()
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Untere Tab-Bar (immer sichtbar)
            GluBottomTabBar(
                selectedTab: Binding(
                    get: { selectedTab },
                    set: { newValue in
                        handleTabSelection(newValue)
                    }
                )
            )
        }
        .alert(
            "Unsaved Settings",
            isPresented: $showUnsavedAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
            You have unsaved changes.
            Please tap “Save Settings” before leaving this screen.
            """)
        }
        .tint(Color.Glu.primaryBlue)    }
    
    // MARK: - Tab Handling

    private func handleTabSelection(_ newTab: GluTab) {
        // Wenn wir die Settings-View verlassen wollen und dort noch ungespeicherte
        // Änderungen vorhanden sind, Navigation blockieren und Hinweis zeigen.
        if selectedTab == .settings,
           newTab != .settings,
           settings.hasUnsavedChanges {
            showUnsavedAlert = true
            return
        }

        // Ansonsten Tab ganz normal wechseln
        selectedTab = newTab
    }
}

#Preview("ContentView – Home Tab") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()                  // 🔹 NEU

    ContentView(startTab: .home)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
