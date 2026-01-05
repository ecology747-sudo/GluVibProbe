//
//  MainChartLandscapeViewV1.swift
//  GluVibProbe
//
//  Metabolic V1 — Landscape Wrapper for MainChartViewV1
//
//  Ziel (Landscape):
//  - Fullscreen, KEINE Card/Kachel-UI
//  - Kein grüner Rahmen, kein Shadow-Container
//  - Nur: Datum+Navigation oben, Chart fullscreen, Chips unten
//  - TabBar zuverlässig ausblenden
//  - KEIN Pull-to-Refresh
//  - Swipe-Dismiss deaktiviert
//

import SwiftUI

struct MainChartLandscapeViewV1: View {

    // SSoT via Environment
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    var body: some View {

        MainChartViewV1(
            healthStore: healthStore,
            chipLayout: .singleRow,
            interactionMode: .landscape
        )
        .environmentObject(settings)

        // TabBar zuverlässig weg
        .toolbar(.hidden, for: .tabBar)
        .navigationBarHidden(true)

        // verhindert "Swipe down to dismiss"
        .interactiveDismissDisabled(true)
    }
}

// MARK: - Preview

#Preview("MainChartLandscapeViewV1") {
    NavigationStack {
        MainChartLandscapeViewV1()
            .environmentObject(HealthStore.preview())
            .environmentObject(SettingsModel.shared)
    }
}
