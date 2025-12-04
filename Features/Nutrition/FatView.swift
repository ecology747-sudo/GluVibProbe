//
//  FatView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Fat
//

import SwiftUI

struct FatView: View {

    @StateObject private var viewModel: FatViewModel

    let onMetricSelected: (String) -> Void

    init(
        viewModel: FatViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: FatViewModel())
        }
    }

    var body: some View {
        ZStack {
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    NutritionSectionCardScaled(
                        sectionTitle: "Nutrition",
                        title: "Fat",
                        kpiTitle: "Fat Today",
                        kpiTargetText: viewModel.formattedTargetFat,
                        kpiCurrentText: viewModel.formattedTodayFat,
                        kpiDeltaText: viewModel.formattedDeltaFat,
                        hasTarget: true,
                        last90DaysData: viewModel.last90DaysDataForChart,
                        periodAverages: viewModel.periodAverages,
                        monthlyData: viewModel.monthlyFatData,
                        dailyScale: viewModel.dailyScale,
                        periodScale: viewModel.periodScale,
                        monthlyScale: viewModel.monthlyScale,
                        goalValue: viewModel.goalValueForChart,
                        onMetricSelected: onMetricSelected,
                        metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"]
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

// MARK: - Preview

#Preview("FatView – Nutrition Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = FatViewModel(healthStore: healthStore)

    return FatView(
        viewModel: viewModel,
        onMetricSelected: { _ in }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
