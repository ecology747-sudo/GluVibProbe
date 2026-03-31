//
//  OverviewHeader.swift
//  GluVib
//
//  Area: Shared / Header
//  File Role:
//  - Reusable overview header for GluVib overview screens.
//  - Displays title / subtitle, report entry, account avatar,
//    premium / trial badges, and permission badges.
//
//  Purpose:
//  - Keep overview header presentation consistent across domains.
//  - Consume the central monetization truth from EntitlementManager for
//    premium / trial badge display and report-entry gating.
//  - Preserve the existing permission-badge behavior tied to HealthStore
//    and user intent settings.
//
//  System Role:
//  - This file is UI only.
//  - It does NOT define premium / trial / free truth.
//  - It does NOT resolve capabilities.
//  - It only renders header UI based on already-resolved app state.
//
//  Key Connections:
//  - AppState
//  - SettingsModel
//  - HealthStore
//  - EntitlementManager
//  - localized strings via L10n
//

import SwiftUI

struct OverviewHeader: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var entitlementManager: EntitlementManager // 🟨 UPDATED

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let title: String
    let subtitle: String?
    let tintColor: Color
    let hasScrolled: Bool

    // ============================================================
    // MARK: - Permission Badge Scope
    // ============================================================

    enum PermissionBadgeScope {
        case none
        case metabolic
        case nutrition
        case activity
        case body
        case allDomains
    }

    let permissionBadgeScope: PermissionBadgeScope

    // ============================================================
    // MARK: - Local UI State
    // ============================================================

    @State private var showReportPreview: Bool = false
    @State private var showReportPeriodDialog: Bool = false
    @State private var selectedReportDays: Int = 30

    @State private var showIncludeDailyChartsDialog: Bool = false
    @State private var includeDailyChartsInReport: Bool = false

    // ============================================================
    // MARK: - Derived UI State
    // ============================================================

    private var canShowReportIcon: Bool { // 🟨 UPDATED
        settings.hasCGM && entitlementManager.canAccessMetabolic
    }

    private var showPremiumBadge: Bool { // 🟨 UPDATED
        entitlementManager.isPremium
    }

    private var showTrialDaysBadge: Bool { // 🟨 UPDATED
        entitlementManager.isTrial
    }

    private var trialDaysBadgeText: String { // 🟨 UPDATED
        let days = max(0, entitlementManager.trialDaysRemaining ?? 0)
        return "\(days)"
    }

    private var showPermissionBadge: Bool {
        guard settings.showPermissionWarnings else { return false }

        switch permissionBadgeScope {
        case .none:
            return false

        case .metabolic:
            let glucoseNeeds =
                settings.hasCGM &&
                healthStore.glucoseReadAuthIssueV1

            let therapyNeeds =
                settings.hasCGM &&
                settings.isInsulinTreated &&
                healthStore.metabolicTherapyAnyAttentionForBadgesV1

            let carbsNeeds =
                settings.hasCGM &&
                settings.isInsulinTreated &&
                healthStore.metabolicCarbsAuthIssueAnyV1

            return glucoseNeeds || therapyNeeds || carbsNeeds

        case .nutrition:
            return healthStore.nutritionAnyAuthIssueForBadgesV1

        case .activity:
            return healthStore.activityAnyAuthIssueForBadgesV1

        case .body:
            return healthStore.bodyAnyAuthIssueForBadgesV1

        case .allDomains:
            return healthStore.anyDomainAuthIssueForBadgesV1
        }
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {

        ZStack {

            Rectangle()
                .fill(Color.white.opacity(0.90))
                .blur(radius: 10)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 2) {

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .zIndex(1)

            HStack {

                if canShowReportIcon {
                    Button {
                        appState.isMetabolicReportPresented = true
                        showReportPeriodDialog = true
                    } label: {
                        Image(systemName: "tray.circle.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .shadow(color: .black.opacity(0.22), radius: 4.5, x: 0, y: 2)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.MetabolicReportFlow.openAccessibility)
                }

                Spacer()
            }
            .padding(.leading, 12)
            .zIndex(2)

            HStack {
                Spacer()

                Button {
                    appState.presentAccountSheet()
                } label: {

                    ZStack {

                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .shadow(color: .black.opacity(0.22), radius: 4.5, x: 0, y: 2)
                            .padding(6)

                        if showPremiumBadge {
                            badgeView(
                                system: "crown.fill",
                                fg: .yellow,
                                offset: CGSize(width: 10, height: -10)
                            )
                        }

                        if showTrialDaysBadge {
                            trialDaysBadgeView(
                                text: trialDaysBadgeText,
                                offset: CGSize(width: -19, height: -10)
                            )
                        }

                        if showPermissionBadge {
                            badgeView(
                                system: "exclamationmark",
                                fg: .white,
                                bg: Color.Glu.acidCGMRed,
                                offset: CGSize(width: 10, height: 10)
                            )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 12)
            .zIndex(2)
        }
        .frame(height: 44)
        .tint(Color.Glu.systemForeground)

        // ============================================================
        // MARK: - Report Step 1: Period Selection
        // ============================================================

        .confirmationDialog(
            L10n.MetabolicReportFlow.periodDialogTitle,
            isPresented: $showReportPeriodDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.MetabolicReportFlow.period7Days)  { openReport(days: 7) }
            Button(L10n.MetabolicReportFlow.period14Days) { openReport(days: 14) }
            Button(L10n.MetabolicReportFlow.period30Days) { openReport(days: 30) }
            Button(L10n.MetabolicReportFlow.period90Days) { openReport(days: 90) }
            Button(L10n.MetabolicReportFlow.cancel, role: .cancel) {
                appState.isMetabolicReportPresented = false
            }
        }

        // ============================================================
        // MARK: - Report Step 2: Daily Charts Appendix
        // ============================================================

        .confirmationDialog(
            "",
            isPresented: $showIncludeDailyChartsDialog,
            titleVisibility: .hidden
        ) {
            Button(L10n.MetabolicReportFlow.include) { presentReportPreview(includeCharts: true) }
            Button(L10n.MetabolicReportFlow.skip) { presentReportPreview(includeCharts: false) }
            Button(L10n.MetabolicReportFlow.cancel, role: .cancel) {
                appState.isMetabolicReportPresented = false
            }
        } message: {
            Text(L10n.MetabolicReportFlow.includeDailyChartsMessage)
        }

        // ============================================================
        // MARK: - Report Preview Sheet
        // ============================================================

        .sheet(
            isPresented: $showReportPreview,
            onDismiss: {
                appState.isMetabolicReportPresented = false
            }
        ) {
            MetabolicReportPreviewV1(
                windowDays: selectedReportDays,
                includeDailyChartsInReport: includeDailyChartsInReport
            )
            .environmentObject(appState)
            .environmentObject(healthStore)
            .environmentObject(settings)
            .environmentObject(entitlementManager) // 🟨 UPDATED
            .tint(Color.Glu.systemForeground)
            .onAppear {
                appState.isMetabolicReportPresented = true
            }
            .onDisappear {
                appState.isMetabolicReportPresented = false
            }
        }
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    @MainActor
    private func openReport(days: Int) {
        selectedReportDays = days
        showIncludeDailyChartsDialog = true
    }

    @MainActor
    private func presentReportPreview(includeCharts: Bool) {
        includeDailyChartsInReport = includeCharts

        showReportPreview = false
        DispatchQueue.main.async {
            showReportPreview = true
        }
    }

    private func badgeView(
        system: String,
        fg: Color,
        bg: Color = .white,
        offset: CGSize
    ) -> some View {
        ZStack {
            Circle()
                .fill(bg)
                .frame(width: 18, height: 18)

            Image(systemName: system)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(fg)
        }
        .offset(offset)
    }

    private func trialDaysBadgeView(
        text: String,
        offset: CGSize
    ) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.Glu.primaryBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .frame(minWidth: 24, minHeight: 20)
            .background(
                Capsule()
                    .fill(Color.white)
            )
            .overlay(
                Capsule()
                    .stroke(Color.Glu.primaryBlue.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 1)
            .offset(offset)
    }
}
