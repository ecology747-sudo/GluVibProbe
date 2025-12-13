//
//  BMIView.swift                                                     // !!! UPDATED
//  GluVibProbe                                                        // !!! UPDATED
//
//  Body-Domain: BMI
//  - Daten aus BMIViewModel
//  - Chart über zentrale BodySectionCardScaled
//

import SwiftUI

struct BMIView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel = BMIViewModel()

    // MARK: - Metric-Navigation Callback

    /// Wird vom Body-Domain-Container gesetzt, um zwischen
    /// Weight / Sleep / BMI / Body Fat / Resting HR zu wechseln.
    let onMetricSelected: (String) -> Void

    // 🔙 NEU: optionaler Back-Callback (zur BodyOverview)
    let onBack: (() -> Void)?

    init(
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: (() -> Void)? = nil          // !!! NEW
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack                // !!! NEW
    }

    // MARK: - Body

    var body: some View {

        // KPI-Texte
        let currentBMIText: String = viewModel.todayBMIText
        let targetText: String      = "–"
        let deltaText: String       = "–"

        return ZStack {
            // 👉 Body-Domain-Hintergrund
            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCardScaled(
                        sectionTitle: "Body",
                        title: "BMI",
                        kpiTitle: "BMI Today",
                        kpiTargetText: targetText,
                        kpiCurrentText: currentBMIText,
                        kpiDeltaText: deltaText,
                        hasTarget: false,

                        last90DaysData: viewModel.last90DaysDataForChart,
                        periodAverages: viewModel.periodAveragesForChart,
                        monthlyData: viewModel.monthlyData,

                        dailyScale: viewModel.dailyScale,
                        periodScale: viewModel.periodScale,
                        monthlyScale: viewModel.monthlyScale,

                        goalValue: nil,

                        onMetricSelected: onMetricSelected,
                        metrics: [
                            "Weight",
                            "Sleep",
                            "BMI",
                            "Body Fat",
                            "Resting Heart Rate"
                        ],
                        showMonthlyChart: false,
                        // temporär gleiche Skala wie Weight
                        scaleType: .weightKg,
                        chartStyle: .bar,
                        onBack: onBack              // !!! NEW – Pfeil-Logik
                    )
                    .padding(.horizontal)
                }
              
            }
            .refreshable {
                viewModel.refresh()
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Preview

#Preview("BMIView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return BMIView(
        onMetricSelected: { metric in
            print("Selected metric:", metric)
        },
        onBack: nil
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
