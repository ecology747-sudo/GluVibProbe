//
//  CarbsBolusRatioViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct CarbsBolusRatioViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: { /* später */ },
            background: {
                LinearGradient(
                    colors: [.white, Color.Glu.metabolicDomain.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Carbs/Bolus Ratio (V1) — TODO")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
            }
            .padding(.horizontal, 8)
        }
    }
}

#Preview("CarbsBolusRatioViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    previewState.currentStatsScreen = .carbsBolusRatio

    return CarbsBolusRatioViewV1()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
