//
//  WeightView.swift
//  GluVibProbe
//
//  Created by MacBookAir on 23.11.25.
//

import SwiftUI

struct WeightView: View {

    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var body: some View {
        ZStack {
            // 👉 Body-Domain-Hintergrund (Orange, leicht transparent)
            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCard(
                        sectionTitle: "Body",
                        title: "Weight",
                        kpiTitle: "Weight Today",
                        kpiTargetText: "–",
                        kpiCurrentText: "–",
                        kpiDeltaText: "–",
                        hasTarget: false,
                        last90DaysData: [],
                        monthlyData: [],
                        dailyGoalForChart: nil,
                        onMetricSelected: onMetricSelected,
                        metrics: ["Sleep", "Weight"],
                        monthlyMetricLabel: "Weight / Month",
                        periodAverages: [],
                        scaleType: .smallInteger
                    )
                    .padding(.horizontal)

                    Text("Weight-Flow folgt – Architektur & Body-Domain sind vorbereitet.")
                        .font(.footnote)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .padding(.top, 16)
            }
        }
    }
}

// MARK: - Preview

#Preview("WeightView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return WeightView()
        .environmentObject(appState)
        .environmentObject(healthStore)
}
