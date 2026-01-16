//
//  ActivityEnergyOverviewCard.swift
//  GluVibProbe
//
//  Home/Deep-Link Card — Activity Energy (kcal)
//  - Same flow as CarbsOverviewCard:
//    Tap -> appState.currentStatsScreen + appState.requestedTab
//

import SwiftUI

// MARK: - Activity Energy Overview Card — Wrapper for MetabolicRingRowCard

struct ActivityEnergyOverviewCard: View {

    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: ActivityEnergyViewModelV1

    let onTap: () -> Void
    private let accentColor = Color.Glu.activityDomain

    init(
        healthStore: HealthStore,
        viewModel: ActivityEnergyViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ActivityEnergyViewModelV1(healthStore: healthStore))
        }
        self.onTap = onTap
    }

    var body: some View {
        MetabolicRingRowCard(
            title: "Active Energy (kcal)",
            todayLabel: "TODAY",
            todayValue: todayKcalValue,
            rings: [
                .init(label: "7d",  avgValue: avg(days: 7)),
                .init(label: "14d", avgValue: avg(days: 14)),
                .init(label: "30d", avgValue: avg(days: 30)),
                .init(label: "90d", avgValue: avg(days: 90))
            ],
            accentColor: accentColor,
            onTap: {
                onTap()
                appState.currentStatsScreen = .activityEnergy
                appState.requestedTab = .activity
            }
        )
    }

    // MARK: - Derived

    private var todayKcalValue: Double {
        // 1) Prefer "today" from chart data (robust, no new VM props needed)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let entry = viewModel.last90DaysChartData.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            return Double(entry.steps)
        }

        // 2) Fallback: parse "1234 kcal" from formatted string
        return Double(parseKcal(viewModel.formattedTodayActiveEnergy))
    }

    private func avg(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }

    private func parseKcal(_ text: String) -> Int {
        // e.g. "1.234 kcal" / "1234 kcal" / "0 kcal"
        let cleaned = text
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let nf = NumberFormatter()
        nf.numberStyle = .decimal

        if let n = nf.number(from: cleaned) {
            return max(0, n.intValue)
        }

        // last resort: keep digits only
        let digitsOnly = cleaned.filter { $0.isNumber }
        return max(0, Int(digitsOnly) ?? 0)
    }
}

// MARK: - Preview

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
