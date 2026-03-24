//
//  HistoryView.swift
//  GluVibProbe
//
//  History V1 — Content Composition
//
//  Purpose
//  - Renders the pure History content for day sections, section headers and event rows.
//  - Does not own background, header, refresh, task orchestration or ViewModel state.
//  - Is embedded by HistoryOverviewViewV1 as the only History screen.
//
//  Data Flow (SSoT)
//  HealthStore / HistoryViewModelV1 → HistoryOverviewViewV1 (composition / grouping) → HistoryView (content only) → row / header subviews
//
//  Key Connections
//  - HistoryOverviewViewV1: owns screen composition, refresh and routing.
//  - HistoryDaySection: UI-only grouping model for day-based History sections.
//  - HistoryEventRowCard: renders the visual History tile.
//  - HistoryOverviewRoute: used for overview-based navigation from row taps.
//  - HistoryMetricRoute: passed through for compatibility with the existing History flow.
//

import SwiftUI

// ============================================================
// MARK: - Day Section Model (UI-only)
// ============================================================

struct HistoryDaySection: Hashable {
    let date: Date
    let title: String
    let items: [HistoryListEvent]
}

// ============================================================
// MARK: - Row Wrapper (Card only, No Chevron)
// ============================================================

struct HistoryListRow: View {

    let model: HistoryEventRowCardModel
    let onTapOverview: () -> Void

    var body: some View {
        HistoryEventRowCard(
            model: model,
            onTapTile: onTapOverview
        )
    }
}

// ============================================================
// MARK: - Day Header
// Today / Yesterday / Date + MainChart shortcut
// ============================================================

struct HistoryDayHeader: View {

    let title: String
    let isChartEnabled: Bool
    let onTapDayChart: () -> Void

    private var dayAccent: Color {
        Color.Glu.acidCGMRed.opacity(0.90)
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(dayAccent)

            Spacer()

            Button(action: onTapDayChart) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(dayAccent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Open day chart")) // 🟨 UPDATED
            .disabled(!isChartEnabled)
            .opacity(isChartEnabled ? 1.0 : 0.35)
        }
    }
}

// ============================================================
// MARK: - Pure Content
// Sections + Rows only
// ============================================================

struct HistoryListContentView: View {

    let sections: [HistoryDaySection]

    let horizontalInset: CGFloat
    let sectionSpacing: CGFloat
    let rowSpacing: CGFloat

    let isChartEnabled: Bool
    let onTapDayChart: (Date) -> Void
    let onTapMetric: (HistoryMetricRoute) -> Void
    let onTapOverview: (HistoryOverviewRoute) -> Void

    var body: some View {
        VStack(spacing: sectionSpacing) {
            ForEach(sections, id: \.date) { section in
                HistoryDayHeader(
                    title: section.title,
                    isChartEnabled: isChartEnabled,
                    onTapDayChart: {
                        onTapDayChart(section.date)
                    }
                )
                .padding(.horizontal, horizontalInset)

                VStack(spacing: rowSpacing) {
                    ForEach(section.items) { event in
                        HistoryListRow(
                            model: event.cardModel,
                            onTapOverview: {
                                onTapOverview(event.overviewRoute)
                            }
                        )
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
        }
    }
}

// ============================================================
// MARK: - Legacy Wrapper
// Keeps the existing external API for embedded content usage
// ============================================================

struct HistoryView: View {

    let sections: [HistoryDaySection]
    let isChartEnabled: Bool
    let onTapDayChart: (Date) -> Void
    let onTapMetric: (HistoryMetricRoute) -> Void
    let onTapOverview: (HistoryOverviewRoute) -> Void

    private let horizontalInset: CGFloat = 16
    private let sectionSpacing: CGFloat = 16
    private let rowSpacing: CGFloat = 10

    var body: some View {
        HistoryListContentView(
            sections: sections,
            horizontalInset: horizontalInset,
            sectionSpacing: sectionSpacing,
            rowSpacing: rowSpacing,
            isChartEnabled: isChartEnabled,
            onTapDayChart: onTapDayChart,
            onTapMetric: onTapMetric,
            onTapOverview: onTapOverview
        )
    }
}

// ============================================================
// MARK: - Preview
// Content-only embedded preview
// ============================================================

#Preview("History Content (Embedded)") {
    VStack(spacing: 16) {
        HistoryView(
            sections: [
                .init(
                    date: Calendar.current.startOfDay(for: Date()),
                    title: L10n.History.Section.today, // 🟨 UPDATED
                    items: []
                )
            ],
            isChartEnabled: true,
            onTapDayChart: { _ in },
            onTapMetric: { _ in },
            onTapOverview: { _ in }
        )
    }
    .padding()
    .background(Color.white)
}
