//
//  NutritionEnergyView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Energy (kcal / kJ)
//

import SwiftUI

struct NutritionEnergyView: View {

    @StateObject private var viewModel = NutritionEnergyViewModel()

    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var body: some View {
        ZStack {
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ✅ NEU: helper-basiertes, skaliertes System
                    NutritionSectionCardScaled(
                        sectionTitle: "Nutrition",
                        title: "Nutrition Energy",
                        kpiTitle: "Energy Today",
                        kpiTargetText: viewModel.targetText,
                        kpiCurrentText: viewModel.currentText,
                        kpiDeltaText: viewModel.deltaText,
                        hasTarget: true,
                        last90DaysData: viewModel.last90DaysForChart,
                        periodAverages: viewModel.periodAverages,
                        // 🔹 Monatsdaten bereits in richtige Einheit konvertiert
                        monthlyData: viewModel.monthlyEnergyForChart,
                        // 🔹 neue Scale-Profile aus dem ViewModel
                        dailyScale: viewModel.dailyScale,
                        periodScale: viewModel.periodScale,
                        monthlyScale: viewModel.monthlyScale,
                        // 🔹 Ziellinie (kcal / kJ)
                        goalValue: viewModel.chartGoalValue,
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

#Preview("NutritionEnergyView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return NutritionEnergyView()
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
