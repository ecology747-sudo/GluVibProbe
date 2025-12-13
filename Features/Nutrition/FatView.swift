//
//  FatView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Fat
//

import SwiftUI

struct FatView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: FatViewModel

    // MARK: - Callbacks

    let onMetricSelected: (String) -> Void
    let onBack: () -> Void          // Back-Callback (nicht optional, mit Default)

    // MARK: - Init

    init(
        viewModel: FatViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: @escaping () -> Void = {}              // Default-Closure
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: FatViewModel())
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Domain-Hintergrund
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {   // Sticky-Header + ScrollView

                // 🔝 Sticky-Header für Fat-Metric
                SectionHeader(
                    title: "Nutrition",
                    subtitle: "Fat",
                    tintColor: Color.Glu.nutritionAccent,
                    onBack: onBack
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Helper-basierte Nutrition-Section-Card OHNE eigenen Header
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
                            onBack: onBack,
                            metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
                            showHeader: false          // Header in Card AUS
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

#Preview("FatView – Nutrition Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = FatViewModel(healthStore: healthStore)

    return FatView(
        viewModel: viewModel,
        onMetricSelected: { _ in },
        onBack: { appState.currentStatsScreen = .nutritionOverview }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
