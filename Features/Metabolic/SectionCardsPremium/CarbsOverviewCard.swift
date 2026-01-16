//
//  CarbsOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Carbs Overview Card (Wrapper for MetabolicRingRowCard)
//

import SwiftUI

// MARK: - Carbs Overview Card (Metabolic) — Wrapper for MetabolicRingRowCard

struct CarbsOverviewCard: View {

    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: CarbsViewModelV1

    let onTap: () -> Void
    private let domainColor = Color.Glu.nutritionDomain   // ✅ UPDATED

    init(
        healthStore: HealthStore,
        settings: SettingsModel,
        viewModel: CarbsViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: CarbsViewModelV1(
                    healthStore: healthStore,
                    settings: settings
                )
            )
        }
        self.onTap = onTap
    }

    var body: some View {
        MetabolicRingRowCard(
            title: "Carbs (g)",
            todayLabel: "TODAY",
            todayValue: Double(viewModel.todayCarbsGrams),
            rings: [
                .init(label: "7d",  avgValue: avgGrams(days: 7)),
                .init(label: "14d", avgValue: avgGrams(days: 14)),
                .init(label: "30d", avgValue: avgGrams(days: 30)),
                .init(label: "90d", avgValue: avgGrams(days: 90))
            ],
            accentColor: domainColor,
            onTap: {
                onTap()
                appState.currentStatsScreen = .carbs
                appState.requestedTab = .nutrition
            }
        )
    }

    private func avgGrams(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }
}

// MARK: - Preview

#Preview("CarbsOverviewCard") {
    let store = HealthStore.preview()
    let settings = SettingsModel.shared
    let vm = CarbsViewModelV1(healthStore: store, settings: settings)
    let state = AppState()

    return VStack(spacing: 16) {
        CarbsOverviewCard(
            healthStore: store,
            settings: settings,
            viewModel: vm,
            onTap: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
    .environmentObject(store)
    .environmentObject(settings)
    .environmentObject(state)
}
