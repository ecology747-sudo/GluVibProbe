//
//  RestingHeartRateView.swift
//  GluVibProbe
//
//  Body-Domain: Resting Heart Rate
//  - zentrale BodySectionCardScaled mit Line-Chart (Last 90 Days)
//  - Daten aus RestingHeartRateViewModel
//

import SwiftUI

struct RestingHeartRateView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel = RestingHeartRateViewModel()

    // MARK: - Metric-Navigation Callback

    let onMetricSelected: (String) -> Void

    // 🔙 NEU: optionaler Back-Callback (zur BodyOverview)
    let onBack: (() -> Void)?          // !!! NEW

    init(
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: (() -> Void)? = nil    // !!! NEW
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack           // !!! NEW
    }

    // MARK: - Body

    var body: some View {

        // KPI-Texte
        let currentText: String = viewModel.todayRestingHeartRateText
        let targetText: String  = "–"
        let deltaText: String   = "–"

        return ZStack {

            // Body-Hintergrund
            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCardScaled(
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
                        chartStyle: .line,
                        onBack: onBack          // !!! NEW – Pfeil in SectionHeader
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

#Preview("RestingHeartRateView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return RestingHeartRateView(
        onMetricSelected: { metric in
            print("Selected metric:", metric)
        },
        onBack: nil
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
