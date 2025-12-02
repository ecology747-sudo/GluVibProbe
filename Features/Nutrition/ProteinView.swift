//
//  ProteinView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Protein
//

import SwiftUI

struct ProteinView: View {

    @StateObject private var viewModel: ProteinViewModel

    let onMetricSelected: (String) -> Void

    init(
        viewModel: ProteinViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ProteinViewModel())
        }
    }

    var body: some View {
        ZStack {
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    NutritionSectionCard(
                        sectionTitle: "Nutrition",
                        title: "Protein",
                        kpiTitle: "Protein Today",
                        kpiTargetText: viewModel.formattedTargetProtein,
                        kpiCurrentText: viewModel.formattedTodayProtein,
                        kpiDeltaText: viewModel.formattedDeltaProtein,
                        hasTarget: true,
                        last90DaysData: viewModel.last90DaysDataForChart,
                        monthlyData: viewModel.monthlyProteinData,
                        // ⬇️ hier KEIN Int(...) – wir übergeben das Int? direkt
                        dailyGoalForChart: viewModel.goalValueForChart,
                        onMetricSelected: onMetricSelected,
                        metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
                        monthlyMetricLabel: "Protein / Month",
                        periodAverages: viewModel.periodAverages,
                        showMonthlyChart: true,
                        dailyScaleType: .smallInteger,
                        monthlyScaleType: .smallInteger
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

#Preview("ProteinView – Nutrition Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = ProteinViewModel(healthStore: healthStore)

    return ProteinView(
        viewModel: viewModel,
        onMetricSelected: { _ in }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
