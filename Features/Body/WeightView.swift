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

        // MARK: - Helper für kg/lbs

        func convertKg(_ value: Int, to unit: WeightUnit) -> Int {
            guard value > 0 else { return 0 }

            switch unit {
            case .kg:
                return value
            case .lbs:
                return Int((Double(value) * 2.20462).rounded())
            }
        }

        func formatWeight(_ valueKg: Int, unit: WeightUnit) -> String {
            let v = convertKg(valueKg, to: unit)
            guard v > 0 else { return "–" }
            return "\(v) \(unit.label)"
        }

        // MARK: - KPI-Logik (Target / Current / Delta)

        let unit           = settings.weightUnit          // .kg oder .lbs
        let targetWeightKg = settings.targetWeightKg      // Basis immer kg
        let currentKg      = viewModel.todayWeightKg      // Basis immer kg

        let targetWeightText: String  = formatWeight(targetWeightKg, unit: unit)
        let currentWeightText: String = formatWeight(currentKg,      unit: unit)

        let deltaText: String = {
            guard currentKg > 0, targetWeightKg > 0 else { return "–" }

            let current = convertKg(currentKg,      to: unit)
            let target  = convertKg(targetWeightKg, to: unit)
            let diff    = current - target

            if diff == 0 { return "0 \(unit.label)" }

            let sign = diff > 0 ? "+" : "−"
            return "\(sign)\(abs(diff)) \(unit.label)"
        }()

        // Zielwert für grüne Linie im Chart (in Anzeigeneinheit)
        let goalForChart: Int? = {
            guard targetWeightKg > 0 else { return nil }
            let converted = convertKg(targetWeightKg, to: unit)
            return converted > 0 ? converted : nil
        }()

        // Last-90-Days-Chart in gewünschter Einheit
        let last90DaysForChart: [DailyStepsEntry] = {
            let source = viewModel.last90DaysDataForChart

            // kg → direkt
            if unit == .kg { return source }

            // lbs → Werte konvertieren
            return source.map { entry in
                let lbs = convertKg(entry.steps, to: .lbs)
                return DailyStepsEntry(date: entry.date, steps: lbs)
            }
        }()

        // Perioden-Durchschnitte in gewünschter Einheit
        let periodAveragesForUnit: [PeriodAverageEntry] = {
            let base = viewModel.periodAverages

            if unit == .kg { return base }

            return base.map { entry in
                let lbsValue = convertKg(entry.value, to: .lbs)
                return PeriodAverageEntry(
                    label: entry.label,
                    days: entry.days,
                    value: lbsValue
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
                        monthlyData: viewModel.monthlyWeightData, // (Monatschart aktuell aus)
                        dailyGoalForChart: goalForChart,          // ✅ Linie in derselben Einheit
                        onMetricSelected: onMetricSelected,
                        metrics: ["Sleep", "Weight"],
                        monthlyMetricLabel: "Weight / Month",
                        periodAverages: periodAveragesForUnit,    // Balken 7T/14T/... in kg/lbs
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
