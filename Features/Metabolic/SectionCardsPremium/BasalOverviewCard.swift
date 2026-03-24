//
//  BasalOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Basal Overview Card
//
//  Purpose
//  - Wraps the shared MetabolicRingRowCard for the Basal overview section.
//  - Shows today's basal value and 7d / 14d / 30d / 90d averages.
//  - Tapping the card routes to the Basal detail screen.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BasalViewModelV1 → BasalOverviewCard
//

import SwiftUI

struct BasalOverviewCard: View {

    // ============================================================
    // MARK: - State / Dependencies
    // ============================================================

    @StateObject private var viewModel: BasalViewModelV1

    let onTap: () -> Void

    private let domainColor = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore,
        viewModel: BasalViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: BasalViewModelV1(healthStore: healthStore)
            )
        }

        self.onTap = onTap
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetabolicRingRowCard(
            title: L10n.MetabolicOverviewBasal.cardTitle, // 🟨 UPDATED
            todayLabel: L10n.MetabolicOverviewBasal.todayLabel, // 🟨 UPDATED
            todayValue: viewModel.todayBasalUnits,
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

#Preview("BasalOverviewCard") {
    let store = HealthStore.preview()
    let vm = BasalViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BasalOverviewCard(
            healthStore: store,
            viewModel: vm,
            onTap: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
