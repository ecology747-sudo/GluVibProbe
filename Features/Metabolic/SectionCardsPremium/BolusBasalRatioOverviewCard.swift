//
//  BolusBasalRatioOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Bolus/Basal Ratio Overview Card
//
//  Purpose
//  - Wraps the shared MetabolicRingRowCard for the Bolus/Basal Ratio overview section.
//  - Shows today's bolus/basal ratio and 7d / 14d / 30d / 90d averages.
//  - Tapping the card routes to the Bolus/Basal Ratio detail screen.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → BolusBasalRatioViewModelV1 → BolusBasalRatioOverviewCard
//

import SwiftUI

struct BolusBasalRatioOverviewCard: View {

    // ============================================================
    // MARK: - State / Dependencies
    // ============================================================

    @StateObject private var viewModel: BolusBasalRatioViewModelV1

    let onTap: () -> Void

    private let domainColor = Color.Glu.metabolicDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore,
        viewModel: BolusBasalRatioViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: BolusBasalRatioViewModelV1(healthStore: healthStore)
            )
        }

        self.onTap = onTap
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetabolicRingRowCard(
            title: L10n.MetabolicOverviewBolusBasalRatio.cardTitle, // 🟨 UPDATED
            todayLabel: L10n.MetabolicOverviewBolusBasalRatio.todayLabel, // 🟨 UPDATED
            todayValue: todayRatio,
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
    // MARK: - Derived Values
    // ============================================================

    private var todayRatio: Double {
        Double(viewModel.todayRatioInt10) / 10.0
    }

    private func avgRatio(days: Int) -> Double {
        let int10 = viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0
        return Double(int10) / 10.0
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("BolusBasalRatioOverviewCard") {
    let store = HealthStore.preview()
    let vm = BolusBasalRatioViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BolusBasalRatioOverviewCard(
            healthStore: store,
            viewModel: vm,
            onTap: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
