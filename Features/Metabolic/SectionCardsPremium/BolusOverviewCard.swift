//
//  BolusOverviewCard.swift
//  GluVibProbe
//

import SwiftUI

// MARK: - Bolus Overview Card (Metabolic) — Wrapper for MetabolicRingRowCard

struct BolusOverviewCard: View {

    @StateObject private var viewModel: BolusViewModelV1

    let onTap: () -> Void
    private let domainColor = Color.Glu.metabolicDomain

    init(
        healthStore: HealthStore,
        viewModel: BolusViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BolusViewModelV1(healthStore: healthStore))
        }
        self.onTap = onTap
    }

    var body: some View {
        MetabolicRingRowCard(
            title: "Bolus (U)",
            todayLabel: "Today",
            todayValue: viewModel.todayBolusUnits,
            rings: [
                .init(label: "7d",  avgValue: avgUnits(days: 7)),
                .init(label: "14d", avgValue: avgUnits(days: 14)),
                .init(label: "30d", avgValue: avgUnits(days: 30)),
                .init(label: "90d", avgValue: avgUnits(days: 90))
            ],
            accentColor: domainColor,
            onTap: onTap
        )
       
    }

    private func avgUnits(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }
}

// MARK: - Preview

#Preview("BolusOverviewCard") {
    let store = HealthStore.preview()
    let vm = BolusViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BolusOverviewCard(healthStore: store, viewModel: vm, onTap: {})
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
