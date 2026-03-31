//
//  MonetizationModels.swift
//  GluVib
//
//  Area: App / Monetization
//  File Role:
//  - Defines the shared base types for the GluVib monetization layer.
//  - These models are the common language between provider, manager,
//    capability, debug, and UI layers.
//
//  Purpose:
//  - Keep monetization-specific enums and lightweight value types in one place.
//  - Separate commercial status language from UI, routing, SettingsModel,
//    and StoreKit implementation details.
//
//  System Role:
//  - This file does NOT fetch products.
//  - This file does NOT evaluate HealthKit data.
//  - This file does NOT perform routing.
//  - This file only defines the core monetization model types.
//
//  Key Architecture Rule:
//  - Trial / Premium / Free are modeled centrally here,
//    so other files do not invent their own competing status types.
//

import Foundation

// ============================================================
// MARK: - Monetization Source
// ============================================================

/// Defines where the premium entitlement information currently comes from.
///
/// This is important for the current transition phase:
/// - `.test` supports the internal TestFlight / prototype setup
/// - `.storeKit` is the later production-oriented source
enum MonetizationSource: String, Codable, Equatable, Sendable {
    case test
    case storeKit
}

// ============================================================
// MARK: - Subscription Plan
// ============================================================

/// Represents the premium subscription plan shape.
///
/// Note:
/// - `none` is used when no active subscription exists.
/// - `unknown` is useful during loading / transition states.
enum SubscriptionPlan: String, Codable, Equatable, Sendable {
    case none
    case monthly
    case yearly
    case unknown
}

// ============================================================
// MARK: - Entitlement Status
// ============================================================

/// The single commercial truth of the app.
///
/// This is the central monetization status that the rest of the app
/// should consume instead of calculating premium / trial / free locally.
enum EntitlementStatus: Equatable, Sendable {
    case premium(plan: SubscriptionPlan)
    case trial(daysRemaining: Int)
    case free

    // ========================================================
    // MARK: - Convenience Flags
    // ========================================================

    var isPremium: Bool {
        if case .premium = self { return true }
        return false
    }

    var isTrial: Bool {
        if case .trial = self { return true }
        return false
    }

    var isFree: Bool {
        if case .free = self { return true }
        return false
    }

    /// Full app access means:
    /// - active premium
    /// - or active trial
    ///
    /// In GluVib, both states unlock the full app.
    var hasFullAppAccess: Bool {
        switch self {
        case .premium, .trial:
            return true
        case .free:
            return false
        }
    }

    /// Metabolic access follows the same rule in the current product model:
    /// available only during premium or trial.
    var canAccessMetabolic: Bool {
        hasFullAppAccess
    }

    var trialDaysRemaining: Int? {
        guard case .trial(let daysRemaining) = self else { return nil }
        return daysRemaining
    }

    var subscriptionPlan: SubscriptionPlan {
        guard case .premium(let plan) = self else { return .none }
        return plan
    }
}

// ============================================================
// MARK: - Locked Feature
// ============================================================

/// Describes which app area is blocked by monetization.
///
/// This is useful later for:
/// - fallback decisions
/// - paywall context
/// - upgrade messaging
/// - analytics / logging
enum LockedFeature: Equatable, Sendable {
    case premiumHome
    case metabolicDomain
    case metabolicMetric
    case activityMetric
    case bodyMetric
    case nutritionMetric
    case historyFeature
}

// ============================================================
// MARK: - Access Decision
// ============================================================

/// Result type for monetization / capability checks.
///
/// This avoids spreading loose Bool checks throughout routing and UI code.
enum AccessDecision: Equatable, Sendable {
    case allowed
    case blocked(feature: LockedFeature)
}

// ============================================================
// MARK: - Provider Snapshot
// ============================================================

/// Lightweight provider output before trial logic is merged in.
///
/// The entitlement provider should only describe the premium-side input.
/// Trial remains app-owned logic and is resolved later by the monetization manager.
struct ProviderEntitlementSnapshot: Equatable, Sendable {
    let source: MonetizationSource
    let hasActivePremium: Bool
    let subscriptionPlan: SubscriptionPlan

    static let emptyTestSnapshot = ProviderEntitlementSnapshot(
        source: .test,
        hasActivePremium: false,
        subscriptionPlan: .none
    )
}

// ============================================================
// MARK: - Capability Inputs
// ============================================================

/// Compact input bundle for the capability layer.
///
/// This keeps the capability resolver independent from SettingsModel,
/// AppState, or UI-specific files.
struct MonetizationCapabilityContext: Equatable, Sendable {
    let entitlementStatus: EntitlementStatus
}

// ============================================================
// MARK: - Free Tier Lead Metrics
// ============================================================

/// Defines the single free metric per lifestyle domain in free mode.
///
/// Product rule:
/// - Body, Activity, and Nutrition remain partially visible in free mode.
/// - Each of these domains exposes one lead metric.
/// - Metabolic remains fully locked.
enum FreeLeadMetric: Equatable, Sendable {
    case steps
    case weight
    case carbs
}
