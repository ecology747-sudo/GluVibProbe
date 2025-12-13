//
//  BodyFatView.swift
//  GluVibProbe
//
//  Body-Domain: Body Fat Percentage
//  - zentrale SectionCard
//  - Daten aus BodyFatViewModel
//

import SwiftUI

struct BodyFatView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel = BodyFatViewModel()

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

        // KPI-Text
        let currentText: String = viewModel.todayBodyFatText
        let targetText: String  = "–"
        let deltaText: String   = "–"

        return ZStack {

            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCardScaled(
                        sectionTitle: "Body",
                        title: "Body Fat",
                        kpiTitle: "Body Fat Today",
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

                        // aktueller ScaleType (kann später spezialisiert werden)
                        scaleType: .weightKg,
                        chartStyle: .bar,
                        onBack: onBack          // !!! NEW – Pfeil durchreichen
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

#Preview("BodyFatView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return BodyFatView(
        onMetricSelected: { metric in
            print("Selected metric:", metric)
        },
        onBack: nil
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
