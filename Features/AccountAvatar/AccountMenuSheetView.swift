//
//  AccountMenuSheetView.swift
//  GluVibProbe
//

import SwiftUI

struct AccountMenuSheetView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore

    let onOpenSettingsMenu: () -> Void
    let onOpenHelp: () -> Void
    let onOpenFAQ: () -> Void
    let onOpenAppInfo: () -> Void
    let onOpenLegal: () -> Void

    // MARK: - Style

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.70)
    private let menuIconColumnWidth: CGFloat = 34 // 🟨 UPDATED

    // ============================================================
    // MARK: - Permission Badge (V1) — domain aggregation + UI gating
    // ============================================================

    private var showsSettingsPermissionBadgeV1: Bool {
        guard settings.showPermissionWarnings else { return false }

        let insulinNeeds =
            settings.isInsulinTreated &&
            healthStore.metabolicTherapyAuthIssueAnyV1

        let glucoseNeeds =
            settings.hasCGM &&
            healthStore.metabolicGlucoseAuthIssueAnyV1

        let metabolicCarbsNeeds =
            settings.isInsulinTreated &&
            healthStore.metabolicCarbsAuthIssueAnyV1

        let nutritionNeeds = healthStore.nutritionAnyAuthIssueForBadgesV1
        let activityNeeds  = healthStore.activityAnyAuthIssueForBadgesV1
        let bodyNeeds      = healthStore.bodyAnyAuthIssueForBadgesV1

        return
            insulinNeeds ||
            glucoseNeeds ||
            metabolicCarbsNeeds ||
            nutritionNeeds ||
            activityNeeds ||
            bodyNeeds
    }

    // MARK: - Access Status

    private enum AccessStatus {
        case premiumPurchased
        case trial(daysLeft: Int?)
        case free
    }

    private var accessStatus: AccessStatus {
        if settings.isPremiumEnabled { return .premiumPurchased }
        if settings.isTrialActive { return .trial(daysLeft: settings.trialDaysRemaining) }
        return .free
    }

    private var accessStatusIsTrial: Bool {
        if case .trial = accessStatus { return true }
        return false
    }

    private var isPremium: Bool {
        if case .premiumPurchased = accessStatus { return true }
        return false
    }

    private var statusTitle: String {
        switch accessStatus {
        case .premiumPurchased:
            return L10n.Avatar.Status.premium
        case .trial:
            return String(
                localized: "Trial",
                defaultValue: "Trial",
                comment: "Trial access status title in the account menu sheet"
            )
        case .free:
            return L10n.Avatar.Status.free
        }
    }

    private var statusIcon: String {
        switch accessStatus {
        case .premiumPurchased: return "crown.fill"
        case .trial: return "hourglass"
        case .free: return "sparkles"
        }
    }

    private var statusIconColor: Color {
        switch accessStatus {
        case .premiumPurchased: return .yellow
        case .trial: return Color.Glu.bodyDomain
        case .free: return titleColor
        }
    }

    private var statusLine2: String {
        switch accessStatus {
        case .premiumPurchased:
            return L10n.Avatar.Status.unlockedOnThisDevice
        case .trial:
            return L10n.Avatar.Status.active
        case .free:
            return L10n.Avatar.Status.noActiveAccess
        }
    }

    private var trialDaysLeftTextV1: String? {
        guard case .trial(let daysLeft) = accessStatus else { return nil }
        guard let d = daysLeft else { return nil }
        return L10n.Avatar.Status.trialDaysLeft(d)
    }

    private var modeStatusLineV1: String {
        if settings.hasCGM == false {
            return L10n.Avatar.Mode.cgmOff
        }

        if settings.isInsulinTreated {
            return L10n.Avatar.Mode.cgmOnInsulinOn
        }

        return L10n.Avatar.Mode.cgmOnInsulinOff
    }

    // MARK: - Body

    var body: some View {

        VStack(spacing: 0) {

            VStack(spacing: 8) {

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .shadow(color: .black.opacity(0.18), radius: 3.5, x: 1, y: 2)
                    .padding(.top, 12)

                HStack(spacing: 8) {

                    Image(systemName: statusIcon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(statusIconColor)

                    if accessStatusIsTrial {
                        Text(
                            String(
                                localized: "Trial",
                                defaultValue: "Trial",
                                comment: "Trial access status title in the account menu sheet"
                            )
                        )
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(titleColor)

                        if let t = trialDaysLeftTextV1 {
                            Text(t)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(titleColor.opacity(0.80))
                                .baselineOffset(-1)
                        }
                    } else {
                        Text(statusTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(titleColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                if accessStatusIsTrial == false, isPremium == false {
                    Text(statusLine2)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(captionColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text(modeStatusLineV1)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(titleColor.opacity(0.80))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
            }

            Divider()

            List {
                Section {

                    Button { onOpenSettingsMenu() } label: {
                        HStack(spacing: 10) {
                            menuIcon("gearshape")
                            menuTitle(
                                String(
                                    localized: "Settings",
                                    defaultValue: "Settings",
                                    comment: "Menu item title for settings in the account menu sheet"
                                )
                            )
                            Spacer()

                            if showsSettingsPermissionBadgeV1 {
                                permissionBadgeIconV1
                                    .accessibilityLabel(
                                        String(
                                            localized: "Permission required",
                                            defaultValue: "Permission required",
                                            comment: "Accessibility label for permission badge in the account menu sheet"
                                        )
                                    )
                            }
                        }
                    }

                    Button { onOpenFAQ() } label: {
                        HStack(spacing: 10) {
                            menuIcon("questionmark.circle")
                            menuTitle(L10n.Avatar.Menu.frequentlyAskedQuestions)
                            Spacer()
                        }
                    }

                    Button { onOpenHelp() } label: {
                        HStack(spacing: 10) {
                            menuIcon("bubble.left.and.bubble.right")
                            menuTitle(
                                String(
                                    localized: "Help & Feedback",
                                    defaultValue: "Help & Feedback",
                                    comment: "Menu item title for help and feedback in the account menu sheet"
                                )
                            )
                            Spacer()
                        }
                    }

                    Button { onOpenAppInfo() } label: {
                        HStack(spacing: 10) {
                            menuIcon("info.circle")
                            menuTitle(
                                String(
                                    localized: "App Info",
                                    defaultValue: "App Info",
                                    comment: "Menu item title for app info in the account menu sheet"
                                )
                            )
                            Spacer()
                        }
                    }

                    Button { onOpenLegal() } label: {
                        HStack(spacing: 10) {
                            menuIcon("doc.text")
                            menuTitle(L10n.Avatar.Menu.legalInformation)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .tint(titleColor)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hard-colored menu atoms (fixes iOS accent bleed)

    private func menuIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .frame(width: menuIconColumnWidth, alignment: .leading) // 🟨 UPDATED
            .foregroundStyle(titleColor)
    }

    private func menuTitle(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(titleColor)
    }

    // MARK: - Badge View (18x18)

    private var permissionBadgeIconV1: some View {
        ZStack {
            Circle()
                .fill(Color.Glu.acidCGMRed)
                .frame(width: 18, height: 18)

            Image(systemName: "exclamationmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(.trailing, 2)
    }
}
