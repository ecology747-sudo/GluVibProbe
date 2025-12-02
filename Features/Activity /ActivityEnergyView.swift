//
//  ActivityEnergyView.swift
//  GluVibProbe
//
//  Reine View für den Activity-Energy-Screen (MVVM)
//

import SwiftUI

struct ActivityEnergyView: View {

    @StateObject private var viewModel: ActivityEnergyViewModel

    // 🔗 globale Settings (u. a. Energy-Unit: kcal / kJ)
    @ObservedObject private var settings = SettingsModel.shared

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    /// Haupt-Init für die App:
    /// - ohne ViewModel → ActivityEnergyViewModel benutzt automatisch HealthStore.shared
    /// - mit ViewModel → z.B. in Previews kann ein spezielles VM übergeben werden
    init(
        viewModel: ActivityEnergyViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ActivityEnergyViewModel())
        }
    }

    var body: some View {

        // 🔧 Skala abhängig von der Energy-Unit wählen:
        // - kcal  → kleine Werte → .smallInteger
        // - kJ    → große Werte  → .steps (wie Steps, mit größeren Achsenabständen)
        let scaleType: MetricScaleType = {
            switch settings.energyUnit {
            case .kcal:
                return .smallInteger
            case .kilojoules:
                return .steps
            }
        }()

        return ZStack {
            // Hintergrund für den Bereich „Körper & Aktivität“
            Color.Glu.activityAccent.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Haupt-Section mit KPI + Charts (Activity Energy)
                    ActivitySectionCard(
                        sectionTitle: "Activity",
                        title: "Activity Energy",
                        kpiTitle: "Active Energy Today",
                        kpiTargetText: "–",                          // aktuell kein Ziel
                        kpiCurrentText: viewModel.formattedTodayActiveEnergy,
                        kpiDeltaText: "–",                            // kein Delta, da kein Ziel
                        hasTarget: false,                             // ❗ nur Current-KPI
                        last90DaysData: viewModel.last90DaysData,
                        monthlyData: viewModel.monthlyActiveEnergyData,
                        dailyGoalForChart: nil,                       // keine RuleMark-Linie
                        onMetricSelected: onMetricSelected,
                        metrics: ["Steps", "Activity Energy"],
                        monthlyMetricLabel: "Active Energy / Month",
                        periodAverages: viewModel.periodAverages,
                        scaleType: scaleType                          // ⬅️ hier dynamisch
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

#Preview("ActivityEnergyView – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = ActivityEnergyViewModel(healthStore: previewStore)

    ActivityEnergyView(viewModel: previewVM)
        .environmentObject(previewStore)
}
