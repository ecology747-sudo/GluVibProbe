//
//  MetabolicReportBodyV1.swift
//  GluVibProbe
//

import SwiftUI

struct MetabolicReportBodyV1: View {

    enum RenderMode {
        case all
        case page1
        case page2
    }

    private let renderMode: RenderMode

    let windowDays: Int
    let isLoading: Bool

    let rangeSummary: RangePeriodSummaryEntry?
    let meanText: String
    let gmiText: String
    let cvText: String
    let sdText: String

    let glucoseProfile: ReportGlucoseProfileV1?

    let sectionBlockSpacing: CGFloat
    let sectionTitleToContentSpacing: CGFloat

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

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

    private var isManualPDFPage: Bool { renderMode == .page1 || renderMode == .page2 }

    private var sepPadS: CGFloat { isManualPDFPage ? 3 : 6 }
    private var sepPadM: CGFloat { isManualPDFPage ? 4 : 6 }
    private var sepPadL: CGFloat { isManualPDFPage ? 6 : 8 }

    private var chartTopPad: CGFloat { isManualPDFPage ? 4 : 8 }
    private var medianChartHeight: CGFloat { isManualPDFPage ? 238 : 260 }
    private var medianSectionTopPad: CGFloat { isManualPDFPage ? 2 : 6 }

    // UPDATED: Provide windowed TIR daily series (full days only, ends yesterday) for ReportRangeSectionView
    private var reportDailyTIRSeries: [DailyTIREntry] {
        windowFullDays(healthStore.dailyTIR90, windowDays: windowDays) { $0.date }
    }

    private func windowFullDays<T>(
        _ entries: [T],
        windowDays: Int,
        date: (T) -> Date
    ) -> [T] {

        guard !entries.isEmpty else { return [] }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: -1, to: todayStart) else { return [] }

        let n = max(1, windowDays)
        guard let start = cal.date(byAdding: .day, value: -(n - 1), to: end) else { return [] }

        return entries
            .filter {
                let d = cal.startOfDay(for: date($0))
                return d >= start && d <= end
            }
            .sorted { date($0) < date($1) }
    }

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

    private var bodyAll: some View {
        Group {
            ReportThresholdsSectionView(onOpenMetabolicSettings: nil)
            reportSeparator(verticalPadding: 6)

            reportDailyMeanGlucoseLineChartSection
            reportSeparator(verticalPadding: 6)

            if isLoading {
                loadingSection
            } else {
                glucoseRangeAndVariabilitySection
                reportSeparator(verticalPadding: 6)

                medianDailyProfileSection
                    .padding(.top, 6)

                insulinBlock

                reportSeparator(verticalPadding: 8)
                lifestyleImpactSection
            }
        }
    }

    private var bodyPage1: some View {
        Group {
            ReportThresholdsSectionView(onOpenMetabolicSettings: nil)
            reportSeparator(verticalPadding: sepPadM)

            reportDailyMeanGlucoseLineChartSection
            reportSeparator(verticalPadding: sepPadM)

            if isLoading {
                loadingSection
            } else {
                glucoseRangeAndVariabilitySection
                reportSeparator(verticalPadding: sepPadM)

                medianDailyProfileSection
                    .padding(.top, medianSectionTopPad)
            }
        }
    }

    private var bodyPage2: some View {
        Group {
            if isLoading {
                loadingSection
            } else {
                if settings.isInsulinTreated {
                    ReportInsulinTherapyOverviewSectionV1(
                        windowDays: windowDays,
                        dailyBolus90: healthStore.dailyBolus90,
                        dailyBasal90: healthStore.dailyBasal90,
                        dailyCarbBolusRatio90: healthStore.dailyCarbBolusRatio90,
                        dailyBolusBasalRatio90: healthStore.dailyBolusBasalRatio90
                    )
                    .padding(.top, 0)

                    reportSeparator(verticalPadding: sepPadL)
                }

                lifestyleImpactSection
            }
        }
    }

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
        .padding(.top, chartTopPad)
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

            Text("Time in Range (\(windowDays) Days)")
                .font(ReportStyle.FontToken.value)
                .foregroundStyle(ReportStyle.textColor)

            ReportRangeSectionView(
                windowDays: windowDays,
                summaryWindow: rangeSummary,
                meanText: meanText,
                gmiText: gmiText,
                cvText: cvText,
                sdText: sdText,

                tirDailySeries: reportDailyTIRSeries,
                tirTargetPercent: settings.tirTargetPercent, // UPDATED

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
                    .frame(height: medianChartHeight)
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
