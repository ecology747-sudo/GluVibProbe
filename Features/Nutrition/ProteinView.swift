//
//  ProteinView.swift
//  GluVibProbe
//
//  Nutrition-Domain: Protein
//

import SwiftUI

struct ProteinView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: ProteinViewModel

    // Callback aus dem Nutrition-Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    // 🔙 Back-Callback (nicht optional, mit leerem Default)
    let onBack: () -> Void   // !!! CHANGED

    /// Haupt-Init:
    /// - ohne ViewModel → ProteinViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: ProteinViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: @escaping () -> Void = {}          // !!! CHANGED: Default-Closure statt Optional
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack                       // !!! CHANGED

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ProteinViewModel())
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Domain-Hintergrund
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {   // !!! CHANGED: Sticky-Header + ScrollView

                // 🔝 Sticky-Header für die Protein-Metric
                SectionHeader(
                    title: "Nutrition",
                    subtitle: "Protein",
                    tintColor: Color.Glu.nutritionAccent,
                    onBack: onBack
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // ✅ Helper-basierte Nutrition-Section-Card OHNE eigenen Header
                        NutritionSectionCardScaled(
                            sectionTitle: "Nutrition",
                            title: "Protein",
                            kpiTitle: "Protein Today",
                            kpiTargetText: viewModel.formattedTargetProtein,
                            kpiCurrentText: viewModel.formattedTodayProtein,
                            kpiDeltaText: viewModel.formattedDeltaProtein,
                            hasTarget: true,
                            last90DaysData: viewModel.last90DaysDataForChart,
                            periodAverages: viewModel.periodAverages,
                            monthlyData: viewModel.monthlyProteinData,
                            dailyScale: viewModel.dailyScale,
                            periodScale: viewModel.periodScale,
                            monthlyScale: viewModel.monthlyScale,
                            goalValue: viewModel.goalValueForChart,
                            onMetricSelected: onMetricSelected,
                            onBack: onBack,   // !!! CHANGED: nicht optional
                            metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
                            showHeader: false   // !!! CHANGED: Header in Card AUS
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

#Preview("ProteinView – Nutrition Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = ProteinViewModel(healthStore: healthStore)

    return ProteinView(
        viewModel: viewModel,
        onMetricSelected: { _ in },
        onBack: { appState.currentStatsScreen = .nutritionOverview }
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
