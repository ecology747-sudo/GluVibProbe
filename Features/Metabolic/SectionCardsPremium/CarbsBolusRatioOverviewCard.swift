//
//  CarbsBolusRatioOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Carbs/Bolus Ratio Overview Card
//
//  Purpose
//  - Wraps the shared MetabolicRingRowCard for the Carbs/Bolus Ratio overview section.
//  - Shows today's carbs/bolus ratio and 7d / 14d / 30d / 90d averages.
//  - Tapping the card routes to the Carbs/Bolus Ratio detail screen.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → CarbsBolusRatioViewModelV1 → CarbsBolusRatioOverviewCard
//

import SwiftUI

struct CarbsBolusRatioOverviewCard: View {

    // ============================================================
    // MARK: - State / Dependencies
    // ============================================================

    @StateObject private var viewModel: CarbsBolusRatioViewModelV1

    let onTap: () -> Void

    private let domainColor = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore,
        viewModel: CarbsBolusRatioViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: CarbsBolusRatioViewModelV1(healthStore: healthStore)
            )
        }

        self.onTap = onTap
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetabolicRingRowCard(
            title: L10n.MetabolicOverviewCarbsBolusRatio.cardTitle, // 🟨 UPDATED
            todayLabel: L10n.MetabolicOverviewCarbsBolusRatio.todayLabel, // 🟨 UPDATED
            todayValue: viewModel.todayRatio,
            rings: [
                .init(label: L10n.Common.period7d, avgValue: avgRatio(days: 7)),   // 🟨 UPDATED
                .init(label: L10n.Common.period14d, avgValue: avgRatio(days: 14)), // 🟨 UPDATED
                .init(label: L10n.Common.period30d, avgValue: avgRatio(days: 30)), // 🟨 UPDATED
                .init(label: L10n.Common.period90d, avgValue: avgRatio(days: 90))  // 🟨 UPDATED
            ],
            accentColor: domainColor,
            onTap: onTap
        )
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func avgRatio(days: Int) -> Double {
        let int10 = Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
        return int10 / 10.0
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("CarbsBolusRatioOverviewCard") {
    let store = HealthStore.preview()
    let vm = CarbsBolusRatioViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        CarbsBolusRatioOverviewCard(
            healthStore: store,
            viewModel: vm,
            onTap: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
