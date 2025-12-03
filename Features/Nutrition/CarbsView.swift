//
//  CarbsView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Carbohydrates
//

import SwiftUI

struct CarbsView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: CarbsViewModel

    // Callback aus dem Nutrition-Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    /// Haupt-Init:
    /// - ohne ViewModel → CarbsViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: CarbsViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsViewModel())
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    NutritionSectionCard(
                        sectionTitle: "Nutrition",
                        title: "Carbs",
                        kpiTitle: "Carbs Today",
                        kpiTargetText: viewModel.formattedTargetCarbs,
                        kpiCurrentText: viewModel.formattedTodayCarbs,
                        kpiDeltaText: viewModel.formattedDeltaCarbs,
                        hasTarget: true,
                        last90DaysData: viewModel.last90DaysDataForChart,
                        monthlyData: viewModel.monthlyCarbsData,
                        dailyGoalForChart: Int(viewModel.goalValueForChart),
                        onMetricSelected: onMetricSelected,
                        metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
                        monthlyMetricLabel: "Carbs / Month",
                        periodAverages: viewModel.periodAverages,
                        showMonthlyChart: true,
                        dailyScaleType: .smallInteger,
                        monthlyScaleType: .smallInteger,
                        // 🔹 NEU: Skalen aus dem ViewModel einspeisen
                        dailyScaleResult: viewModel.dailyScale,
                        monthlyScaleResult: viewModel.monthlyScale
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

#Preview("CarbsView – Nutrition Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = CarbsViewModel(healthStore: healthStore)

    return CarbsView(
        viewModel: viewModel,
        onMetricSelected: { _ in }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
