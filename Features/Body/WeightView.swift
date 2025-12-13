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

    // 🔗 HealthStore für den echten Double-Wert aus HealthKit
    @EnvironmentObject private var healthStore: HealthStore

    let onMetricSelected: (String) -> Void

    // optionaler Back-Callback
    let onBack: (() -> Void)?

    init(
        onMetricSelected: @escaping (String) -> Void = { _ in },
        onBack: (() -> Void)? = nil
    ) {
        self.onMetricSelected = onMetricSelected
        self.onBack = onBack
    }

    var body: some View {

        // MARK: - Basis: aktuelle Einheit + kg-Werte aus Model

        let unit              = settings.weightUnit           // .kg oder .lbs
        let targetWeightKgInt = settings.targetWeightKg       // Basis-Target (Int, wie gehabt)
        let currentKgInt      = viewModel.effectiveTodayWeightKg   // Fallback-Int

        // Echter HealthKit-Wert als Double für KPI
        let currentKgRaw      = healthStore.todayWeightKgRaw

        // Wenn HealthKit einen Double-Wert liefert → den nehmen,
        // sonst auf das bisherige Int-Fallback gehen.
        let currentKgForKPI: Double = currentKgRaw > 0
            ? currentKgRaw
            : Double(currentKgInt)

        let targetKgForKPI: Double = Double(targetWeightKgInt)

        // MARK: - KPI-Texte (mit echter Nachkommastelle)

        let targetWeightText: String  = formatWeightKPI(kg: targetKgForKPI, unit: unit)
        let currentWeightText: String = formatWeightKPI(kg: currentKgForKPI, unit: unit)
        let deltaText: String         = formatDeltaKPI(
            currentKg: currentKgForKPI,
            targetKg: targetKgForKPI,
            unit: unit
        )

        // Zielwert für Linie im Chart (weiterhin Int, keine Nachkommastellen nötig)
        let goalForChart: Int? = {
            guard targetWeightKgInt > 0 else { return nil }
            let convertedInt = unit.convertedValue(fromKg: targetWeightKgInt)
            return convertedInt > 0 ? convertedInt : nil
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
                        metrics: [
                            "Weight",
                            "Sleep",
                            "BMI",
                            "Body Fat",
                            "Resting Heart Rate"
                        ],
                        showMonthlyChart: false,
                        scaleType: .weightKg,
                        chartStyle: .bar,
                        onBack: onBack
                    )
                    .padding(.horizontal)
                }
               
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

// MARK: - KPI Formatting Helpers (1 echte Nachkommastelle)

private extension WeightView {

    /// Formatiert einen kg-Wert für KPI (Target / Current) mit 1 Nachkommastelle,
    /// z. B. "94,3 kg" oder "207,7 lbs" – basierend auf der eingestellten Einheit.
    func formatWeightKPI(kg: Double, unit: WeightUnit) -> String {
        guard kg > 0 else { return "–" }

        let valueInUnit = convertFromKg(kg, to: unit)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1

        let text = formatter.string(from: NSNumber(value: valueInUnit))
            ?? String(format: "%.1f", valueInUnit)

        return "\(text) \(unit.label)"
    }

    /// Formatiert das Delta zwischen aktuellem und Zielgewicht:
    /// "+1,7 kg", "−2,3 kg" – ebenfalls mit 1 Nachkommastelle, basierend auf echten Doubles.
    func formatDeltaKPI(currentKg: Double, targetKg: Double, unit: WeightUnit) -> String {
        guard currentKg > 0, targetKg > 0 else { return "–" }

        let diffKg = currentKg - targetKg
        if abs(diffKg) < 0.0001 {
            return "0,0 \(unit.label)"
        }

        let sign = diffKg > 0 ? "+" : "−"
        let diffAbsKg = abs(diffKg)

        let valueInUnit = convertFromKg(diffAbsKg, to: unit)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1

        let text = formatter.string(from: NSNumber(value: valueInUnit))
            ?? String(format: "%.1f", valueInUnit)

        return "\(sign)\(text) \(unit.label)"
    }

    /// Umrechnung kg → gewählte Einheit als Double
    func convertFromKg(_ valueKg: Double, to unit: WeightUnit) -> Double {
        switch unit {
        case .kg:
            return valueKg
        case .lbs:
            return valueKg * 2.20462
        }
    }
}

// MARK: - Preview

#Preview("WeightView – Body Domain") {
    let appState    = AppState()
    let healthStore = HealthStore.preview()

    return WeightView(
        onMetricSelected: { _ in },
        onBack: nil
    )
    .environmentObject(appState)
    .environmentObject(healthStore)
}
