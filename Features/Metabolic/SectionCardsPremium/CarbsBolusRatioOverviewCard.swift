//
//  CarbsBolusRatioOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Carbs/Bolus Ratio Overview Card (Wrapper for MetabolicRingRowCard)
//

import SwiftUI

// MARK: - Carbs/Bolus Ratio Overview Card (Metabolic) — Wrapper for MetabolicRingRowCard

struct CarbsBolusRatioOverviewCard: View {

    @StateObject private var viewModel: CarbsBolusRatioViewModelV1

    let onTap: () -> Void
    private let domainColor = Color.Glu.metabolicDomain

    init(
        healthStore: HealthStore,
        viewModel: CarbsBolusRatioViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsBolusRatioViewModelV1(healthStore: healthStore))
        }
        self.onTap = onTap
    }

    var body: some View {
        MetabolicRingRowCard(
            title: "Carbs/Bolus (g/U)",
            todayLabel: "Today",
            todayValue: viewModel.todayRatio,
            rings: [
                .init(label: "7d",  avgValue: avgRatio(days: 7)),
                .init(label: "14d", avgValue: avgRatio(days: 14)),
                .init(label: "30d", avgValue: avgRatio(days: 30)),
                .init(label: "90d", avgValue: avgRatio(days: 90))
            ],
            accentColor: domainColor,
            onTap: onTap
        )
    }

    private func avgRatio(days: Int) -> Double {
        let int10 = Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
        return int10 / 10.0
    }
}

// MARK: - Preview

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
