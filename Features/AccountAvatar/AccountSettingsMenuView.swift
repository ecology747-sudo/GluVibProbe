//
//  AccountSettingsMenuView.swift
//  GluVibProbe
//

import SwiftUI

struct AccountSettingsMenuView: View {

    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore

    let onOpenAppStatus: () -> Void
    let onOpenTargetsThresholds: () -> Void
    let onOpenUnits: () -> Void
    let onOpenHealthKitPermissions: () -> Void

    // MARK: - Style

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.70)
    private let menuIconColumnWidth: CGFloat = 34 // 🟨 UPDATED

    // MARK: - Access Status (same logic as AccountMenuSheetView)

    private enum AccessStatus {
        case premiumPurchased
        case trial(daysLeft: Int?)
        case free
    }

    private var accessStatus: AccessStatus {
        if settings.isPremiumEnabled {
            return .premiumPurchased
        }
        if settings.isTrialActive {
            return .trial(daysLeft: settings.trialDaysRemaining)
        }
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

    private var statusTitle: String { // 🟨 UPDATED
        switch accessStatus {
        case .premiumPurchased:
            return L10n.Avatar.Status.premium
        case .trial:
            return String(
                localized: "Trial",
                defaultValue: "Trial",
                comment: "Trial access status title in the account settings menu"
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

    private var statusLine2: String { // 🟨 UPDATED
        switch accessStatus {
        case .premiumPurchased:
            return L10n.Avatar.Status.unlockedOnThisDevice
        case .trial:
            return L10n.Avatar.Status.active
        case .free:
            return L10n.Avatar.Status.noActiveAccess
        }
    }

    private var trialDaysLeftTextV1: String? { // 🟨 UPDATED
        guard case .trial(let daysLeft) = accessStatus else { return nil }
        guard let d = daysLeft else { return nil }
        return L10n.Avatar.Status.trialDaysLeft(d)
    }

    private var modeStatusLineV1: String { // 🟨 UPDATED
        if settings.hasCGM == false { return L10n.Avatar.Mode.cgmOff }
        return settings.isInsulinTreated
            ? L10n.Avatar.Mode.cgmOnInsulinOn
            : L10n.Avatar.Mode.cgmOnInsulinOff
    }

    // MARK: - Permission Badge (same logic as SettingsView/AccountMenu)

    private var needsHealthKitPermissionsV1: Bool {
        guard settings.showPermissionWarnings else { return false } // 🟨 UPDATED

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

        return insulinNeeds || glucoseNeeds || metabolicCarbsNeeds || nutritionNeeds || activityNeeds || bodyNeeds
    }
    
    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            statusHeaderNoAvatarV1
                .padding(.top, 10)
                .padding(.bottom, 10)

            Divider()

            List {
                Section {

                    Button { onOpenAppStatus() } label: {
                        HStack(spacing: 10) {
                            menuIcon("person.crop.circle")
                            menuTitle(L10n.Avatar.Menu.appStatus) // 🟨 UPDATED
                            Spacer()
                        }
                    }

                    Button { onOpenTargetsThresholds() } label: {
                        HStack(spacing: 10) {
                            menuIcon("target")
                            menuTitle(
                                String(
                                    localized: "Targets & Thresholds",
                                    defaultValue: "Targets & Thresholds",
                                    comment: "Menu item title for targets and thresholds in the account settings menu"
                                )
                            )
                            Spacer()
                        }
                    }

                    Button { onOpenUnits() } label: {
                        HStack(spacing: 10) {
                            menuIcon("ruler")
                            menuTitle(L10n.Avatar.Menu.units) // 🟨 UPDATED
                            Spacer()
                        }
                    }

                    Button { onOpenHealthKitPermissions() } label: {
                        HStack(spacing: 10) {
                            menuIcon("checkmark.shield")
                            menuTitle(
                                String(
                                    localized: "HealthKit Permissions",
                                    defaultValue: "HealthKit Permissions",
                                    comment: "Menu item title for HealthKit permissions in the account settings menu"
                                )
                            )
                            Spacer()

                            if needsHealthKitPermissionsV1 {
                                permissionBadgeIconV1
                                    .accessibilityLabel(
                                        String(
                                            localized: "Permission required",
                                            defaultValue: "Permission required",
                                            comment: "Accessibility label for permission badge in the account settings menu"
                                        )
                                    )
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .tint(titleColor)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(
                    String(
                        localized: "Settings",
                        defaultValue: "Settings",
                        comment: "Navigation title for the account settings menu"
                    )
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }

    // MARK: - Header (NO avatar)

    private var statusHeaderNoAvatarV1: some View {
        VStack(spacing: 6) {

            HStack(spacing: 8) {

                Image(systemName: statusIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusIconColor)

                if accessStatusIsTrial {
                    Text(
                        String(
                            localized: "Trial",
                            defaultValue: "Trial",
                            comment: "Trial access status title in the account settings menu"
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
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Hard-colored menu atoms (prevents iOS accent bleed)

    private func menuIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .frame(width: menuIconColumnWidth, alignment: .leading) // 🟨 UPDATED
            .foregroundStyle(titleColor)
    }

    private func menuTitle(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(titleColor)
    }

    // MARK: - Badge Icon

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

#if DEBUG
#Preview("AccountSettingsMenuView") {
    NavigationStack {
        AccountSettingsMenuView(
            onOpenAppStatus: {},
            onOpenTargetsThresholds: {},
            onOpenUnits: {},
            onOpenHealthKitPermissions: {}
        )
        .environmentObject(SettingsModel.shared)
        .environmentObject(HealthStore.preview())
    }
}
#endif
