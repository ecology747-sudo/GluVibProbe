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

        // MARK: - Basis: aktuelle Einheit + kg-Werte aus Model

        let unit           = settings.weightUnit          // .kg oder .lbs
        let targetWeightKg = settings.targetWeightKg      // Basis immer kg
        let currentKg      = viewModel.todayWeightKg      // Basis immer kg

        // MARK: - KPI-Texte (nutzen zentrale WeightUnit-Logik)

        let targetWeightText: String = unit.formatted(fromKg: targetWeightKg)
        let currentWeightText: String = unit.formatted(fromKg: currentKg)

        let deltaText: String = {
            guard currentKg > 0, targetWeightKg > 0 else { return "–" }

            // Differenz immer in kg berechnen
            let diffKg = currentKg - targetWeightKg
            if diffKg == 0 {
                return "0 \(unit.label)"
            }

            let sign = diffKg > 0 ? "+" : "−"
            let diffDisplay = unit.convertedValue(fromKg: abs(diffKg))
            return "\(sign)\(diffDisplay) \(unit.label)"
        }()

        // Zielwert für Linie im Chart (in Anzeigeneinheit)
        let goalForChart: Int? = {
            guard targetWeightKg > 0 else { return nil }
            let converted = unit.convertedValue(fromKg: targetWeightKg)
            return converted > 0 ? converted : nil
        }()

        // MARK: - View

        return ZStack {
            // 👉 Body-Domain-Hintergrund
            Color.Glu.bodyAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    BodySectionCardScaled(
                        sectionTitle: "Body",
                        title: "Weight",
                        kpiTitle: "Weight Today",
                        kpiTargetText: targetWeightText,
                        kpiCurrentText: currentWeightText,
                        kpiDeltaText: deltaText,
                        hasTarget: true,
                        last90DaysData: viewModel.last90DaysDataForChart,
                        periodAverages: viewModel.periodAveragesForChart,
                        monthlyData: viewModel.monthlyData,
                        dailyScale: viewModel.dailyScale,
                        periodScale: viewModel.periodScale,
                        monthlyScale: viewModel.monthlyScale,
                        goalValue: goalForChart,
                        onMetricSelected: onMetricSelected,
                        metrics: ["Sleep", "Weight"],
                        showMonthlyChart: false,
                        scaleType: .weightKg       // ⬅️ neu
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

#Preview("WeightView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return WeightView()
        .environmentObject(appState)
        .environmentObject(healthStore)
}
