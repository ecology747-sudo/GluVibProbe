//
//  ManageAccountHomeView.swift
//  GluVib
//
//  Area: Account / Monetization Status
//  File Role:
//  - User-facing status screen for GluVib access state and metabolic visibility controls.
//  - Reads the central monetization truth from EntitlementManager instead of calculating
//    premium / trial / free locally inside the View.
//
//  Purpose:
//  - Show the current commercial access state:
//    - Premium
//    - Trial
//    - Free
//  - Expose the current metabolic visibility intent:
//    - Show sensor data (CGM)
//    - Show insulin data
//  - Keep the current TestFlight transition flow working while the app is migrated
//    toward the dedicated monetization layer.
//
//  System Role:
//  - This View is user-facing UI.
//  - This View does NOT define the commercial truth itself.
//  - This View does NOT resolve capabilities itself.
//  - This View consumes EntitlementManager and triggers refresh / enforcement when
//    transition-state toggles change.
//
//  Key Connections:
//  - SettingsModel
//  - AppState
//  - HealthStore
//  - EntitlementManager
//

import SwiftUI
import HealthKit

struct ManageAccountHomeView: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var entitlementManager: EntitlementManager // 🟨 UPDATED

    // ============================================================
    // MARK: - Style
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.70)

    private let premiumTint: Color = .yellow
    private let premiumCardFill: Color = .yellow.opacity(0.10)
    private let premiumCardStroke: Color = .yellow.opacity(0.35)

    private let metabolicTint: Color = Color.Glu.metabolicDomain
    private let metabolicCardFill: Color = Color.Glu.metabolicDomain.opacity(0.10)
    private let metabolicCardStroke: Color = Color.Glu.metabolicDomain.opacity(0.35)

    // ============================================================
    // MARK: - Derived Status
    // ============================================================

    private var statusTitle: String {
        switch entitlementManager.entitlementStatus {
        case .premium:
            return L10n.Avatar.Status.premium
        case .trial:
            return String(
                localized: "Trial",
                defaultValue: "Trial",
                comment: "Trial access status title in manage app status view"
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
        case .free: return Color.Glu.primaryBlue
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
        guard let days = entitlementManager.trialDaysRemaining else { return nil }
        return L10n.Avatar.Status.trialDaysLeft(days)
    }

    private var modeStatusLineV1: String {
        if settings.hasCGM == false { return L10n.Avatar.Mode.cgmOff }
        return settings.isInsulinTreated
            ? L10n.Avatar.Mode.cgmOnInsulinOn
            : L10n.Avatar.Mode.cgmOnInsulinOff
    }

    private var isTrial: Bool {
        entitlementManager.isTrial
    }

    private var isPremium: Bool {
        entitlementManager.isPremium
    }

    private var canUseMetabolicControls: Bool {
        entitlementManager.canAccessMetabolic
    }

    // ============================================================
    // MARK: - Toggle Edge Tracking
    // ============================================================

    @State private var lastHasCGM: Bool = false
    @State private var lastIsInsulinTreated: Bool = false

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusHeaderCenteredV1
                appStatusCard
                premiumAccessCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color("GluSoftGray"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(
                    String(
                        localized: "Manage App Status",
                        defaultValue: "Manage App Status",
                        comment: "Navigation title for manage app status view"
                    )
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
        .onAppear {
            lastHasCGM = settings.hasCGM
            lastIsInsulinTreated = settings.isInsulinTreated
        }
        .onChange(of: settingsSnapshotKeyV1) { _ in
            let prevCGM = lastHasCGM
            let prevInsulin = lastIsInsulinTreated

            applyGatingRulesSaveEnforceV1()

            lastHasCGM = settings.hasCGM
            lastIsInsulinTreated = settings.isInsulinTreated

            Task { @MainActor in
                await handlePostToggleAuthorizationV1IfNeeded(
                    prevHasCGM: prevCGM,
                    prevIsInsulinTreated: prevInsulin
                )
            }
        }
        .onChange(of: settings.isPremiumEnabled) { _ in // 🟨 UPDATED
            Task { @MainActor in
                await entitlementManager.refresh()
                appState.enforceAccessAfterPremiumChange(
                    settings: settings,
                    entitlementManager: entitlementManager
                )
            }
        }
        .onChange(of: entitlementManager.entitlementStatus) { _ in // 🟨 UPDATED
            appState.enforceAccessAfterPremiumChange(
                settings: settings,
                entitlementManager: entitlementManager
            )
        }
    }

    // ============================================================
    // MARK: - Snapshot Key
    // ============================================================

    private var settingsSnapshotKeyV1: String {
        [
            settings.isPremiumEnabled ? "P1" : "P0",
            settings.hasCGM ? "C1" : "C0",
            settings.isInsulinTreated ? "I1" : "I0",
            settings.trialStartDate != nil ? "T1" : "T0"
        ].joined(separator: "|")
    }

    // ============================================================
    // MARK: - Header
    // ============================================================

    private var statusHeaderCenteredV1: some View {
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
                            comment: "Trial access status title in manage app status view"
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
        .padding(.top, 2)
    }

    // ============================================================
    // MARK: - Card A: App Status
    // ============================================================

    private var appStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if canUseMetabolicControls == false {
                Text(
                    String(
                        localized: "Metabolic controls require Premium or an active Trial.",
                        defaultValue: "Metabolic controls require Premium or an active Trial.",
                        comment: "Message shown when metabolic controls are unavailable in manage app status view"
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(titleColor.opacity(0.85))
            }

            Toggle(isOn: $settings.hasCGM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        String(
                            localized: "Show sensor data (CGM)",
                            defaultValue: "Show sensor data (CGM)",
                            comment: "Toggle title for showing sensor data in manage app status view"
                        )
                    )
                    .font(.headline)
                    .foregroundStyle(titleColor)

                    Text(
                        String(
                            localized: "Enable to show glucose sensor dashboards when sensor data is available in Apple Health.",
                            defaultValue: "Enable to show glucose sensor dashboards when sensor data is available in Apple Health.",
                            comment: "Description for sensor data toggle in manage app status view"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(captionColor)
                }
            }
            .tint(metabolicTint)
            .disabled(!canUseMetabolicControls)

            Divider()

            Toggle(isOn: $settings.isInsulinTreated) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        String(
                            localized: "Show insulin data",
                            defaultValue: "Show insulin data",
                            comment: "Toggle title for showing insulin data in manage app status view"
                        )
                    )
                    .font(.headline)
                    .foregroundStyle(titleColor)

                    Text(
                        String(
                            localized: "Enable to show therapy context when Insulin Delivery data is available in Apple Health.",
                            defaultValue: "Enable to show therapy context when Insulin Delivery data is available in Apple Health.",
                            comment: "Description for insulin data toggle in manage app status view"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(captionColor)

                    if settings.hasCGM == false {
                        Text(
                            String(
                                localized: "Insulin metrics require sensor mode enabled.",
                                defaultValue: "Insulin metrics require sensor mode enabled.",
                                comment: "Hint shown when insulin metrics require sensor mode in manage app status view"
                            )
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(captionColor)
                    }
                }
            }
            .tint(metabolicTint)
            .disabled(!canUseMetabolicControls || !settings.hasCGM)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.48),
                            metabolicCardFill
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(metabolicCardStroke, lineWidth: 1.0)
                )
        )
    }

    // ============================================================
    // MARK: - Card B: Premium Access
    // ============================================================

    private var premiumAccessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    localized: "Premium Access",
                    defaultValue: "Premium Access",
                    comment: "Title of premium access card in manage app status view"
                )
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(titleColor)

            Text(
                String(
                    localized: "Enabling Premium unlocks all features and may involve a paid purchase.",
                    defaultValue: "Enabling Premium unlocks all features and may involve a paid purchase.",
                    comment: "Description of premium access card in manage app status view"
                )
            )
            .font(.caption)
            .foregroundStyle(captionColor)

            Divider().opacity(0.35)

            Toggle(isOn: $settings.isPremiumEnabled) {
                Text(
                    String(
                        localized: "Enable Premium",
                        defaultValue: "Enable Premium",
                        comment: "Toggle title for enabling premium in manage app status view"
                    )
                )
                .font(.headline)
                .foregroundStyle(titleColor)
            }
            .tint(premiumTint)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.48),
                            premiumCardFill
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(premiumCardStroke, lineWidth: 1.0)
                )
        )
    }

    // ============================================================
    // MARK: - Canonical State Enforcement
    // ============================================================

    private func applyGatingRulesSaveEnforceV1() {
        if canUseMetabolicControls == false {
            settings.hasCGM = false
            settings.isInsulinTreated = false
        }

        if settings.hasCGM == false {
            settings.isInsulinTreated = false
        }

        settings.saveToDefaults()

        appState.enforceAccessAfterPremiumChange(
            settings: settings,
            entitlementManager: entitlementManager
        )
    }

    // ============================================================
    // MARK: - Post-toggle Authorization + Refresh
    // ============================================================

    @MainActor
    private func handlePostToggleAuthorizationV1IfNeeded(
        prevHasCGM: Bool,
        prevIsInsulinTreated: Bool
    ) async {
        guard canUseMetabolicControls else { return }

        let cgmJustEnabled = (prevHasCGM == false && settings.hasCGM == true)
        let insulinJustEnabled = (prevIsInsulinTreated == false && settings.isInsulinTreated == true)

        guard cgmJustEnabled || insulinJustEnabled else { return }

        let scope: HealthStore.AuthorizationScopeV1
        if settings.hasCGM == false {
            return
        } else if settings.isInsulinTreated {
            scope = .basePlusCGMPlusInsulin
        } else {
            scope = .basePlusCGM
        }

        let readSet = healthStore.readTypesV1(for: scope)
        guard readSet.isEmpty == false else { return }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            healthStore.healthStore.requestAuthorization(toShare: [], read: readSet) { _, _ in
                DispatchQueue.main.async { cont.resume(returning: ()) }
            }
        }

        await healthStore.refreshMetabolicOverview(.navigation)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ManageAccountHomeView") {
    NavigationStack {
        ManageAccountHomeView()
            .environmentObject(SettingsModel.shared)
            .environmentObject(AppState())
            .environmentObject(HealthStore.preview())
            .environmentObject(EntitlementManager()) // 🟨 UPDATED
    }
}
