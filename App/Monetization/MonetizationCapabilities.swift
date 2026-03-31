//
//  MonetizationCapabilities.swift
//  GluVib
//
//  Area: App / Monetization
//  File Role:
//  - Defines the product-side access policy for GluVib.
//  - Translates the central commercial app status into concrete app capabilities.
//
//  Purpose:
//  - Keep all monetization-driven visibility / access / routing rules in one place.
//  - Remove scattered unlock decisions from AppState, ContentView, and feature Views.
//  - Express the current GluVib product model clearly:
//
//    Trial:
//    - full app access
//    - all domains and metrics unlocked
//
//    Premium:
//    - full app access
//    - all domains and metrics unlocked
//
//    Free:
//    - Metabolic fully locked
//    - Premium home tab hidden
//    - Activity / Body / Nutrition overviews remain accessible
//    - exactly one free lead metric per lifestyle domain remains accessible
//
//  System Role:
//  - This file does NOT fetch StoreKit products.
//  - This file does NOT decide the premium entitlement source.
//  - This file does NOT render paywalls.
//  - This file only answers:
//    "What is the user allowed to see and open right now?"
//

import Foundation

// ============================================================
// MARK: - App Tabs
// ============================================================

/// App-wide tab identifiers used by the monetization capability layer.
///
/// This type stays independent from UI enums such as `GluTab`,
/// so the capability layer does not depend directly on view files.
enum MonetizationTab: Equatable, Sendable {
    case home
    case activity
    case body
    case nutrition
    case history
}

// ============================================================
// MARK: - App Domains
// ============================================================

/// High-level product domains used by the capability layer.
enum MonetizationDomain: Equatable, Sendable {
    case metabolic
    case activity
    case body
    case nutrition
    case history
}

// ============================================================
// MARK: - App Screens
// ============================================================

/// Monetization-relevant screen identifiers.
///
/// This enum mirrors the current routing reality closely enough to let
/// AppState migrate toward capability-driven access checks.
enum MonetizationScreen: Equatable, Sendable {
    case none

    // Overviews
    case premiumHome
    case metabolicOverview
    case activityOverview
    case bodyOverview
    case nutritionOverview
    case historyOverview

    // Nutrition Metrics
    case carbs
    case carbsDayparts
    case sugar
    case protein
    case fat
    case calories

    // Activity Metrics
    case steps
    case activityEnergy
    case activityExerciseMinutes
    case movementSplit
    case moveTime
    case workoutMinutes

    // Body Metrics
    case weight
    case sleep
    case bmi
    case bodyFat
    case restingHeartRate

    // Metabolic Metrics
    case bolus
    case basal
    case bolusBasalRatio
    case carbsBolusRatio
    case timeInRange
    case gmi
    case range
    case SD
    case CV
    case ig
}

// ============================================================
// MARK: - App Capability Set
// ============================================================

/// Concrete access map derived from the central commercial app status.
///
/// This is the product-facing access result that UI and routing can consume.
struct AppCapabilitySet: Equatable, Sendable {

    // ========================================================
    // MARK: - Global Commercial State
    // ========================================================

    let entitlementStatus: EntitlementStatus

    // ========================================================
    // MARK: - Tabs
    // ========================================================

    let visibleTabs: [MonetizationTab]
    let canSeeHomeTab: Bool

    // ========================================================
    // MARK: - Domain Access
    // ========================================================

    let canAccessMetabolicDomain: Bool
    let canAccessActivityOverview: Bool
    let canAccessBodyOverview: Bool
    let canAccessNutritionOverview: Bool
    let canAccessHistoryOverview: Bool

    // ========================================================
    // MARK: - Free Tier Lead Metrics
    // ========================================================

    let freeActivityLeadMetric: FreeLeadMetric?
    let freeBodyLeadMetric: FreeLeadMetric?
    let freeNutritionLeadMetric: FreeLeadMetric?

    // ========================================================
    // MARK: - Convenience Flags
    // ========================================================

    var hasFullAppAccess: Bool {
        entitlementStatus.hasFullAppAccess
    }
}

// ============================================================
// MARK: - Capability Resolver
// ============================================================

/// Central product policy for GluVib monetization.
///
/// This resolver translates the commercial app status into concrete access rules.
/// The rest of the app should consume these results instead of hardcoding rules
/// in AppState, ContentView, or individual Views.
struct CapabilityResolver {

    // ========================================================
    // MARK: - Public API
    // ========================================================

    func makeCapabilitySet(
        context: MonetizationCapabilityContext
    ) -> AppCapabilitySet {
        switch context.entitlementStatus {

        case .premium, .trial:
            return makeFullAccessCapabilitySet(
                entitlementStatus: context.entitlementStatus
            )

        case .free:
            return makeFreeAccessCapabilitySet(
                entitlementStatus: context.entitlementStatus
            )
        }
    }

    func accessDecision(
        for screen: MonetizationScreen,
        capabilities: AppCapabilitySet
    ) -> AccessDecision {
        switch screen {

        // ----------------------------------------------------
        // Neutral
        // ----------------------------------------------------

        case .none:
            return .allowed

        // ----------------------------------------------------
        // Overviews
        // ----------------------------------------------------

        case .premiumHome:
            return capabilities.canSeeHomeTab
                ? .allowed
                : .blocked(feature: .premiumHome)

        case .metabolicOverview:
            return capabilities.canAccessMetabolicDomain
                ? .allowed
                : .blocked(feature: .metabolicDomain)

        case .activityOverview:
            return capabilities.canAccessActivityOverview
                ? .allowed
                : .blocked(feature: .activityMetric)

        case .bodyOverview:
            return capabilities.canAccessBodyOverview
                ? .allowed
                : .blocked(feature: .bodyMetric)

        case .nutritionOverview:
            return capabilities.canAccessNutritionOverview
                ? .allowed
                : .blocked(feature: .nutritionMetric)

        case .historyOverview:
            return capabilities.canAccessHistoryOverview
                ? .allowed
                : .blocked(feature: .historyFeature)

        // ----------------------------------------------------
        // Nutrition Metrics
        // ----------------------------------------------------

        case .carbs:
            return isAllowedNutritionLeadMetric(.carbs, capabilities: capabilities)
                ? .allowed
                : blockedNutritionMetric(capabilities: capabilities)

        case .carbsDayparts,
             .sugar,
             .protein,
             .fat,
             .calories:
            return capabilities.hasFullAppAccess
                ? .allowed
                : .blocked(feature: .nutritionMetric)

        // ----------------------------------------------------
        // Activity Metrics
        // ----------------------------------------------------

        case .steps:
            return isAllowedActivityLeadMetric(.steps, capabilities: capabilities)
                ? .allowed
                : blockedActivityMetric(capabilities: capabilities)

        case .activityEnergy,
             .activityExerciseMinutes,
             .movementSplit,
             .moveTime,
             .workoutMinutes:
            return capabilities.hasFullAppAccess
                ? .allowed
                : .blocked(feature: .activityMetric)

        // ----------------------------------------------------
        // Body Metrics
        // ----------------------------------------------------

        case .weight:
            return isAllowedBodyLeadMetric(.weight, capabilities: capabilities)
                ? .allowed
                : blockedBodyMetric(capabilities: capabilities)

        case .sleep,
             .bmi,
             .bodyFat,
             .restingHeartRate:
            return capabilities.hasFullAppAccess
                ? .allowed
                : .blocked(feature: .bodyMetric)

        // ----------------------------------------------------
        // Metabolic Metrics
        // ----------------------------------------------------

        case .bolus,
             .basal,
             .bolusBasalRatio,
             .carbsBolusRatio,
             .timeInRange,
             .gmi,
             .range,
             .SD,
             .CV,
             .ig:
            return capabilities.canAccessMetabolicDomain
                ? .allowed
                : .blocked(feature: .metabolicMetric)
        }
    }

    func canOpen(
        screen: MonetizationScreen,
        capabilities: AppCapabilitySet
    ) -> Bool {
        if case .allowed = accessDecision(for: screen, capabilities: capabilities) {
            return true
        }
        return false
    }

    func visibleMetabolicMetrics(
        capabilities: AppCapabilitySet,
        hasCGM: Bool,
        isInsulinTreated: Bool
    ) -> [MonetizationScreen] {
        guard capabilities.canAccessMetabolicDomain else { return [] }

        var result: [MonetizationScreen] = [
            .timeInRange,
            .ig,
            .gmi,
            .SD,
            .CV,
            .range
        ]

        if hasCGM, isInsulinTreated {
            result.insert(contentsOf: [
                .bolus,
                .basal,
                .bolusBasalRatio,
                .carbsBolusRatio
            ], at: 0)
        }

        return result
    }

    // ========================================================
    // MARK: - Private Capability Builders
    // ========================================================

    private func makeFullAccessCapabilitySet(
        entitlementStatus: EntitlementStatus
    ) -> AppCapabilitySet {
        AppCapabilitySet(
            entitlementStatus: entitlementStatus,
            visibleTabs: [.home, .activity, .body, .nutrition, .history],
            canSeeHomeTab: true,
            canAccessMetabolicDomain: true,
            canAccessActivityOverview: true,
            canAccessBodyOverview: true,
            canAccessNutritionOverview: true,
            canAccessHistoryOverview: true,
            freeActivityLeadMetric: .steps,
            freeBodyLeadMetric: .weight,
            freeNutritionLeadMetric: .carbs
        )
    }

    private func makeFreeAccessCapabilitySet(
        entitlementStatus: EntitlementStatus
    ) -> AppCapabilitySet {
        AppCapabilitySet(
            entitlementStatus: entitlementStatus,
            visibleTabs: [.activity, .body, .nutrition, .history],
            canSeeHomeTab: false,
            canAccessMetabolicDomain: false,
            canAccessActivityOverview: true,
            canAccessBodyOverview: true,
            canAccessNutritionOverview: true,
            canAccessHistoryOverview: true,
            freeActivityLeadMetric: .steps,
            freeBodyLeadMetric: .weight,
            freeNutritionLeadMetric: .carbs
        )
    }

    // ========================================================
    // MARK: - Private Access Helpers
    // ========================================================

    private func isAllowedActivityLeadMetric(
        _ metric: FreeLeadMetric,
        capabilities: AppCapabilitySet
    ) -> Bool {
        guard capabilities.canAccessActivityOverview else { return false }
        guard capabilities.hasFullAppAccess == false else { return true }
        return capabilities.freeActivityLeadMetric == metric
    }

    private func isAllowedBodyLeadMetric(
        _ metric: FreeLeadMetric,
        capabilities: AppCapabilitySet
    ) -> Bool {
        guard capabilities.canAccessBodyOverview else { return false }
        guard capabilities.hasFullAppAccess == false else { return true }
        return capabilities.freeBodyLeadMetric == metric
    }

    private func isAllowedNutritionLeadMetric(
        _ metric: FreeLeadMetric,
        capabilities: AppCapabilitySet
    ) -> Bool {
        guard capabilities.canAccessNutritionOverview else { return false }
        guard capabilities.hasFullAppAccess == false else { return true }
        return capabilities.freeNutritionLeadMetric == metric
    }

    private func blockedActivityMetric(
        capabilities: AppCapabilitySet
    ) -> AccessDecision {
        guard capabilities.canAccessActivityOverview else {
            return .blocked(feature: .activityMetric)
        }
        return .blocked(feature: .activityMetric)
    }

    private func blockedBodyMetric(
        capabilities: AppCapabilitySet
    ) -> AccessDecision {
        guard capabilities.canAccessBodyOverview else {
            return .blocked(feature: .bodyMetric)
        }
        return .blocked(feature: .bodyMetric)
    }

    private func blockedNutritionMetric(
        capabilities: AppCapabilitySet
    ) -> AccessDecision {
        guard capabilities.canAccessNutritionOverview else {
            return .blocked(feature: .nutritionMetric)
        }
        return .blocked(feature: .nutritionMetric)
    }
}
