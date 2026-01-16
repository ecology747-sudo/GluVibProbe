//
//  HistoryView.swift
//  GluVibProbe
//
//  HISTORY — Content (Rows only)
//  - NO OverviewHeader
//  - NO Background
//  - NO Refresh / Task
//  - NO ViewModel
//  - Used by HistoryOverviewViewV1 (the only History screen)
//

import SwiftUI

// MARK: - Day Section Model (UI-only)

struct HistoryDaySection: Hashable {
    let date: Date
    let title: String
    let items: [HistoryListEvent]
}

// MARK: - Wrapper Row (Card only, NO Chevron)

struct HistoryListRow: View {

    let model: HistoryEventRowCardModel
    let onTapOverview: () -> Void        // ✅ UPDATED: tile navigates to overview only

    var body: some View {
        // ✅ UPDATED: Entire tile navigates (no separate chevron)
        HistoryEventRowCard(model: model, onTapTile: onTapOverview)
    }
}

// MARK: - Day Header (Today / Yesterday / Date + MainChart shortcut)

struct HistoryDayHeader: View {

    let title: String
    let isChartEnabled: Bool
    let onTapDayChart: () -> Void

    // ✅ Requirement: day line (Today/Yesterday/Date) must be Acid CGM Red
    private var dayAccent: Color { Color.Glu.acidCGMRed.opacity(0.90) }

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
            .accessibilityLabel("Open day chart")
            .disabled(!isChartEnabled)
            .opacity(isChartEnabled ? 1.0 : 0.35)
        }
    }
}

// MARK: - Pure Content (Sections + Rows)

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
                    onTapDayChart: { onTapDayChart(section.date) }
                )
                .padding(.horizontal, horizontalInset)

                VStack(spacing: rowSpacing) {
                    ForEach(section.items) { e in
                        HistoryListRow(
                            model: e.cardModel,
                            onTapOverview: { onTapOverview(e.overviewRoute) }   // ✅ UPDATED
                        )
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
        }
    }
}

// MARK: - Legacy Wrapper (kept only so the file still offers a View type named "HistoryView")

struct HistoryView: View {

    let sections: [HistoryDaySection]
    let isChartEnabled: Bool
    let onTapDayChart: (Date) -> Void
    let onTapMetric: (HistoryMetricRoute) -> Void
    let onTapOverview: (HistoryOverviewRoute) -> Void

    // Layout defaults (keeps call-sites simple)
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
            onTapMetric: onTapMetric,               // kept for call-site stability (unused now)
            onTapOverview: onTapOverview
        )
    }
}

// MARK: - Preview (content-only)

#Preview("History Content (Embedded)") {
    VStack(spacing: 16) {
        HistoryView(
            sections: [
                .init(
                    date: Calendar.current.startOfDay(for: Date()),
                    title: "Today",
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
