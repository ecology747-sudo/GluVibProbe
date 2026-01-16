//
//  BasalOverviewCard.swift
//  GluVibProbe
//

import SwiftUI

// MARK: - Basal Overview Card (Metabolic) — Wrapper for MetabolicRingRowCard

struct BasalOverviewCard: View {

    @StateObject private var viewModel: BasalViewModelV1

    let onTap: () -> Void
    private let domainColor = Color.Glu.metabolicDomain

    // MARK: - Init (IMPORTANT: use the passed HealthStore instance)

    init(
        healthStore: HealthStore,
        viewModel: BasalViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BasalViewModelV1(healthStore: healthStore))
        }
        self.onTap = onTap
    }

    // MARK: - Body

    var body: some View {
        MetabolicRingRowCard(
            title: "Basal (U)",
            todayLabel: "Today",
            todayValue: viewModel.todayBasalUnits,
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

#Preview("BasalOverviewCard") {
    let store = HealthStore.preview()
    let vm = BasalViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BasalOverviewCard(healthStore: store, viewModel: vm, onTap: {})
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
