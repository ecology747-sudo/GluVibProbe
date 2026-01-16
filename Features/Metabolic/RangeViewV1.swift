//
//  RangeViewV1.swift
//  GluVibProbe
//

import SwiftUI

struct RangeViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @StateObject private var viewModel: RangeViewModelV1

    let onMetricSelected: (String) -> Void
    private let color = Color.Glu.metabolicDomain

    init(
        viewModel: RangeViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: RangeViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Capability-aware Metrics (Chips)
    // ============================================================

    private var visibleMetrics: [String] {
        AppState.metabolicVisibleMetrics(settings: settings)
    }

    private var row1: [String] { Array(visibleMetrics.prefix(4)) }
    private var row2: [String] { Array(visibleMetrics.dropFirst(4)) }

    var body: some View {

        let tiles: [RangeBarGridSectionV1.TileInput] = [
            .init(
                title: "7 Days",
                summary: viewModel.summary7d,
                periodText: viewModel.periodCVWholeText(last: 7)      // !!! NEW
            ),
            .init(
                title: "14 Days",
                summary: viewModel.summary14d,
                periodText: viewModel.periodCVWholeText(last: 14)     // !!! NEW
            ),
            .init(
                title: "30 Days",
                summary: viewModel.summary30d,
                periodText: viewModel.periodCVWholeText(last: 30)     // !!! NEW
            ),
            .init(
                title: "90 Days",
                summary: viewModel.summary90d,
                periodText: viewModel.periodCVWholeText(last: 90)     // !!! NEW
            )
        ]

        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: color,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: { await healthStore.refreshMetabolic(.pullToRefresh) },
            background: {
                LinearGradient(
                    colors: [.white, color.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                MetricChipGroup(
                    row1: row1,
                    row2: row2,
                    selected: "Range",
                    accent: color,
                    onSelect: onMetricSelected
                )

                RangeThresholdLegendV1(
                    onOpenSettings: {
                        appState.currentStatsScreen = .none
                        appState.settingsStartDomain = .metabolic
                        appState.currentStatsScreen = .none
                        appState.requestedTab = .home
                    }
                )
                .environmentObject(settings)

                RangeBarGridSectionV1(tiles: tiles)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .task {
            await healthStore.refreshMetabolic(.navigation)
        }
    }
}

// MARK: - Preview

#Preview("RangeViewV1 – Metabolic") {
    let previewStore = HealthStore.preview()
    let previewVM = RangeViewModelV1(healthStore: previewStore)
    let previewState = AppState()
    previewState.currentStatsScreen = .range

    return RangeViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
