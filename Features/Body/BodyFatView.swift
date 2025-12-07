//  BodyFatView.swift                                                 // !!! UPDATED
//  GluVibProbe
//
//  Body-Domain: Body Fat Percentage
//  - zentrale SectionCard (mit chartStyle: .line)
//  - Daten aus BodyFatViewModel
//

import SwiftUI                                                        // !!! UPDATED

struct BodyFatView: View {                                            // !!! UPDATED

    // MARK: - ViewModel

    @StateObject private var viewModel = BodyFatViewModel()          // !!! UPDATED

    // MARK: - Metric-Navigation Callback

    let onMetricSelected: (String) -> Void                           // !!! UPDATED

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {  // !!! UPDATED
        self.onMetricSelected = onMetricSelected
    }

    // MARK: - Body

    var body: some View {                                            // !!! UPDATED

        // KPI-Text
        let currentText: String = viewModel.todayBodyFatText         // !!! UPDATED
        let targetText: String  = "–"
        let deltaText: String   = "–"

        return ZStack {                                              // !!! UPDATED

            Color.Glu.bodyAccent.opacity(0.18)                       // !!! UPDATED
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // !!! UPDATED: zentrale SectionCard mit chartStyle: .line
                    BodySectionCardScaled(
                        sectionTitle: "Body",                        // !!! UPDATED
                        title: "Body Fat",                           // !!! UPDATED
                        kpiTitle: "Body Fat Today",                  // !!! UPDATED
                        kpiTargetText: targetText,                   // !!! UPDATED
                        kpiCurrentText: currentText,                 // !!! UPDATED
                        kpiDeltaText: deltaText,                     // !!! UPDATED
                        hasTarget: false,                            // !!! UPDATED

                        last90DaysData: viewModel.last90DaysDataForChart,   // !!! UPDATED
                        periodAverages: viewModel.periodAveragesForChart,   // !!! UPDATED
                        monthlyData: viewModel.monthlyData,                 // !!! UPDATED

                        dailyScale: viewModel.dailyScale,            // !!! UPDATED
                        periodScale: viewModel.periodScale,          // !!! UPDATED
                        monthlyScale: viewModel.monthlyScale,        // !!! UPDATED

                        goalValue: nil,                              // !!! UPDATED

                        onMetricSelected: onMetricSelected,          // !!! UPDATED
                        metrics: [                                   // !!! UPDATED
                            "Weight",
                            "Sleep",
                            "BMI",
                            "Body Fat",
                            "Resting Heart Rate"
                        ],
                        showMonthlyChart: false,                     // !!! UPDATED

                        // Eigener Scale-Type wäre möglich.
                        // Aktuell speichern wir BodyFat als Prozent 0–100, daher:
                        scaleType: .weightKg,                        // !!! TEMP: eigener ScaleType folgt später

                        chartStyle: .bar                            // !!! NEW
                    )
                    .padding(.horizontal)

                }
                .padding(.top, 16)
            }
            .refreshable {
                viewModel.refresh()                                 // !!! UPDATED
            }
        }
        .onAppear {
            viewModel.onAppear()                                    // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("BodyFatView – Body Domain") {                               // !!! UPDATED
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return BodyFatView() { metric in
        print("Selected metric:", metric)
    }
    .environmentObject(appState)
    .environmentObject(healthStore)
}
