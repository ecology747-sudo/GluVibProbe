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

    // ============================================================
    // MARK: - Header Badge
    // ============================================================

    private var glucoseAttentionBadgeV1: Bool { // 🟨 NEW
        settings.hasCGM && settings.showPermissionWarnings && healthStore.glucoseAnyAttentionForBadgesV1
    }

    // ============================================================
    // MARK: - Today Hint
    // ============================================================

    private var localizedTodayHint: String? { // 🟨 NEW
        guard settings.showPermissionWarnings else { return nil }
        guard let state = viewModel.todayInfoState else { return nil }

        switch state {
        case .noHistory:
            return L10n.Range.hintNoDataOrPermission
        case .noTodayData:
            return L10n.Range.hintNoToday
        }
    }

    // ============================================================
    // MARK: - Chip Badge Mapping
    // ============================================================

    private func showsMetabolicWarningBadge(for metric: String) -> Bool {
        switch metric {

        case L10n.IG.title,
             L10n.TimeInRange.title,
             L10n.GMI.title,
             L10n.SD.title,
             L10n.CV.title,
             L10n.Range.title:
            return settings.hasCGM && healthStore.glucoseAnyAttentionForBadgesV1 // 🟨 NEW

        case L10n.Bolus.title:
            return settings.hasCGM && settings.isInsulinTreated && healthStore.bolusAnyAttentionForBadgesV1 // 🟨 NEW

        case L10n.Basal.title:
            return settings.hasCGM && settings.isInsulinTreated && healthStore.basalAnyAttentionForBadgesV1 // 🟨 NEW

        case L10n.BolusBasalRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && (healthStore.bolusAnyAttentionForBadgesV1 || healthStore.basalAnyAttentionForBadgesV1) // 🟨 NEW

        case L10n.CarbsBolusRatio.title:
            return settings.hasCGM
                && settings.isInsulinTreated
                && (healthStore.carbsReadAuthIssueV1 || healthStore.bolusAnyAttentionForBadgesV1) // 🟨 NEW

        default:
            return false
        }
    }

    var body: some View {

        let tiles: [RangeBarGridSectionV1.TileInput] = [
            .init(
                title: L10n.Range.period7dTitle,
                summary: viewModel.summary7d,
                periodText: viewModel.periodCVWholeText(last: 7)
            ),
            .init(
                title: L10n.Range.period14dTitle,
                summary: viewModel.summary14d,
                periodText: viewModel.periodCVWholeText(last: 14)
            ),
            .init(
                title: L10n.Range.period30dTitle,
                summary: viewModel.summary30d,
                periodText: viewModel.periodCVWholeText(last: 30)
            ),
            .init(
                title: L10n.Range.period90dTitle,
                summary: viewModel.summary90d,
                periodText: viewModel.periodCVWholeText(last: 90)
            )
        ]

        MetricDetailScaffold(
            headerTitle: L10n.Common.metabolicHeader,
            headerTint: color,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: { await healthStore.refreshMetabolic(.pullToRefresh) },
            showsPermissionBadge: glucoseAttentionBadgeV1,
            background: {
                LinearGradient(
                    colors: [.white, color.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                if let hint = localizedTodayHint { // 🟨 NEW
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                MetricChipGroup(
                    row1: row1,
                    row2: row2,
                    selected: L10n.Range.title,
                    accent: color,
                    onSelect: onMetricSelected,
                    showsWarningBadge: { metric in
                        showsMetabolicWarningBadge(for: metric)
                    }
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
