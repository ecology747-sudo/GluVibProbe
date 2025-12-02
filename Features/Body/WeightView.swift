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

        // Zielwert für grüne Linie im Chart (in Anzeigeneinheit)
        let goalForChart: Int? = {
            guard targetWeightKg > 0 else { return nil }
            let converted = unit.convertedValue(fromKg: targetWeightKg)
            return converted > 0 ? converted : nil
        }()

        // Last-90-Days-Chart in gewünschter Einheit
        let last90DaysForChart: [DailyStepsEntry] = {
            let source = viewModel.last90DaysDataForChart  // immer kg

            // kg → direkt
            if unit == .kg { return source }

            // lbs → Werte konvertieren über WeightUnit
            return source.map { entry in
                let converted = unit.convertedValue(fromKg: entry.steps)
                return DailyStepsEntry(date: entry.date, steps: converted)
            }
        }()

        // Perioden-Durchschnitte in gewünschter Einheit
        let periodAveragesForUnit: [PeriodAverageEntry] = {
            let base = viewModel.periodAverages   // Werte in kg

            if unit == .kg { return base }

            return base.map { entry in
                let converted = unit.convertedValue(fromKg: entry.value)
                return PeriodAverageEntry(
                    label: entry.label,
                    days: entry.days,
                    value: converted
                )
            }
        }()

        // MARK: - View

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
                        kpiTargetText: targetWeightText,          // 🎯 Target inkl. Einheit
                        kpiCurrentText: currentWeightText,        // 📊 Current inkl. Einheit
                        kpiDeltaText: deltaText,                  // 🔺 Delta inkl. Einheit
                        hasTarget: true,                          // ✅ 3 KPIs aktiv
                        last90DaysData: last90DaysForChart,       // 📈 Daten in kg oder lbs
                        monthlyData: viewModel.monthlyWeightData, // Monatsdaten (aktuell optional)
                        dailyGoalForChart: goalForChart,          // ✅ Linie in derselben Einheit
                        onMetricSelected: onMetricSelected,
                        metrics: ["Sleep", "Weight"],
                        monthlyMetricLabel: "Weight / Month",
                        periodAverages: periodAveragesForUnit,    // 7T/14T/... in kg/lbs
                        showMonthlyChart: false,                  // Weight: kein Monats-Chart
                        scaleType: .smallInteger
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
