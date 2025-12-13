//
//  NutritionEnergyView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Energy (kcal / kJ)
//

import SwiftUI

struct NutritionEnergyView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel = NutritionEnergyViewModel()

    // Callback aus dem Nutrition-Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    // Back-Callback (nicht optional, mit Default-Closure – wie bei Carbs/Protein/Fat)
    let onBack: () -> Void

    // MARK: - Init

    init(
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: @escaping () -> Void = {}
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Domain-Hintergrund
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // 🔝 Sticky-Header für Energy-Metric
                SectionHeader(
                    title: "Nutrition",
                    subtitle: "Energy",
                    tintColor: Color.Glu.nutritionAccent,
                    onBack: onBack
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // helper-basiertes, skaliertes System
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
                            // Monatsdaten bereits in richtige Einheit konvertiert
                            monthlyData: viewModel.monthlyEnergyForChart,
                            // Scale-Profile aus dem ViewModel
                            dailyScale: viewModel.dailyScale,
                            periodScale: viewModel.periodScale,
                            monthlyScale: viewModel.monthlyScale,
                            // Ziellinie (kcal / kJ)
                            goalValue: viewModel.chartGoalValue,
                            onMetricSelected: onMetricSelected,
                            onBack: onBack,
                            metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
                            showHeader: false          // Header in Card AUS – Sticky-Header übernimmt
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    viewModel.refresh()
                }
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

    return NutritionEnergyView(
        onMetricSelected: { _ in },
        onBack: { previewState.currentStatsScreen = .nutritionOverview }
    )
    .environmentObject(previewStore)
    .environmentObject(previewState)
}
