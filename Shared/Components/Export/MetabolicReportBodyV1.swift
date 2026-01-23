//
//  MetabolicReportBodyV1.swift
//  GluVibProbe
//
//  Metabolic Report (V1) — PDF/Print Master Body
//
//  UPDATED:
//  - Adds compact spacing profile for manual PDF pages (.page1/.page2) to prevent unwanted extra pages
//  - Rule remains: Insulin therapy section (incl. its heading inside the section) is ALWAYS on page 2
//  - Screen preview (.all) keeps current layout unchanged
//

import SwiftUI

struct MetabolicReportBodyV1: View {

    // ============================================================
    // MARK: - Paging Mode
    // ============================================================

    enum RenderMode {
        case all
        case page1
        case page2
    }

    private let renderMode: RenderMode

    // ============================================================
    // MARK: - Inputs (provided by Preview/Export wrapper)
    // ============================================================

    let windowDays: Int
    let isLoading: Bool

    // “Computed” texts (already produced in your Preview flow)
    let rangeSummary: RangePeriodSummaryEntry?
    let meanText: String
    let gmiText: String
    let cvText: String
    let sdText: String

    // Percentile profile from Coordinator
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
    // MARK: - Init (keeps old call sites working)
    // ============================================================

    init(
        windowDays: Int,
        isLoading: Bool,
        rangeSummary: RangePeriodSummaryEntry?,
        meanText: String,
        gmiText: String,
        cvText: String,
        sdText: String,
        glucoseProfile: ReportGlucoseProfileV1?,
        sectionBlockSpacing: CGFloat,
        sectionTitleToContentSpacing: CGFloat,
        renderMode: RenderMode = .all
    ) {
        self.windowDays = windowDays
        self.isLoading = isLoading
        self.rangeSummary = rangeSummary
        self.meanText = meanText
        self.gmiText = gmiText
        self.cvText = cvText
        self.sdText = sdText
        self.glucoseProfile = glucoseProfile
        self.sectionBlockSpacing = sectionBlockSpacing
        self.sectionTitleToContentSpacing = sectionTitleToContentSpacing
        self.renderMode = renderMode
    }

    // ============================================================
    // MARK: - Compact PDF Spacing (ONLY for manual pages)
    // ============================================================

    // UPDATED: Manual PDF pages must be more compact because footer grows with disclaimer length.
    private var isManualPDFPage: Bool {
        renderMode == .page1 || renderMode == .page2
    }

    // UPDATED: Separator paddings become smaller in PDF manual pages.
    private var sepPadS: CGFloat { isManualPDFPage ? 3 : 6 }
    private var sepPadM: CGFloat { isManualPDFPage ? 4 : 6 }
    private var sepPadL: CGFloat { isManualPDFPage ? 6 : 8 }

    // UPDATED: Reduce top padding for first charts/sections in PDF manual pages.
    private var chartTopPad: CGFloat { isManualPDFPage ? 4 : 8 }

    // UPDATED: Median profile chart height slightly reduced ONLY in PDF manual pages.
    private var medianChartHeight: CGFloat { isManualPDFPage ? 238 : 260 }

    // UPDATED: Reduce extra top padding above median section in PDF manual pages.
    private var medianSectionTopPad: CGFloat { isManualPDFPage ? 2 : 6 }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionBlockSpacing) {
            switch renderMode {
            case .all:
                bodyAll
            case .page1:
                bodyPage1
            case .page2:
                bodyPage2
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    // ============================================================
    // MARK: - Page Variants
    // ============================================================

    private var bodyAll: some View {
        Group {
            // Thresholds
            ReportThresholdsSectionView(onOpenMetabolicSettings: nil)
            reportSeparator(verticalPadding: 6)

            // Daily Mean chart
            reportDailyMeanGlucoseLineChartSection
            reportSeparator(verticalPadding: 6)

            // Main Body
            if isLoading {
                loadingSection
            } else {
                glucoseRangeAndVariabilitySection
                reportSeparator(verticalPadding: 6)

                medianDailyProfileSection
                    .padding(.top, 6)

                // Insulin must exist here for on-screen layout
                insulinBlock

                reportSeparator(verticalPadding: 8)
                lifestyleImpactSection
            }
        }
    }

    // PAGE 1: everything up to (and including) Median Daily Profile
    //         (Insulin therapy is NOT rendered here)
    private var bodyPage1: some View {
        Group {
            // Thresholds
            ReportThresholdsSectionView(onOpenMetabolicSettings: nil)
            reportSeparator(verticalPadding: sepPadM) // UPDATED

            // Daily Mean chart
            reportDailyMeanGlucoseLineChartSection
            reportSeparator(verticalPadding: sepPadM) // UPDATED

            if isLoading {
                loadingSection
            } else {
                glucoseRangeAndVariabilitySection
                reportSeparator(verticalPadding: sepPadM) // UPDATED

                medianDailyProfileSection
                    .padding(.top, medianSectionTopPad) // UPDATED
            }
        }
    }

    // PAGE 2: insulin therapy section (if enabled) + lifestyle impact
    //         (Rule: insulin therapy incl its heading is ALWAYS on page 2)
    private var bodyPage2: some View {
        Group {
            if isLoading {
                loadingSection
            } else {

                // UPDATED: Start directly under page header -> no extra top padding here.
                if settings.isInsulinTreated {
                    ReportInsulinTherapyOverviewSectionV1(
                        windowDays: windowDays,
                        dailyBolus90: healthStore.dailyBolus90,
                        dailyBasal90: healthStore.dailyBasal90,
                        dailyCarbBolusRatio90: healthStore.dailyCarbBolusRatio90,
                        dailyBolusBasalRatio90: healthStore.dailyBolusBasalRatio90
                    )
                    .padding(.top, 0) // UPDATED

                    reportSeparator(verticalPadding: sepPadL) // UPDATED
                }

                lifestyleImpactSection
            }
        }
    }

    // ============================================================
    // MARK: - Sections
    // ============================================================

    private var reportDailyMeanGlucoseLineChartSection: some View {
        Group {
            if isLoading {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ReportStyle.dividerColor.opacity(0.20))
                    .frame(height: 180)
                    .overlay(
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Updating chart…")
                                .font(ReportStyle.FontToken.caption)
                                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                        }
                    )
            } else {
                ReportDailyMeanGlucoseLineChartV1(
                    windowDays: windowDays,
                    glucoseUnit: settings.glucoseUnit,
                    entries: healthStore.dailyGlucoseStats90,
                    targetMinMgdl: settings.glucoseMin,
                    targetMaxMgdl: settings.glucoseMax
                )
            }
        }
        .padding(.top, chartTopPad) // UPDATED
    }

    private var loadingSection: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(ReportStyle.dividerColor.opacity(0.20))
            .frame(height: 110)
            .overlay(
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating report data…")
                        .font(ReportStyle.FontToken.caption)
                        .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                }
            )
    }

    private var glucoseRangeAndVariabilitySection: some View {
        VStack(alignment: .leading, spacing: sectionTitleToContentSpacing) {

            Text("Glucose Range & Variability (\(windowDays) Days)")
                .font(ReportStyle.FontToken.value)
                .foregroundStyle(ReportStyle.textColor)

            ReportRangeSectionView(
                windowDays: windowDays,
                summaryWindow: rangeSummary,
                meanText: meanText,
                gmiText: gmiText,
                cvText: cvText,
                sdText: sdText,
                onTap: nil
            )
        }
    }

    private var medianDailyProfileSection: some View {
        Group {
            if let profile = glucoseProfile {
                VStack(alignment: .leading, spacing: sectionTitleToContentSpacing) {

                    Text("Median Daily Glucose Profile (\(windowDays) Days)")
                        .font(ReportStyle.FontToken.value)
                        .foregroundStyle(ReportStyle.textColor)

                    MedianDailyGlucoseProfileChart(
                        profile: profile,
                        glucoseUnit: settings.glucoseUnit
                    )
                    .frame(height: medianChartHeight) // UPDATED
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ReportStyle.dividerColor.opacity(0.25))
                    .frame(height: 220)
            }
        }
    }

    @ViewBuilder
    private var insulinBlock: some View {
        if settings.isInsulinTreated {
            reportSeparator(verticalPadding: 8)

            ReportInsulinTherapyOverviewSectionV1(
                windowDays: windowDays,
                dailyBolus90: healthStore.dailyBolus90,
                dailyBasal90: healthStore.dailyBasal90,
                dailyCarbBolusRatio90: healthStore.dailyCarbBolusRatio90,
                dailyBolusBasalRatio90: healthStore.dailyBolusBasalRatio90
            )
            .padding(.top, 10)
        }
    }

    private var lifestyleImpactSection: some View {
        ReportLifestyleImpactSectionV1(
            windowDays: windowDays,
            dailyCarbs90: healthStore.last90DaysCarbs,
            dailyActiveEnergy90: healthStore.last90DaysActiveEnergy
        )
    }

    private func reportSeparator(verticalPadding: CGFloat) -> some View {
        Rectangle()
            .fill(ReportStyle.dividerColor.opacity(0.9))
            .frame(height: ReportStyle.Size.dividerHeight)
            .padding(.vertical, verticalPadding)
    }
}

// MARK: - Preview
#Preview {
    let store = HealthStore.preview()
    let settings = SettingsModel.shared
    settings.hasCGM = true
    settings.isInsulinTreated = true

    return ScrollView {
        VStack(spacing: 24) {

            Text("PAGE 1")
            MetabolicReportBodyV1(
                windowDays: 30,
                isLoading: false,
                rangeSummary: nil,
                meanText: "124 mg/dL",
                gmiText: "6.4",
                cvText: "28%",
                sdText: "35 mg/dL",
                glucoseProfile: nil,
                sectionBlockSpacing: 0,
                sectionTitleToContentSpacing: 8,
                renderMode: .page1
            )
            .environmentObject(store)
            .environmentObject(settings)

            Text("PAGE 2")
            MetabolicReportBodyV1(
                windowDays: 30,
                isLoading: false,
                rangeSummary: nil,
                meanText: "124 mg/dL",
                gmiText: "6.4",
                cvText: "28%",
                sdText: "35 mg/dL",
                glucoseProfile: nil,
                sectionBlockSpacing: 0,
                sectionTitleToContentSpacing: 8,
                renderMode: .page2
            )
            .environmentObject(store)
            .environmentObject(settings)
        }
        .background(Color.white)
    }
}
