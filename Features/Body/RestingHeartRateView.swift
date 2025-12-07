//  RestingHeartRateView.swift                                         // !!! UPDATED
//  GluVibProbe
//
//  Body-Domain: Resting Heart Rate
//  - zentrale BodySectionCardScaled mit Line-Chart (Last 90 Days)
//  - Daten aus RestingHeartRateViewModel
//

import SwiftUI                                                         // !!! UPDATED

struct RestingHeartRateView: View {                                   // !!! UPDATED

    // MARK: - ViewModel

    @StateObject private var viewModel = RestingHeartRateViewModel()  // !!! UPDATED

    // MARK: - Metric-Navigation Callback

    let onMetricSelected: (String) -> Void                            // !!! UPDATED

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {   // !!! UPDATED
        self.onMetricSelected = onMetricSelected
    }

    // MARK: - Body

    var body: some View {                                             // !!! UPDATED

        // KPI-Texte (werden über Extension geliefert, s.u.)           // !!! UPDATED
        let currentText: String = viewModel.todayRestingHeartRateText // !!! UPDATED
        let targetText: String  = "–"
        let deltaText: String   = "–"

        return ZStack {                                               // !!! UPDATED

            // Body-Hintergrund
            Color.Glu.bodyAccent.opacity(0.18)                        // !!! UPDATED
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCardScaled(                            // !!! UPDATED
                        sectionTitle: "Body",
                        title: "Resting Heart Rate",
                        kpiTitle: "Resting HR Today",
                        kpiTargetText: targetText,
                        kpiCurrentText: currentText,
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
                        scaleType: .heartRateBpm,
                        chartStyle: .line                             // !!! NEW
                    )
                    .padding(.horizontal)

                }
                .padding(.top, 16)
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

// MARK: - Fallback-Formatter für KPI-Text                           // !!! NEW
// Wird später durch echte BPM-Formatierung ersetzt, wenn wir
// das RestingHeartRateViewModel gemeinsam ansehen.                  // !!! NEW

                                                                    // !!! NEW

// MARK: - Preview

#Preview("RestingHeartRateView – Body Domain") {                      // !!! UPDATED
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return RestingHeartRateView() { metric in
        print("Selected metric:", metric)
    }
    .environmentObject(appState)
    .environmentObject(healthStore)
}
