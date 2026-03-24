//
//  CarbsDaypartsViewV1.swift
//  GluVibProbe
//
//  Nutrition V1 — Carbs Dayparts Detail Screen
//
//  Purpose
//  - Renders the carbohydrate dayparts metric detail screen for the Nutrition domain.
//  - Shows the current daypart hint state, three daypart KPI tiles,
//    and the custom dayparts chart inside the shared nutrition metric card shell.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → CarbsDaypartsViewModelV1 (mapping / formatting) → CarbsDaypartsViewV1 (render only)
//
//  Key Connections
//  - CarbsDaypartsViewModelV1: provides the daypart values, chart data and today hint text.
//  - HealthStore: provides the central nutrition badge / attention sources.
//  - AppState: handles navigation and metric routing.
//  - NutritionSectionCardScaledV2: shared nutrition card shell for chips, KPI area and chart area.
//  - L10n: localized titles and labels for the carbs dayparts metric.
//

import SwiftUI

struct CarbsDaypartsViewV1: View {

    // ============================================================
    // MARK: - Dependencies (Environment)
    // ============================================================

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - ViewModel
    // ============================================================

    @StateObject private var viewModel: CarbsDaypartsViewModelV1

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onMetricSelected: (String) -> Void

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        viewModel: CarbsDaypartsViewModelV1? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CarbsDaypartsViewModelV1())
        }
    }

    // ============================================================
    // MARK: - Header Badge Gate (Nutrition / Carbs Dayparts)
    // ============================================================

    private var carbsAttentionBadgeV1: Bool { // 🟨 UPDATED
        settings.showPermissionWarnings && healthStore.carbsAnyAttentionForBadgesV1
    }

    // ============================================================
    // MARK: - Time Logic (strict daypart display rules)
    // ============================================================

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }

    private var morningStarted: Bool { hour >= 6 }
    private var afternoonStarted: Bool { hour >= 12 }
    private var nightActive: Bool { hour >= 18 || hour < 6 }

    private var morningDisplayGrams: Int {
        morningStarted ? viewModel.todayMorningGrams : viewModel.yesterdayMorningGrams
    }

    private var afternoonDisplayGrams: Int {
        afternoonStarted ? viewModel.todayAfternoonGrams : viewModel.yesterdayAfternoonGrams
    }

    private var nightDisplayGrams: Int {
        (hour >= 18) ? viewModel.todayNightGrams : viewModel.yesterdayNightGrams
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {

        MetricDetailScaffold(
            headerTitle: L10n.Common.tabNutrition,
            headerTint: Color.Glu.nutritionDomain,
            onBack: {
                appState.currentStatsScreen = .nutritionOverview
            },
            onRefresh: {
                await healthStore.refreshNutrition(.pullToRefresh)
            },
            showsPermissionBadge: carbsAttentionBadgeV1,
            background: {
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.nutritionDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                // Today info / hint text from ViewModel
                if let hint = viewModel.todayInfoText { // 🟨 UPDATED
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .padding(.horizontal, 2)
                }

                // Shared Nutrition metric card shell with custom KPI + custom chart content
                NutritionSectionCardScaledV2(
                    sectionTitle: "",
                    title: L10n.CarbsDayparts.title,

                    kpiTitle: "",
                    kpiTargetText: "–",
                    kpiCurrentText: "–",
                    kpiDeltaText: "–",
                    kpiDeltaColor: nil,
                    hasTarget: false,

                    last90DaysData: [],
                    periodAverages: [],
                    monthlyData: [],

                    dailyScale: MetricScaleHelper.scale([], for: .grams),
                    periodScale: MetricScaleHelper.scale([], for: .grams),
                    monthlyScale: MetricScaleHelper.scale([], for: .grams),

                    goalValue: nil,

                    onMetricSelected: { metric in
                        appState.handleMetricTap(metricName: metric, settings: settings)
                    },
                    metrics: AppState.nutritionVisibleMetrics,

                    showsDailyChart: false,
                    showsPeriodChart: false,
                    showsMonthlyChart: false,

                    customKpiContent: AnyView(
                        HStack(alignment: .top, spacing: 10) {

                            splitKpiTile(
                                label: L10n.CarbsDayparts.morning,
                                grams: morningDisplayGrams,
                                stroke: Color.Glu.bodyDomain,
                                fillEnabled: morningStarted,
                                fillColor: Color.Glu.bodyDomain
                            )

                            splitKpiTile(
                                label: L10n.CarbsDayparts.afternoon,
                                grams: afternoonDisplayGrams,
                                stroke: Color.Glu.metabolicDomain,
                                fillEnabled: afternoonStarted,
                                fillColor: Color.Glu.metabolicDomain
                            )

                            splitKpiTile(
                                label: L10n.CarbsDayparts.night,
                                grams: nightDisplayGrams,
                                stroke: Color.Glu.nutritionDomain,
                                fillEnabled: nightActive,
                                fillColor: Color.Glu.nutritionDomain
                            )
                        }
                        .padding(.bottom, 10)
                    ),

                    customChartContent: AnyView(
                        CarbsDaypartsStackedBarChartViewV1(data: viewModel.periodAverages)
                    ),

                    customDailyChartBuilder: nil,
                    dailyScaleType: nil,

                    isMetricLocked: { metric in
                        !AppState.isUnlocked(metricName: metric, settings: settings)
                    },
                    onLockedMetricSelected: { _ in
                        appState.openAccountRoute(.manage)
                    },

                    // Nutrition goldstandard:
                    // each chip resolves its own attention source centrally from HealthStore
                    showsWarningBadgeForMetric: { metric in // 🟨 UPDATED
                        guard settings.showPermissionWarnings else { return false }

                        switch metric {
                        case L10n.Carbs.title:
                            return healthStore.carbsAnyAttentionForBadgesV1
                        case L10n.CarbsDayparts.title:
                            return healthStore.carbsAnyAttentionForBadgesV1
                        case L10n.Sugar.title:
                            return healthStore.sugarAnyAttentionForBadgesV1
                        case L10n.Protein.title:
                            return healthStore.proteinAnyAttentionForBadgesV1
                        case L10n.Fat.title:
                            return healthStore.fatAnyAttentionForBadgesV1
                        case L10n.NutritionEnergy.title:
                            return healthStore.nutritionEnergyAnyAttentionForBadgesV1
                        default:
                            return false
                        }
                    }
                )
            }
        }
        .task {
            await healthStore.refreshNutrition(.navigation)
        }
    }

    // ============================================================
    // MARK: - KPI Tile
    // 2-line tile, stroke always visible, fill conditional by active state
    // ============================================================

    private func splitKpiTile(
        label: String,
        grams: Int,
        stroke: Color,
        fillEnabled: Bool,
        fillColor: Color
    ) -> some View {

        let fill = fillEnabled ? fillColor.opacity(0.18) : Color.white.opacity(0.45)
        let shadow = fillEnabled ? fillColor.opacity(0.10) : Color.black.opacity(0.06)

        return VStack(spacing: 6) {

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("\(grams) g")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(stroke.opacity(0.75), lineWidth: 1.4)
        )
        .shadow(color: shadow, radius: 2.5, x: 0, y: 1.5)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("CarbsDaypartsViewV1 – Nutrition") {
    let previewStore = HealthStore.preview()
    let previewVM = CarbsDaypartsViewModelV1(healthStore: previewStore)
    let previewState = AppState()

    return CarbsDaypartsViewV1(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
