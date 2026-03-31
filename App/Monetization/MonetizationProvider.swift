//
//  MonetizationProvider.swift
//  GluVib
//
//  Area: App / Monetization
//  File Role:
//  - Defines the entitlement source abstraction for the GluVib monetization layer.
//  - Provides the current test-oriented entitlement source for the ongoing
//    TestFlight / prototype phase.
//  - Prepares a StoreKit-oriented provider placeholder without making StoreKit
//    a hard runtime requirement yet.
//
//  Purpose:
//  - Keep the source of premium entitlement separate from:
//    - trial logic
//    - capability logic
//    - UI / routing
//    - SettingsModel
//
//  System Role:
//  - This file answers only one question:
//    "Where does the premium entitlement input come from?"
//  - It does NOT resolve the final app status (premium / trial / free).
//  - It does NOT decide which screens or tabs are unlocked.
//  - It does NOT own paywall UI.
//
//  Current Project Phase:
//  - GluVib is still in TestFlight / product iteration.
//  - Therefore, the active provider is currently expected to be test-oriented.
//  - StoreKit support is prepared structurally, but not forced yet.
//

import Foundation

// ============================================================
// MARK: - Entitlement Provider Protocol
// ============================================================

/// Common source abstraction for premium entitlement input.
///
/// Important:
/// - Providers only describe premium-side input.
/// - Trial remains app-owned logic and is resolved later by the monetization manager.
protocol EntitlementProvider: Sendable {
    var source: MonetizationSource { get }

    /// Returns the current premium entitlement snapshot from this source.
    func currentSnapshot() async -> ProviderEntitlementSnapshot
}

// ============================================================
// MARK: - Provider Configuration
// ============================================================

/// Internal source selection for the current app build / runtime phase.
///
/// This is NOT intended to be exposed as a user-facing toggle in App Status.
enum MonetizationProviderMode: String, Codable, Equatable, Sendable {
    case test
    case storeKit
}

/// Central internal configuration for selecting the currently active
/// entitlement provider.
///
/// Current recommendation:
/// - keep `.test` active during the current TestFlight / feedback phase
/// - switch to `.storeKit` later when the StoreKit flow is actually introduced
enum MonetizationProviderConfig {

    /// Active entitlement source mode for the app.
    ///
    /// During the current phase, this should intentionally stay on `.test`.
    static let activeMode: MonetizationProviderMode = .test

    /// Creates the currently active provider instance.
    static func makeProvider() -> EntitlementProvider {
        switch activeMode {
        case .test:
            return TestEntitlementProvider()
        case .storeKit:
            return StoreKitEntitlementProvider()
        }
    }
}

// ============================================================
// MARK: - Test Entitlement Provider
// ============================================================

/// Current premium input source for the TestFlight / prototype phase.
///
/// Transitional responsibility:
/// - reads the temporary internal premium simulation state
/// - reports it in a normalized provider snapshot
///
/// Important architectural note:
/// - This provider is transitional infrastructure.
/// - It is allowed to read the current temporary premium flag from SettingsModel
///   during the migration phase.
/// - The rest of the app should NOT read that flag directly anymore once the
///   monetization manager is wired in.
struct TestEntitlementProvider: EntitlementProvider {

    let source: MonetizationSource = .test

    func currentSnapshot() async -> ProviderEntitlementSnapshot {
        let settings = await MainActor.run { SettingsModel.shared }

        let hasActivePremium = await MainActor.run {
            settings.isPremiumEnabled
        }

        return ProviderEntitlementSnapshot(
            source: source,
            hasActivePremium: hasActivePremium,
            subscriptionPlan: hasActivePremium ? .unknown : .none
        )
    }
}

// ============================================================
// MARK: - StoreKit Entitlement Provider
// ============================================================

/// Prepared premium input source for the later StoreKit 2 phase.
///
/// Current state:
/// - structural placeholder only
/// - intentionally returns "no active premium" until StoreKit is wired in
///
/// This keeps the architecture ready without making StoreKit a hard dependency
/// during the ongoing TestFlight product iteration phase.
struct StoreKitEntitlementProvider: EntitlementProvider {

    let source: MonetizationSource = .storeKit

    func currentSnapshot() async -> ProviderEntitlementSnapshot {
        ProviderEntitlementSnapshot(
            source: source,
            hasActivePremium: false,
            subscriptionPlan: .none
        )
    }
}
