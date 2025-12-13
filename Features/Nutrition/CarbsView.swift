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

    // optionaler Back-Callback (kommt aus NutritionDashboardView)
    let onBack: (() -> Void)?

    /// Haupt-Init:
    /// - ohne ViewModel → CarbsViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: CarbsViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: (() -> Void)? = nil
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsViewModel())
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Domain-Hintergrund
            Color.Glu.nutritionAccent.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // 🔝 Sticky-Header für die Metric-View
                SectionHeader(
                    title: "Nutrition",
                    subtitle: nil,                       // Subtitle rausgenommen
                    tintColor: Color.Glu.nutritionAccent,
                    onBack: onBack                      // 🔥 Pfeil nur, wenn nicht nil
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        NutritionSectionCardScaled(
                            sectionTitle: "Nutrition",
                            title: "Carbs",
                            kpiTitle: "Carbs Today",
                            kpiTargetText: viewModel.formattedTargetCarbs,
                            kpiCurrentText: viewModel.formattedTodayCarbs,
                            kpiDeltaText: viewModel.formattedDeltaCarbs,
                            hasTarget: true,
                            last90DaysData: viewModel.last90DaysDataForChart,
                            periodAverages: viewModel.periodAverages,
                            monthlyData: viewModel.monthlyCarbsData,
                            dailyScale: viewModel.dailyScale,
                            periodScale: viewModel.periodScale,
                            monthlyScale: viewModel.monthlyScale,
                            goalValue: Int(viewModel.goalValueForChart),
                            onMetricSelected: onMetricSelected,
                            onBack: onBack ?? {},              // Fallback, falls nil
                            metrics: ["Carbs", "Protein", "Fat", "Nutrition Energy"],
                            showHeader: false                  // Header IN der Card AUS
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

#Preview("CarbsView – Nutrition Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()
    let viewModel   = CarbsViewModel(healthStore: healthStore)

    return CarbsView(
        viewModel: viewModel,
        onMetricSelected: { _ in },
        // ⬇️ Wenn du im Preview den Pfeil sehen willst:
        onBack: { print("Back tapped") }
        // oder: onBack: nil  → kein Pfeil im Preview
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
