//
//  SectionHeader.swift
//  GluVib
//
//  Area: Shared / Header
//  File Role:
//  - Reusable section header used across GluVib screens.
//  - Displays title / subtitle, optional back action, optional avatar,
//    premium / trial status badges, and permission badges.
//
//  Purpose:
//  - Keep header presentation consistent across the app.
//  - Consume the central monetization truth from EntitlementManager for
//    premium / trial badge display.
//  - Preserve the existing permission-badge behavior tied to HealthStore
//    and user intent settings.
//
//  System Role:
//  - This file is UI only.
//  - It does NOT define premium / trial / free truth.
//  - It does NOT resolve capabilities.
//  - It only renders badges based on already-resolved app state.
//
//  Key Connections:
//  - SettingsModel
//  - HealthStore
//  - EntitlementManager
//

import SwiftUI

struct SectionHeader: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var entitlementManager: EntitlementManager // 🟨 UPDATED

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let title: String
    let subtitle: String?
    let tintColor: Color
    let onBack: (() -> Void)?

    let showsAvatar: Bool
    let onAvatarTapped: (() -> Void)?

    let showsPermissionBadge: Bool

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
    // MARK: - Init
    // ============================================================

    init(
        title: String,
        subtitle: String? = nil,
        tintColor: Color = Color.Glu.primaryBlue,
        onBack: (() -> Void)? = nil,
        showsAvatar: Bool = true,
        onAvatarTapped: (() -> Void)? = nil,
        showsPermissionBadge: Bool = false,
        permissionBadgeScope: PermissionBadgeScope = .none
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.onBack = onBack
        self.showsAvatar = showsAvatar
        self.onAvatarTapped = onAvatarTapped
        self.showsPermissionBadge = showsPermissionBadge
        self.permissionBadgeScope = permissionBadgeScope
    }

    // ============================================================
    // MARK: - Monetization Badges
    // ============================================================

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

    // ============================================================
    // MARK: - Permission Badge
    // ============================================================

    private var computedPermissionBadge: Bool {
        guard settings.showPermissionWarnings else { return false }

        switch permissionBadgeScope {
        case .none:
            return showsPermissionBadge

        case .metabolic:
            let glucoseNeeds = settings.hasCGM && healthStore.glucoseReadAuthIssueV1
            let therapyNeeds = settings.hasCGM && settings.isInsulinTreated && healthStore.metabolicTherapyAuthIssueAnyV1
            let carbsNeeds = settings.hasCGM && settings.isInsulinTreated && healthStore.metabolicCarbsAuthIssueAnyV1
            return glucoseNeeds || therapyNeeds || carbsNeeds

        case .nutrition:
            return healthStore.nutritionAnyAuthIssueForBadgesV1

        case .activity:
            return healthStore.activityAnyAuthIssueForBadgesV1

        case .body:
            return healthStore.bodyAnyAuthIssueForBadgesV1

        case .allDomains:
            let glucoseNeeds = settings.hasCGM && healthStore.metabolicGlucoseAuthIssueAnyV1
            let therapyNeeds = settings.hasCGM && settings.isInsulinTreated && healthStore.metabolicTherapyAuthIssueAnyV1
            let carbsNeeds = settings.hasCGM && settings.isInsulinTreated && healthStore.metabolicCarbsAuthIssueAnyV1

            let nutritionNeeds = healthStore.nutritionAnyAuthIssueForBadgesV1
            let activityNeeds = healthStore.activityAnyAuthIssueForBadgesV1
            let bodyNeeds = healthStore.bodyAnyAuthIssueForBadgesV1

            return glucoseNeeds || therapyNeeds || carbsNeeds || nutritionNeeds || activityNeeds || bodyNeeds
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
                    .font(.headline.weight(.semibold))
                    .foregroundColor(tintColor)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(tintColor.opacity(0.75))
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)

            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(tintColor)
                    }
                    .accessibilityLabel(
                        String(
                            localized: "Back",
                            defaultValue: "Back",
                            comment: "Accessibility label for section header back button"
                        )
                    )
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                } else {
                    Spacer().frame(width: 44)
                }

                Spacer()

                if showsAvatar {
                    Button {
                        onAvatarTapped?()
                    } label: {
                        ZStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 27, weight: .semibold))
                                .foregroundColor(Color.Glu.primaryBlue)
                                .shadow(
                                    color: Color.black.opacity(0.22),
                                    radius: 4.5,
                                    x: 0,
                                    y: 2
                                )
                                .accessibilityLabel(
                                    String(
                                        localized: "Account menu",
                                        defaultValue: "Account menu",
                                        comment: "Accessibility label for section header account avatar button"
                                    )
                                )
                                .padding(6)

                            if showPremiumBadge {
                                badgeView(
                                    system: "crown.fill",
                                    fg: .yellow,
                                    bg: .white,
                                    offset: CGSize(width: 10, height: -10)
                                )
                                .accessibilityHidden(true)
                            }

                            if showTrialDaysBadge {
                                trialDaysBadgeView(
                                    text: trialDaysBadgeText,
                                    offset: CGSize(width: -19, height: -10)
                                )
                                .accessibilityHidden(true)
                            }

                            if computedPermissionBadge {
                                badgeView(
                                    system: "exclamationmark",
                                    fg: .white,
                                    bg: Color.Glu.acidCGMRed,
                                    offset: CGSize(width: 10, height: 10)
                                )
                                .accessibilityLabel(
                                    String(
                                        localized: "Permission required",
                                        defaultValue: "Permission required",
                                        comment: "Accessibility label for section header permission badge"
                                    )
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                } else {
                    Spacer().frame(width: 44)
                }
            }
        }
        .frame(height: 44)
    }

    // ============================================================
    // MARK: - Badge Views
    // ============================================================

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

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    let settings = SettingsModel.shared
    let store = HealthStore.preview()
    let entitlementManager = EntitlementManager() // 🟨 UPDATED

    store.glucoseReadAuthIssueV1 = true

    return VStack(spacing: 24) {

        SectionHeader(
            title: "Units",
            tintColor: Color.Glu.primaryBlue,
            onBack: { },
            showsAvatar: false
        )

        SectionHeader(
            title: "Metabolic",
            subtitle: "Basal",
            tintColor: Color.Glu.metabolicDomain,
            onBack: nil,
            showsAvatar: true,
            onAvatarTapped: { },
            permissionBadgeScope: .metabolic
        )
    }
    .environmentObject(settings)
    .environmentObject(store)
    .environmentObject(entitlementManager) // 🟨 UPDATED
    .background(Color.white)
}
