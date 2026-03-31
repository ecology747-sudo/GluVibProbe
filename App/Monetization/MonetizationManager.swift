//
//  MonetizationManager.swift
//  GluVib
//
//  Area: App / Monetization
//  File Role:
//  - Owns the central monetization runtime state for GluVib.
//  - Resolves the single commercial app status from:
//    - app-owned 30-day trial logic
//    - the currently active entitlement provider
//
//  Purpose:
//  - Replace scattered premium / trial / free calculations across Views,
//    AppState, and SettingsModel with one canonical source of truth.
//  - Keep current TestFlight iteration possible while preparing the later
//    StoreKit-based production flow.
//  - Provide a controlled shared read-access point for non-UI service files
//    that cannot consume monetization via EnvironmentObject.
//
//  System Role:
//  - This file does NOT define detailed screen gating.
//  - This file does NOT own UI / paywall rendering.
//  - This file does NOT fetch HealthKit data.
//  - This file only answers the commercial status question:
//    "Is the app currently premium, trial, or free?"
//
//  Current Transition Rule:
//  - Trial remains app-owned logic.
//  - Premium currently comes from the active entitlement provider.
//  - The final app status is resolved here and published centrally.
//

import Foundation
import Combine

// ============================================================
// MARK: - Trial Manager
// ============================================================

/// Manages the local GluVib 30-day trial window.
///
/// Current transition behavior:
/// - Trial start is still persisted via SettingsModel during migration.
/// - This keeps the current app flow stable while the monetization layer
///   is introduced.
/// - Later, the persistence backing can be moved without changing the rest
///   of the monetization architecture.
struct TrialManager {

    // ========================================================
    // MARK: - Configuration
    // ========================================================

    private let trialLengthDays: Int = 30

    // ========================================================
    // MARK: - Trial Evaluation
    // ========================================================

    func trialStartDate(from settings: SettingsModel) -> Date? {
        settings.trialStartDate
    }

    func hasTrialStarted(settings: SettingsModel) -> Bool {
        trialStartDate(from: settings) != nil
    }

    func isTrialActive(settings: SettingsModel, now: Date = Date()) -> Bool {
        guard let start = trialStartDate(from: settings) else { return false }
        guard let trialEnd = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) else {
            return false
        }

        return now < trialEnd
    }

    func trialDaysRemaining(settings: SettingsModel, now: Date = Date()) -> Int? {
        guard let start = trialStartDate(from: settings) else { return nil }
        guard let trialEnd = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) else {
            return nil
        }

        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: now)
        let toDay = calendar.startOfDay(for: trialEnd)
        let days = calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0

        return max(0, days)
    }

    // ========================================================
    // MARK: - Trial Start Control
    // ========================================================

    /// Starts the local trial if the current onboarding conditions allow it.
    ///
    /// Current rule mirrors the existing app behavior:
    /// - onboarding must be completed
    /// - trial must not already exist
    func ensureTrialStartedIfEligible(settings: SettingsModel, now: Date = Date()) {
        guard settings.hasCompletedOnboarding else { return }
        guard settings.trialStartDate == nil else { return }

        settings.trialStartDate = now
        settings.saveToDefaults()
    }
}

// ============================================================
// MARK: - Entitlement Resolver
// ============================================================

/// Pure resolution logic for the final commercial app state.
///
/// Resolution order:
/// 1. Active premium from provider wins.
/// 2. Otherwise active trial wins.
/// 3. Otherwise the app is free.
struct EntitlementResolver {

    func resolveStatus(
        providerSnapshot: ProviderEntitlementSnapshot,
        settings: SettingsModel,
        trialManager: TrialManager,
        now: Date = Date()
    ) -> EntitlementStatus {

        if providerSnapshot.hasActivePremium {
            return .premium(plan: providerSnapshot.subscriptionPlan)
        }

        if trialManager.isTrialActive(settings: settings, now: now) {
            let daysRemaining = trialManager.trialDaysRemaining(settings: settings, now: now) ?? 0
            return .trial(daysRemaining: daysRemaining)
        }

        return .free
    }
}

// ============================================================
// MARK: - Entitlement Manager
// ============================================================

/// Central published monetization state for the app.
///
/// This object should become the single commercial source of truth consumed by:
/// - AppState
/// - ContentView
/// - account / app status UI
/// - capability resolution
///
/// Current transition notes:
/// - provider defaults to the internal test provider configuration
/// - trial start persistence still uses SettingsModel during migration
/// - a controlled shared instance is provided for non-UI service files
@MainActor
final class EntitlementManager: ObservableObject {

    // ========================================================
    // MARK: - Shared Access
    // ========================================================

    /// Controlled shared app-wide monetization instance.
    ///
    /// Usage rule:
    /// - UI should continue to consume this manager via EnvironmentObject.
    /// - Non-UI service / orchestration files may read this shared instance
    ///   when EnvironmentObject injection is not available.
    static let shared = EntitlementManager()

    // ========================================================
    // MARK: - Published State
    // ========================================================

    @Published private(set) var monetizationSource: MonetizationSource
    @Published private(set) var providerSnapshot: ProviderEntitlementSnapshot
    @Published private(set) var entitlementStatus: EntitlementStatus

    // ========================================================
    // MARK: - Dependencies
    // ========================================================

    private let provider: EntitlementProvider
    private let trialManager: TrialManager
    private let resolver: EntitlementResolver
    private let settings: SettingsModel

    // ========================================================
    // MARK: - Init
    // ========================================================

    init(
        settings: SettingsModel = .shared,
        provider: EntitlementProvider = MonetizationProviderConfig.makeProvider(),
        trialManager: TrialManager = TrialManager(),
        resolver: EntitlementResolver = EntitlementResolver()
    ) {
        self.settings = settings
        self.provider = provider
        self.trialManager = trialManager
        self.resolver = resolver

        let initialSnapshot = ProviderEntitlementSnapshot(
            source: provider.source,
            hasActivePremium: false,
            subscriptionPlan: .none
        )

        self.monetizationSource = provider.source
        self.providerSnapshot = initialSnapshot
        self.entitlementStatus = .free
    }

    // ========================================================
    // MARK: - Public API
    // ========================================================

    /// Ensures the local trial exists once onboarding is completed.
    ///
    /// This keeps the current app behavior intact while the monetization
    /// architecture is migrated into its own layer.
    func ensureTrialStartedIfEligible(now: Date = Date()) {
        trialManager.ensureTrialStartedIfEligible(settings: settings, now: now)
    }

    /// Refreshes the premium-side provider snapshot and resolves the final
    /// commercial app status.
    func refresh(now: Date = Date()) async {
        let snapshot = await provider.currentSnapshot()
        let resolvedStatus = resolver.resolveStatus(
            providerSnapshot: snapshot,
            settings: settings,
            trialManager: trialManager,
            now: now
        )

        monetizationSource = snapshot.source
        providerSnapshot = snapshot
        entitlementStatus = resolvedStatus
    }

    // ========================================================
    // MARK: - Convenience API
    // ========================================================

    var isPremium: Bool {
        entitlementStatus.isPremium
    }

    var isTrial: Bool {
        entitlementStatus.isTrial
    }

    var isFree: Bool {
        entitlementStatus.isFree
    }

    var hasFullAppAccess: Bool {
        entitlementStatus.hasFullAppAccess
    }

    var canAccessMetabolic: Bool {
        entitlementStatus.canAccessMetabolic
    }

    var trialDaysRemaining: Int? {
        entitlementStatus.trialDaysRemaining
    }

    var subscriptionPlan: SubscriptionPlan {
        entitlementStatus.subscriptionPlan
    }
}
