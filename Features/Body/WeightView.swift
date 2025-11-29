//
//  WeightView.swift
//  GluVibProbe
//
//  Body-Domain: Weight (live aus HealthStore, über WeightViewModel)
//

import SwiftUI

struct WeightView: View {

    @StateObject private var viewModel = WeightViewModel()

    // 🔗 Settings für Target Weight & Units
    @ObservedObject private var settings = SettingsModel.shared

    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var body: some View {

        // MARK: - KPI-Logik (Target / Current / Delta)

        let targetWeight = settings.targetWeightKg
        let targetWeightText: String = {
            guard targetWeight > 0 else { return "–" }
            return "\(targetWeight)"
        }()

        let currentWeightText: String = viewModel.formattedTodayWeight

        let deltaText: String = {
            let current = viewModel.todayWeightKg
            let target  = settings.targetWeightKg

            guard current > 0, target > 0 else { return "–" }

            let diff = current - target
            if diff == 0 { return "0" }

            let sign = diff > 0 ? "+" : "−"
            return "\(sign)\(abs(diff))"
        }()

        // Zielwert für grüne Linie im Chart
        let goalForChart: Int? = targetWeight > 0 ? targetWeight : nil

        return ZStack {
            // 👉 Body-Domain-Hintergrund (Orange, leicht transparent)
            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCard(
                        sectionTitle: "Body",
                        title: "Weight",
                        kpiTitle: "Weight Today",
                        kpiTargetText: targetWeightText,              // 🎯 Target aus Settings
                        kpiCurrentText: currentWeightText,           // 📊 aktuelles Gewicht
                        kpiDeltaText: deltaText,                     // 🔺 Delta (Current–Target)
                        hasTarget: true,                             // ✅ 3 KPIs aktiv
                        last90DaysData: viewModel.last90DaysDataForChart,
                        monthlyData: viewModel.monthlyWeightData,
                        dailyGoalForChart: goalForChart,             // ✅ grüne Linie im Chart
                        onMetricSelected: onMetricSelected,
                        metrics: ["Sleep", "Weight"],
                        monthlyMetricLabel: "Weight / Month",
                        periodAverages: viewModel.periodAverages,
                        showMonthlyChart: false,                     // Weight: kein Monats-Chart
                        scaleType: .smallInteger
                    )
                    .padding(.horizontal)

                }
                .padding(.top, 16)
            }
            .refreshable {
                // nutzt die bestehende Logik im ViewModel
                viewModel.refresh()}
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Preview

#Preview("WeightView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return WeightView()
        .environmentObject(appState)
        .environmentObject(healthStore)
}
