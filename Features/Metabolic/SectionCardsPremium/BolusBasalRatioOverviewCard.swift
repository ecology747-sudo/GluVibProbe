//
//  BolusBasalRatioOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Bolus/Basal Ratio Overview Card (Wrapper for MetabolicRingRowCard)
//

import SwiftUI

// MARK: - Bolus/Basal Ratio Overview Card (Metabolic) — Wrapper for MetabolicRingRowCard

struct BolusBasalRatioOverviewCard: View {

    @StateObject private var viewModel: BolusBasalRatioViewModelV1

    let onTap: () -> Void
    private let domainColor = Color.Glu.metabolicDomain

    init(
        healthStore: HealthStore,
        viewModel: BolusBasalRatioViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BolusBasalRatioViewModelV1(healthStore: healthStore))
        }
        self.onTap = onTap
    }

    var body: some View {
        MetabolicRingRowCard(
            title: "Bolus/Basal Ratio",
            todayLabel: "Today",
            todayValue: todayRatio,
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

    private var todayRatio: Double {
        Double(viewModel.todayRatioInt10) / 10.0
    }

    private func avgRatio(days: Int) -> Double {
        let int10 = viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0
        return Double(int10) / 10.0
    }
}

// MARK: - Preview

#Preview("BolusBasalRatioOverviewCard") {
    let store = HealthStore.preview()
    let vm = BolusBasalRatioViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BolusBasalRatioOverviewCard(healthStore: store, viewModel: vm, onTap: {})
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
