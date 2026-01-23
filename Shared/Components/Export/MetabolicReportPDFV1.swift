//
//  MetabolicReportPDFV1.swift
//  GluVibProbe
//
//  Metabolic Report (V1) — PDF Wrapper
//
//  NEW:
//  - PDF layout = Header + Body + Footnote
//  - NO fetch, NO coordinator loading, NO navigation
//  - Body is embedded 1:1 via MetabolicReportBodyV1 (single source for report content)
//

import SwiftUI

struct MetabolicReportPDFV1: View {

    // ============================================================
    // MARK: - Inputs (provided by Preview/Export wrapper)
    // ============================================================

    let windowDays: Int
    let isLoading: Bool

    // Header inputs (computed in Preview; no duplicated logic here)
    let reportTitle: String
    let endDate: Date
    let cgmCoveragePercent: Int

    // Body inputs (already computed in Preview flow)
    let rangeSummary: RangePeriodSummaryEntry?
    let meanText: String
    let gmiText: String
    let cvText: String
    let sdText: String
    let glucoseProfile: ReportGlucoseProfileV1?

    // Layout tuning
    let sectionBlockSpacing: CGFloat
    let sectionTitleToContentSpacing: CGFloat

    // ============================================================
    // MARK: - Dependencies (SSoT)
    // ============================================================

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionBlockSpacing) {

            // ====================================================
            // Header (PDF wrapper responsibility)
            // ====================================================

            ReportHeaderSectionView(
                reportTitle: reportTitle,
                windowDays: windowDays,
                endDate: endDate,
                cgmCoveragePercent: cgmCoveragePercent
            )

            reportSeparator(verticalPadding: 6)

            // ====================================================
            // Body (single source)
            // ====================================================

            MetabolicReportBodyV1(
                windowDays: windowDays,
                isLoading: isLoading,
                rangeSummary: rangeSummary,
                meanText: meanText,
                gmiText: gmiText,
                cvText: cvText,
                sdText: sdText,
                glucoseProfile: glucoseProfile,
                sectionBlockSpacing: sectionBlockSpacing,
                sectionTitleToContentSpacing: sectionTitleToContentSpacing
            )

            reportDividerSection
            reportFootnoteSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    // ============================================================
    // MARK: - Shared PDF separators / footer
    // ============================================================

    private func reportSeparator(verticalPadding: CGFloat) -> some View {
        Rectangle()
            .fill(ReportStyle.dividerColor.opacity(0.9))
            .frame(height: ReportStyle.Size.dividerHeight)
            .padding(.vertical, verticalPadding)
    }

    private var reportDividerSection: some View {
        Rectangle()
            .fill(ReportStyle.dividerColor)
            .frame(height: ReportStyle.Size.dividerHeight)
            .padding(.vertical, 6)
    }

    private var reportFootnoteSection: some View {
        Text(
            "* This report is for informational purposes only and does not constitute medical advice. "
            + "All analyses are based exclusively on data available in Apple Health. "
            + "Health-related decisions should always be made in consultation with a qualified healthcare professional."
        )
        .font(ReportStyle.FontToken.caption)
        .foregroundStyle(ReportStyle.textColor.opacity(0.75))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preview
#Preview {
    let store = HealthStore.preview()
    let settings = SettingsModel.shared
    settings.hasCGM = true

    return ScrollView {
        MetabolicReportPDFV1(
            windowDays: 30,
            isLoading: false,
            reportTitle: "GluVib Metabolic & Lifestyle Report*",
            endDate: Calendar.current.startOfDay(for: Date()),
            cgmCoveragePercent: 92,
            rangeSummary: nil,
            meanText: "124 mg/dL",
            gmiText: "6.4",
            cvText: "28%",
            sdText: "35 mg/dL",
            glucoseProfile: nil,
            sectionBlockSpacing: 0,
            sectionTitleToContentSpacing: 8
        )
        .environmentObject(store)
        .environmentObject(settings)
    }
}
