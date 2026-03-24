//
//  ActivityEnergyOverviewCard.swift
//  GluVibProbe
//
//  Metabolic V1 — Activity Energy Overview Card
//
//  Purpose
//  - Wraps the shared MetabolicRingRowCard for the Activity Energy overview section.
//  - Shows today's active energy value and 7d / 14d / 30d / 90d averages.
//  - Tapping the card routes into the Activity domain → Activity Energy detail screen.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → ActivityEnergyViewModelV1 → ActivityEnergyOverviewCard
//

import SwiftUI

struct ActivityEnergyOverviewCard: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: ActivityEnergyViewModelV1

    let onTap: () -> Void

    private let accentColor = Color.Glu.activityDomain

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore,
        viewModel: ActivityEnergyViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(
                wrappedValue: ActivityEnergyViewModelV1(healthStore: healthStore)
            )
        }

        self.onTap = onTap
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        MetabolicRingRowCard(
            title: L10n.MetabolicOverviewActivityEnergy.cardTitle, // 🟨 UPDATED
            todayLabel: L10n.MetabolicOverviewActivityEnergy.todayLabel, // 🟨 UPDATED
            todayValue: todayKcalValue,
            rings: [
                .init(label: L10n.Common.period7d, avgValue: avg(days: 7)),   // 🟨 UPDATED
                .init(label: L10n.Common.period14d, avgValue: avg(days: 14)), // 🟨 UPDATED
                .init(label: L10n.Common.period30d, avgValue: avg(days: 30)), // 🟨 UPDATED
                .init(label: L10n.Common.period90d, avgValue: avg(days: 90))  // 🟨 UPDATED
            ],
            accentColor: accentColor,
            onTap: {
                onTap()
                appState.currentStatsScreen = .activityEnergy
                appState.requestedTab = .activity
            }
        )
    }

    // ============================================================
    // MARK: - Derived Values
    // ============================================================

    private var todayKcalValue: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let entry = viewModel.last90DaysChartData.first(where: {
            calendar.isDate($0.date, inSameDayAs: today)
        }) {
            return Double(entry.steps)
        }

        return Double(parseKcal(viewModel.formattedTodayActiveEnergy))
    }

    private func avg(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }

    private func parseKcal(_ text: String) -> Int {
        let cleaned = text
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if let number = formatter.number(from: cleaned) {
            return max(0, number.intValue)
        }

        let digitsOnly = cleaned.filter { $0.isNumber }
        return max(0, Int(digitsOnly) ?? 0)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ActivityEnergyOverviewCard") {
    let store = HealthStore.preview()
    let state = AppState()
    let vm = ActivityEnergyViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        ActivityEnergyOverviewCard(
            healthStore: store,
            viewModel: vm,
            onTap: {}
        )
        .padding(.horizontal, 16)
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
    .environmentObject(store)
    .environmentObject(state)
    .environmentObject(SettingsModel.shared)
}
