//
//  AccountSettingsMenuView.swift
//  GluVib
//
//  Area: Account / Settings Entry
//  File Role:
//  - Secondary account settings menu inside the account flow.
//  - Shows the current GluVib access status in the header without recalculating
//    premium / trial / free locally.
//  - Provides entry points to app status, targets, units, and HealthKit permissions.
//
//  Purpose:
//  - Consume the central monetization truth from EntitlementManager.
//  - Keep the settings-side account header aligned with the account root header
//    and with the new monetization layer.
//  - Preserve existing localized menu entries and HealthKit permission badge logic.
//
//  System Role:
//  - This View is user-facing UI.
//  - It does NOT define entitlement truth.
//  - It does NOT resolve StoreKit products.
//  - It does NOT perform routing policy decisions.
//
//  Key Connections:
//  - SettingsModel
//  - HealthStore
//  - EntitlementManager
//  - localized strings via L10n
//

import SwiftUI

struct AccountSettingsMenuView: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var entitlementManager: EntitlementManager // 🟨 UPDATED

    let onOpenAppStatus: () -> Void
    let onOpenTargetsThresholds: () -> Void
    let onOpenUnits: () -> Void
    let onOpenHealthKitPermissions: () -> Void

    // ============================================================
    // MARK: - Style
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.70)
    private let menuIconColumnWidth: CGFloat = 34

    // ============================================================
    // MARK: - Derived Access Status
    // ============================================================

    private var isTrial: Bool {
        entitlementManager.isTrial
    }

    private var isPremium: Bool {
        entitlementManager.isPremium
    }

    private var statusTitle: String {
        switch entitlementManager.entitlementStatus {
        case .premium:
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
        switch entitlementManager.entitlementStatus {
        case .premium: return "crown.fill"
        case .trial: return "hourglass"
        case .free: return "sparkles"
        }
    }

    private var statusIconColor: Color {
        switch entitlementManager.entitlementStatus {
        case .premium: return .yellow
        case .trial: return Color.Glu.bodyDomain
        case .free: return titleColor
        }
    }

    private var statusLine2: String {
        switch entitlementManager.entitlementStatus {
        case .premium:
            return L10n.Avatar.Status.unlockedOnThisDevice
        case .trial:
            return L10n.Avatar.Status.active
        case .free:
            return L10n.Avatar.Status.noActiveAccess
        }
    }

    private var trialDaysLeftTextV1: String? {
        guard let daysLeft = entitlementManager.trialDaysRemaining else { return nil }
        return L10n.Avatar.Status.trialDaysLeft(daysLeft)
    }

    private var modeStatusLineV1: String {
        if settings.hasCGM == false { return L10n.Avatar.Mode.cgmOff }
        return settings.isInsulinTreated
            ? L10n.Avatar.Mode.cgmOnInsulinOn
            : L10n.Avatar.Mode.cgmOnInsulinOff
    }

    // ============================================================
    // MARK: - Permission Badge
    // ============================================================

    private var needsHealthKitPermissionsV1: Bool {
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

        return insulinNeeds || glucoseNeeds || metabolicCarbsNeeds || nutritionNeeds || activityNeeds || bodyNeeds
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

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
                            menuTitle(L10n.Avatar.Menu.appStatus)
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
                            menuTitle(L10n.Avatar.Menu.units)
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

    // ============================================================
    // MARK: - Header
    // ============================================================

    private var statusHeaderNoAvatarV1: some View {
        VStack(spacing: 6) {

            HStack(spacing: 8) {

                Image(systemName: statusIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusIconColor)

                if isTrial {
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

            if isTrial == false, isPremium == false {
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

    // ============================================================
    // MARK: - Menu Atoms
    // ============================================================

    private func menuIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .frame(width: menuIconColumnWidth, alignment: .leading)
            .foregroundStyle(titleColor)
    }

    private func menuTitle(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(titleColor)
    }

    // ============================================================
    // MARK: - Badge Icon
    // ============================================================

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
        .environmentObject(EntitlementManager()) // 🟨 UPDATED
    }
}
#endif
