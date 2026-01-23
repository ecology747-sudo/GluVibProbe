//
//  MetabolicReportPreviewV1.swift
//  GluVibProbe
//

import SwiftUI

struct MetabolicReportPreviewV1: View {

    // ============================================================
    // MARK: - Config
    // ============================================================

    let windowDays: Int

    init(windowDays: Int = 30) {
        self.windowDays = windowDays
    }

    // ============================================================
    // MARK: - State / Dependencies
    // ============================================================

    @StateObject private var coordinator = MetabolicReportCoordinatorV1()
    @StateObject private var gmiVM = GMIViewModelV1()
    @StateObject private var sdVM = GlucoseSDViewModelV1()
    @StateObject private var cvVM = GlucoseCVViewModelV1()

    @State private var isLoading: Bool = true
    @State private var showExportFlow: Bool = false

    // UPDATED: Auto-forward guard (prevents repeated auto-navigation)
    @State private var didAutoForwardToExport: Bool = false

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss

    // ============================================================
    // MARK: - Layout
    // ============================================================

    private let sectionBlockSpacing: CGFloat = 0
    private let sectionTitleToContentSpacing: CGFloat = 8
    private let headerToBodyTopPadding: CGFloat = 2

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let reportTitleText: String = "GluVib Metabolic & Lifestyle Report*"

    private let reportFootnoteText: String =
        "* This report is provided for informational purposes only and does not constitute medical advice, diagnosis, or treatment. "
        + "All analyses are based exclusively on data available in Apple Health at the time of report generation. "
        + "GluVib does not verify, validate, or guarantee the accuracy of this data and assumes no responsibility for errors, omissions, or inconsistencies originating from Apple Health or connected sources. "
        + "Health-related decisions should always be made in consultation with a qualified healthcare professional."

    private let loadingTitle: String = "Preparing report…"
    private let loadingSubtitle: String = "Refreshing report data and generating your export preview."

    // ============================================================
    // MARK: - Period Anchors
    // ============================================================

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    // ============================================================
    // MARK: - Activation Gate
    // ============================================================

    private var isMetabolicReportEnabled: Bool {
        settings.hasCGM
    }

    // UPDATED: During auto-forward we show ONLY the loading UI (no report body flash).
    private var isAutoForwardPhase: Bool {
        !didAutoForwardToExport && !showExportFlow
    }

    // ============================================================
    // MARK: - Report Inputs (SSoT ONLY)
    // ============================================================

    private var reportCoveragePercent: Int {
        let ratio: Double?
        switch windowDays {
        case 7:  ratio = healthStore.tir7dSummary?.coverageRatio
        case 14: ratio = healthStore.tir14dSummary?.coverageRatio
        case 30: ratio = healthStore.tir30dSummary?.coverageRatio
        case 90: ratio = healthStore.tir90dSummary?.coverageRatio
        default: ratio = healthStore.tir30dSummary?.coverageRatio
        }
        guard let r = ratio else { return 0 }
        return Int((r * 100.0).rounded())
    }

    private var reportCvText: String {
        cvVM.formatted90dCVWhole
    }

    private var reportSdText: String {
        sdVM.sdTextForReport(windowDays: windowDays)
    }

    private var reportRangeSummary: RangePeriodSummaryEntry? {
        switch windowDays {
        case 7:  return healthStore.range7dSummary
        case 14: return healthStore.range14dSummary
        case 30: return healthStore.range30dSummary
        case 90: return healthStore.range90dSummary
        default: return healthStore.range30dSummary
        }
    }

    private var reportMeanText: String {
        guard let meanMgdl = gmiVM.hybridMeanMgdl(days: windowDays), meanMgdl > 0 else { return "–" }
        switch settings.glucoseUnit {
        case .mgdL:
            return "\(Int(meanMgdl.rounded())) mg/dL"
        case .mmolL:
            let mmol = meanMgdl / 18.0182
            return "\(format1(mmol)) mmol/L"
        }
    }

    private var reportGmiText: String {
        let value: Double?
        switch windowDays {
        case 7:  value = gmiVM.gmi7dPercent
        case 14: value = gmiVM.gmi14dPercent
        case 30: value = gmiVM.gmi30dPercent
        case 90: value = gmiVM.gmi90dPercent
        default: value = gmiVM.gmi30dPercent
        }
        guard let v = value else { return "–" }
        return format1(v)
    }

    private func format1(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f.string(from: NSNumber(value: value)) ?? "–"
    }

    // ============================================================
    // MARK: - Typechecker Breakouts
    // ============================================================

    private var mainScrollContent: some View {
        ScrollView {
            ZoomableContainer {
                contentBody
            }
        }
    }

    // ============================================================
    // MARK: - PDF Export Builders
    // ============================================================

    private var pdfExportPages: [AnyView] {
        [
            AnyView(
                MetabolicReportBodyV1(
                    windowDays: windowDays,
                    isLoading: isLoading,
                    rangeSummary: reportRangeSummary,
                    meanText: reportMeanText,
                    gmiText: reportGmiText,
                    cvText: reportCvText,
                    sdText: reportSdText,
                    glucoseProfile: coordinator.glucoseProfile,
                    sectionBlockSpacing: sectionBlockSpacing,
                    sectionTitleToContentSpacing: sectionTitleToContentSpacing,
                    renderMode: .page1
                )
                .environmentObject(healthStore)
                .environmentObject(settings)
                .background(Color.white)
            ),
            AnyView(
                MetabolicReportBodyV1(
                    windowDays: windowDays,
                    isLoading: isLoading,
                    rangeSummary: reportRangeSummary,
                    meanText: reportMeanText,
                    gmiText: reportGmiText,
                    cvText: reportCvText,
                    sdText: reportSdText,
                    glucoseProfile: coordinator.glucoseProfile,
                    sectionBlockSpacing: sectionBlockSpacing,
                    sectionTitleToContentSpacing: sectionTitleToContentSpacing,
                    renderMode: .page2
                )
                .environmentObject(healthStore)
                .environmentObject(settings)
                .background(Color.white)
            )
        ]
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        Group {
            if isAutoForwardPhase {
                loadingScreen
            } else {
                mainScrollContent
            }
        }
        .task {
            guard isMetabolicReportEnabled else { return }
            guard !didAutoForwardToExport else { return }

            isLoading = true
            await healthStore.refreshMetabolicReport(.navigation, windowDays: windowDays)
            await coordinator.loadGlucosePercentileProfile(windowDays: windowDays)
            isLoading = false

            // UPDATED: open export after load (preview stays on loading screen, so no flash)
            showExportFlow = true
        }
        .onChange(of: settings.veryLowLimit) { _, _ in
            guard isMetabolicReportEnabled else { return }
            Task { await coordinator.loadGlucosePercentileProfile(windowDays: windowDays, forceReload: true) }
        }
        .onChange(of: settings.veryHighLimit) { _, _ in
            guard isMetabolicReportEnabled else { return }
            Task { await coordinator.loadGlucosePercentileProfile(windowDays: windowDays, forceReload: true) }
        }
        .onChange(of: settings.glucoseMin) { _, _ in
            guard isMetabolicReportEnabled else { return }
            Task { await coordinator.loadGlucosePercentileProfile(windowDays: windowDays, forceReload: true) }
        }
        .onChange(of: settings.glucoseMax) { _, _ in
            guard isMetabolicReportEnabled else { return }
            Task { await coordinator.loadGlucosePercentileProfile(windowDays: windowDays, forceReload: true) }
        }
        .navigationTitle(isAutoForwardPhase ? "" : "Report Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isAutoForwardPhase {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .disabled(isLoading)
                }
            }
        }
        .fullScreenCover(isPresented: $showExportFlow) {
            ReportExportFlow(
                fileName: "GluVib_Metabolic_Report_\(windowDays)d",
                pdfPages: { pdfExportPages },

                // UPDATED: closures must return AnyView
                pageHeader: {
                    AnyView(
                        ReportHeaderSectionView(
                            reportTitle: reportTitleText,
                            windowDays: windowDays,
                            endDate: todayStart,
                            cgmCoveragePercent: reportCoveragePercent
                        )
                    )
                },

                // UPDATED: closures must return AnyView
                pageFooter: {
                    AnyView(
                        Text(reportFootnoteText)
                            .font(ReportStyle.FontToken.caption)
                            .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    )
                },

                onClose: {
                    // UPDATED: Close export AND preview (return to Metabolic Overview)
                    showExportFlow = false
                    dismiss()}
            )
            .environmentObject(healthStore)
            .environmentObject(settings)
            .onAppear {
                // UPDATED: mark auto-forward only AFTER export is actually on-screen (prevents flash)
                didAutoForwardToExport = true
            }
        }
    }

    // ============================================================
    // MARK: - Loading Screen
    // ============================================================

    private var loadingScreen: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)

            Text(loadingTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Text(loadingSubtitle)
                .font(.caption)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.70))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea()
    }

    // ============================================================
    // MARK: - Content
    // ============================================================

    @ViewBuilder
    private var contentBody: some View {
        if isMetabolicReportEnabled {
            reportContent
        } else {
            disabledReportContent
        }
    }

    private var reportContent: some View {
        VStack(alignment: .leading, spacing: sectionBlockSpacing) {

            ReportHeaderSectionView(
                reportTitle: reportTitleText,
                windowDays: windowDays,
                endDate: todayStart,
                cgmCoveragePercent: reportCoveragePercent
            )

            MetabolicReportBodyV1(
                windowDays: windowDays,
                isLoading: isLoading,
                rangeSummary: reportRangeSummary,
                meanText: reportMeanText,
                gmiText: reportGmiText,
                cvText: reportCvText,
                sdText: reportSdText,
                glucoseProfile: coordinator.glucoseProfile,
                sectionBlockSpacing: sectionBlockSpacing,
                sectionTitleToContentSpacing: sectionTitleToContentSpacing
            )
            .padding(.top, headerToBodyTopPadding)

            Rectangle()
                .fill(ReportStyle.dividerColor)
                .frame(height: ReportStyle.Size.dividerHeight)
                .padding(.vertical, 6)

            Text(reportFootnoteText)
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var disabledReportContent: some View {
        VStack(alignment: .leading, spacing: 10) {

            ReportHeaderSectionView(
                reportTitle: reportTitleText,
                windowDays: windowDays,
                endDate: todayStart,
                cgmCoveragePercent: reportCoveragePercent
            )

            RoundedRectangle(cornerRadius: 8)
                .fill(ReportStyle.dividerColor.opacity(0.18))
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metabolic report is disabled")
                            .font(ReportStyle.FontToken.value)
                            .foregroundStyle(ReportStyle.textColor)

                        Text("Enable CGM in Settings to activate this report preview.")
                            .font(ReportStyle.FontToken.caption)
                            .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                )
                .frame(height: 110)

            Rectangle()
                .fill(ReportStyle.dividerColor)
                .frame(height: ReportStyle.Size.dividerHeight)
                .padding(.vertical, 6)

            Text(reportFootnoteText)
                .font(ReportStyle.FontToken.caption)
                .foregroundStyle(ReportStyle.textColor.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MetabolicReportPreviewV1(windowDays: 14)
            .environmentObject(HealthStore.preview())
            .environmentObject(SettingsModel.shared)
    }
}
