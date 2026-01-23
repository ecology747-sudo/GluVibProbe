//
//  ReportHeaderSectionView.swift
//  GluVibProbe
//
//  GluVib Report (V1) — Header Section
//
//  FINAL:
//  - Closed meta row: Coverage · CGM · Insulin · Unit
//  - Date format without weekday (e.g. "22. Dec 2025")
//  - Flat report look (no cards)
//  - Period line uses the ONE system truth: (days-1 full days) + today (startOfDay anchored)
//

import SwiftUI

struct ReportHeaderSectionView: View {

    let reportTitle: String
    let windowDays: Int
    let endDate: Date
    let cgmCoveragePercent: Int

    @EnvironmentObject private var settings: SettingsModel
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    // ============================================================
    // MARK: - Period (single truth)
    // ============================================================

    private var endDay: Date {
        calendar.startOfDay(for: endDate)
    }

    private var startDay: Date {
        calendar.date(
            byAdding: .day,
            value: -(max(1, windowDays) - 1),
            to: endDay
        ) ?? endDay
    }

    private var periodLine: String {
        "\(windowDays) Days · \(formatDate(startDay)) – \(formatDate(endDay))"
    }

    // ============================================================
    // MARK: - Meta (single truth)
    // ============================================================

    private var coverageText: String { "\(cgmCoveragePercent)%" }
    private var cgmStatusText: String { settings.hasCGM ? "On" : "Off" }
    private var insulinStatusText: String { settings.isInsulinTreated ? "On" : "Off" }
    private var glucoseUnitText: String { settings.glucoseUnit == .mmolL ? "mmol/L" : "mg/dL" }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: ReportStyle.Spacing.block) {

            HStack(alignment: .top, spacing: 12) {

                VStack(alignment: .leading, spacing: ReportStyle.Spacing.blockTight) {

                    Text("\(reportTitle)")
                        .font(ReportStyle.FontToken.title)
                        .foregroundStyle(ReportStyle.textColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(periodLine)
                        .font(ReportStyle.FontToken.caption)
                        .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Image("GluVibLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: ReportStyle.Size.headerLogo,
                        height: ReportStyle.Size.headerLogo
                    )
                    .accessibilityLabel(Text("GluVib Logo"))
            }

            Rectangle()
                .fill(ReportStyle.dividerColor)
                .frame(height: ReportStyle.Size.dividerHeight)

            HStack(spacing: 14) {

                metaItem("Coverage", coverageText)
                metaDivider
                metaItem("CGM", cgmStatusText)
                metaDivider
                metaItem("Insulin", insulinStatusText)
                metaDivider
                metaItem("Unit", glucoseUnitText)

                Spacer()
            }
        }
        .padding(.bottom, 6)
        .overlay(
            Rectangle()
                .fill(ReportStyle.dividerColor)
                .frame(height: ReportStyle.Size.dividerHeight),
            alignment: .bottom
        )
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func metaItem(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text("\(title):")
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
            Text(value)
                .font(ReportStyle.FontToken.value)
                .foregroundStyle(ReportStyle.textColor)
        }
    }

    private var metaDivider: some View {
        Rectangle()
            .fill(ReportStyle.dividerColor)
            .frame(width: 1, height: 14)
            .opacity(0.9)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.dateFormat = "d. MMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VStack(alignment: .leading, spacing: 12) {

            let cal = Calendar.current
            let endDay = cal.startOfDay(for: Date())

            ReportHeaderSectionView(
                reportTitle: "GluVib Metabolic & Lifestyle Report",
                windowDays: 30,
                endDate: endDay,
                cgmCoveragePercent: 92
            )
            .environmentObject(SettingsModel.shared)

            Spacer()
        }
        .padding(20)
    }
}
