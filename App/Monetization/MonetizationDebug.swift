//
//  MonetizationDebug.swift
//  GluVib
//
//  Area: App / Monetization
//  File Role:
//  - Holds internal-only helpers for the current GluVib monetization transition phase.
//  - Keeps temporary test / debug support out of the main entitlement,
//    provider, and capability files.
//
//  Purpose:
//  - Support the current TestFlight / iteration phase without polluting
//    user-facing product logic.
//  - Provide one explicit place for temporary internal monetization helpers.
//  - Keep future cleanup straightforward once real StoreKit-driven production
//    monetization is fully active.
//
//  System Role:
//  - This file is NOT user-facing UI.
//  - This file does NOT define the final premium / trial / free truth.
//  - This file does NOT replace StoreKit.
//  - This file only contains internal transition helpers.
//
//  Localization Note:
//  - This file intentionally contains no user-facing strings.
//  - Therefore it does not bypass the existing EN / DE localization structure.
//

import Foundation

// ============================================================
// MARK: - Debug Flags
// ============================================================

/// Internal monetization debug flags used during the current transition phase.
///
/// Important:
/// - These flags are for internal development / migration support.
/// - They must not be surfaced as normal user-facing App Status controls.
/// - They are intentionally centralized here so temporary behavior stays easy
///   to find and remove later.
enum MonetizationDebug {

    /// Global internal switch for temporary monetization debug support.
    ///
    /// Recommendation for the current phase:
    /// - keep `true` while the app is still migrating away from the old
    ///   SettingsModel-based premium simulation
    /// - set to `false` once the migration is complete
    static let isInternalDebugSupportEnabled: Bool = true

    /// Controls whether the test entitlement provider is currently allowed
    /// to consume the temporary legacy premium flag from `SettingsModel`.
    ///
    /// This keeps the current TestFlight setup working while the new
    /// monetization architecture is introduced step by step.
    static let allowLegacySettingsPremiumBridge: Bool = true

    /// Controls whether internal monetization debug logging should be allowed.
    ///
    /// This file does not depend on any logging system yet; the flag exists
    /// so later integration can stay centralized.
    static let allowDebugLogging: Bool = true
}

// ============================================================
// MARK: - Legacy Migration Rules
// ============================================================

/// Centralized helper rules for the ongoing migration from legacy
/// monetization state to the new dedicated monetization layer.
///
/// Keeping these rules in one place avoids scattering transition checks
/// across provider / manager / UI files.
enum MonetizationLegacyBridge {

    /// Returns whether the temporary legacy premium state may still be read
    /// from `SettingsModel` during the current migration phase.
    static var mayReadLegacyPremiumFlag: Bool {
        MonetizationDebug.isInternalDebugSupportEnabled &&
        MonetizationDebug.allowLegacySettingsPremiumBridge
    }
}

// ============================================================
// MARK: - Debug Snapshot
// ============================================================

/// Lightweight internal snapshot for inspecting the current monetization
/// transition state while wiring the new architecture.
///
/// This type is intentionally developer-facing only.
struct MonetizationDebugSnapshot: Equatable, Sendable {
    let debugSupportEnabled: Bool
    let legacySettingsPremiumBridgeEnabled: Bool
    let activeProviderMode: MonetizationProviderMode
}

// ============================================================
// MARK: - Debug Snapshot Factory
// ============================================================

enum MonetizationDebugFactory {

    /// Builds a compact internal snapshot of the current monetization
    /// transition configuration.
    static func makeSnapshot() -> MonetizationDebugSnapshot {
        MonetizationDebugSnapshot(
            debugSupportEnabled: MonetizationDebug.isInternalDebugSupportEnabled,
            legacySettingsPremiumBridgeEnabled: MonetizationLegacyBridge.mayReadLegacyPremiumFlag,
            activeProviderMode: MonetizationProviderConfig.activeMode
        )
    }
}
