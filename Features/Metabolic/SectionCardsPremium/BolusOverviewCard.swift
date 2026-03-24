//
//  BolusOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Bolus Overview Card
//
//  Purpose
//  - Wraps the shared MetabolicRingRowCard for the Bolus overview section.
//  - Shows today's bolus value and 7d / 14d / 30d / 90d averages.
//  - Tapping the card routes to the Bolus detail screen.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BolusViewModelV1 → BolusOverviewCard
//

import SwiftUI

struct BolusOverviewCard: View {

    // ============================================================
    // MARK: - State / Dependencies
    // ============================================================

    @StateObject private var viewModel: BolusViewModelV1

    let onTap: () -> Void

    private let domainColor = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore,
        viewModel: BolusViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: BolusViewModelV1(healthStore: healthStore)
            )
        }

        self.onTap = onTap
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetabolicRingRowCard(
            title: L10n.MetabolicOverviewBolus.cardTitle, // 🟨 UPDATED
            todayLabel: L10n.MetabolicOverviewBolus.todayLabel, // 🟨 UPDATED
            todayValue: viewModel.todayBolusUnits,
            rings: [
                .init(label: L10n.Common.period7d, avgValue: avgUnits(days: 7)),   // 🟨 UPDATED
                .init(label: L10n.Common.period14d, avgValue: avgUnits(days: 14)), // 🟨 UPDATED
                .init(label: L10n.Common.period30d, avgValue: avgUnits(days: 30)), // 🟨 UPDATED
                .init(label: L10n.Common.period90d, avgValue: avgUnits(days: 90))  // 🟨 UPDATED
            ],
            accentColor: domainColor,
            onTap: onTap
        )
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func avgUnits(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("BolusOverviewCard") {
    let store = HealthStore.preview()
    let vm = BolusViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BolusOverviewCard(
            healthStore: store,
            viewModel: vm,
            onTap: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
