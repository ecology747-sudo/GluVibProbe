//  BMIView.swift                                                     // !!! UPDATED
//  GluVibProbe                                                        // !!! UPDATED
//
//  Body-Domain: BMI
//  - Daten aus BMIViewModel
//  - Line-Chart (Last 90 Days) über zentrale BodySectionCardScaled   // !!! UPDATED

import SwiftUI                                                        // !!! UPDATED

struct BMIView: View {                                               // !!! UPDATED

    // MARK: - ViewModel

    @StateObject private var viewModel = BMIViewModel()              // !!! UPDATED

    // MARK: - Metric-Navigation Callback

    /// Wird vom Body-Domain-Container gesetzt, um zwischen
    /// Weight / Sleep / BMI / Body Fat / Resting HR zu wechseln.
    let onMetricSelected: (String) -> Void                           // !!! UPDATED

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {  // !!! UPDATED
        self.onMetricSelected = onMetricSelected                     // !!! UPDATED
    }

    // MARK: - Body

    var body: some View {                                            // !!! UPDATED

        // KPI-Texte
        let currentBMIText: String = viewModel.todayBMIText          // !!! UPDATED
        let targetText: String      = "–"                             // !!! UPDATED
        let deltaText: String       = "–"                             // !!! UPDATED

        return ZStack {                                              // !!! UPDATED
            // 👉 Body-Domain-Hintergrund
            Color.Glu.bodyAccent.opacity(0.18)                       // !!! UPDATED
                .ignoresSafeArea()                                   // !!! UPDATED

            ScrollView {                                             // !!! UPDATED
                VStack(alignment: .leading, spacing: 16) {           // !!! UPDATED

                    // !!! UPDATED: zentrale SectionCard mit chartStyle: .line
                    BodySectionCardScaled(                           // !!! UPDATED
                        sectionTitle: "Body",                        // !!! UPDATED
                        title: "BMI",                               // !!! UPDATED
                        kpiTitle: "BMI Today",                      // !!! UPDATED
                        kpiTargetText: targetText,                  // !!! UPDATED
                        kpiCurrentText: currentBMIText,             // !!! UPDATED
                        kpiDeltaText: deltaText,                    // !!! UPDATED
                        hasTarget: false,                           // !!! UPDATED

                        last90DaysData: viewModel.last90DaysDataForChart, // !!! UPDATED
                        periodAverages: viewModel.periodAveragesForChart, // !!! UPDATED
                        monthlyData: viewModel.monthlyData,         // !!! UPDATED

                        dailyScale: viewModel.dailyScale,           // !!! UPDATED
                        periodScale: viewModel.periodScale,         // !!! UPDATED
                        monthlyScale: viewModel.monthlyScale,       // !!! UPDATED

                        goalValue: nil,                             // !!! UPDATED

                        onMetricSelected: onMetricSelected,         // !!! UPDATED
                        metrics: [                                  // !!! UPDATED
                            "Weight",
                            "Sleep",
                            "BMI",
                            "Body Fat",
                            "Resting Heart Rate"
                        ],
                        showMonthlyChart: false,                    // !!! UPDATED
                        // Temporär nutzen wir dieselbe Skala wie Weight,    // !!! UPDATED
                        // bis ein eigener BMI-ScaleType eingeführt ist.     // !!! UPDATED
                        scaleType: .weightKg,                       // !!! UPDATED
                        chartStyle: .bar                          // !!! NEW
                    )
                    .padding(.horizontal)                           // !!! UPDATED

                }
                .padding(.top, 16)                                  // !!! UPDATED
            }
            .refreshable {                                          // !!! UPDATED
                viewModel.refresh()                                 // !!! UPDATED
            }
        }
        .onAppear {                                                 // !!! UPDATED
            viewModel.onAppear()                                    // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("BMIView – Body Domain") {                                   // !!! UPDATED
    let appState    = AppState()                                      // !!! UPDATED
    let healthStore = HealthStore.preview()                           // !!! UPDATED

    return BMIView() { metric in                                      // !!! UPDATED
        print("Selected metric:", metric)                             // !!! UPDATED
    }
    .environmentObject(appState)                                      // !!! UPDATED
    .environmentObject(healthStore)                                   // !!! UPDATED
}
