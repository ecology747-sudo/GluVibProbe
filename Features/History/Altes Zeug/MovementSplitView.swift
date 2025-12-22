//
//  MovementSplitView.swift
//  GluVibProbe
//
//  Reine View für den Movement-Split-Screen (MVVM)
//  - Domain-Header „Activity“ mit Back-Pfeil
//  - Metric-Chip-Leiste (Steps / Active Time / Activity Energy / Movement Split)
//  - KPI-Zeile (Sleep / Active / Rest)
//  - Eine SingleChartSectionCard mit MovementSplit30DayChart
//

import SwiftUI

struct MovementSplitView: View {

    // MARK: - Environment
    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel
    @StateObject private var viewModel: MovementSplitViewModel

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    // Domain-Farbe (wie in ActivitySectionCardScaled)
    private let color = Color.Glu.activityAccent

    // Metrik-Namen für die Chip-Leiste
    private let metrics = [
        "Steps",
        "Active Time",
        "Activity Energy",
        "Movement Split"
    ]

    // MARK: - Init

    init(
        viewModel: MovementSplitViewModel? = nil,
        onMetricSelected: @escaping (String) -> Void = { _ in }
    ) {
        self.onMetricSelected = onMetricSelected

        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: MovementSplitViewModel())
        }
    }

    // MARK: - Body

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Activity",
            headerTint: Color.Glu.activityDomain,
            onBack: {
                appState.currentStatsScreen = .none
            },
            onRefresh: {
                viewModel.refresh()
            },
            background: {                                     // CHANGED: Gradient statt Color
                LinearGradient(
                    colors: [
                        .white,
                        Color.Glu.activityDomain.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {

                // METRIC CHIPS
                metricChips

                // KPI-ZEILE
                kpiHeader

                // EINZIGE SECTION CARD: Movement Split Chart
                SingleChartSectionCard(
                    title: "",
                    borderColor: color,
                    backgroundColor: Color.Glu.backgroundSurface
                ) {
                    MovementSplit30DayChart(
                        data: viewModel.dailyMovementSplits
                    )
                    .frame(height: 325)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - Metric Chips

private extension MovementSplitView {

    var metricChips: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Erste Zeile: 3 Metriken
            HStack(spacing: 8) {
                ForEach(metrics.prefix(3), id: \.self) { metric in
                    metricChip(metric)
                }
            }

            // Zweite Zeile: Rest (hier 1 Metrik)
            HStack(spacing: 8) {
                ForEach(metrics.suffix(from: 3), id: \.self) { metric in
                    metricChip(metric)
                }
            }
        }
        .padding(.top, 4)
    }

    private func metricChip(_ metric: String) -> some View {
        let active = (metric == "Movement Split")

        return Text(metric)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(
                        active
                        ? LinearGradient(
                            colors: [
                                color.opacity(0.95),
                                color.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                color.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        active
                        ? Color.white.opacity(0.90)
                        : Color.white.opacity(0.35),
                        lineWidth: active ? 1.6 : 0.8
                    )
            )
            .shadow(
                color: Color.black.opacity(active ? 0.25 : 0.08),
                radius: active ? 4 : 2,
                x: 0,
                y: active ? 2 : 1
            )
            .foregroundStyle(
                active
                ? Color.white
                : Color.Glu.primaryBlue.opacity(0.95)
            )
            .scaleEffect(active ? 1.05 : 1.0)
            .animation(.easeOut(duration: 0.15), value: active)
            .onTapGesture {
                onMetricSelected(metric)
            }
    }
}

// MARK: - KPI Header

private extension MovementSplitView {

    var kpiHeader: some View {
        HStack(alignment: .top, spacing: 10) {

            KPICard(
                title: "Sleep Today",
                valueText: viewModel.kpiSleepText,
                unit: nil,
                domain: .activity
            )

            KPICard(
                title: "Active Today",
                valueText: viewModel.kpiActiveText,
                unit: nil,
                domain: .activity
            )

            KPICard(
                title: "Rest Today",
                valueText: viewModel.kpiSedentaryText,
                unit: nil,
                domain: .activity
            )
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Preview

#Preview("MovementSplitView – Activity") {
    let previewStore = HealthStore.preview()
    let previewVM = MovementSplitViewModel(healthStore: previewStore)
    let previewState = AppState()

    return MovementSplitView(viewModel: previewVM) { metric in
        print("Selected metric: \(metric)")
    }
    .environmentObject(previewStore)
    .environmentObject(previewState)
}
