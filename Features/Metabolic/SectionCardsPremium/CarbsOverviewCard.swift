//
//  CarbsOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Carbs Overview Card
//
//  Purpose
//  - Wraps the shared MetabolicRingRowCard for the Carbs overview section.
//  - Shows today's carbs value and 7d / 14d / 30d / 90d averages.
//  - Tapping the card routes to the Nutrition domain → Carbs detail screen.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) + SettingsModel → CarbsViewModelV1 → CarbsOverviewCard
//

import SwiftUI

struct CarbsOverviewCard: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: CarbsViewModelV1

    let onTap: () -> Void

    private let domainColor = Color.Glu.nutritionDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

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

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetabolicRingRowCard(
            title: L10n.MetabolicOverviewCarbs.cardTitle, // 🟨 UPDATED
            todayLabel: L10n.MetabolicOverviewCarbs.todayLabel, // 🟨 UPDATED
            todayValue: Double(viewModel.todayCarbsGrams),
            rings: [
                .init(label: L10n.Common.period7d, avgValue: avgGrams(days: 7)),   // 🟨 UPDATED
                .init(label: L10n.Common.period14d, avgValue: avgGrams(days: 14)), // 🟨 UPDATED
                .init(label: L10n.Common.period30d, avgValue: avgGrams(days: 30)), // 🟨 UPDATED
                .init(label: L10n.Common.period90d, avgValue: avgGrams(days: 90))  // 🟨 UPDATED
            ],
            accentColor: domainColor,
            onTap: {
                onTap()
                appState.currentStatsScreen = .carbs
                appState.requestedTab = .nutrition
            }
        )
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func avgGrams(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

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
