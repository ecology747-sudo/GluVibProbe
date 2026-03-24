//
//  HealthStore+AuthorizationV1.swift
//  GluVibProbe
//
//  HealthStore Extension V1 — Authorization
//
//  Purpose
//  - Defines the central authorization scope model.
//  - Defines the requested Apple Health read types.
//  - Owns the authorization request entry points for sync and async flows.
//
//  Data Flow (SSoT)
//  Apple Health → HealthStore (SSoT) → requested read types / authorization entry points
//
//  Key Connections
//  - HealthStore: single source of truth for authorization request logic.
//  - SettingsModel: controls capability-aware authorization scope selection.
//
//  Important
//  - This file does NOT drive badge logic.
//  - Badge / permission-warning behavior is handled metrically via read probes
//    + bootstrap-resolved gates in the active HealthStore V1 flow.
//

import Foundation
import HealthKit
import OSLog // 🟨 UPDATED

extension HealthStore {

    // ============================================================
    // MARK: - Authorization Scope
    // ============================================================

    enum AuthorizationScopeV1 {
        case baseOnly
        case basePlusCGM
        case basePlusCGMPlusInsulin
    }

    // ============================================================
    // MARK: - Requested Read Types
    // Single source of truth for requested read types
    // ============================================================

    func readTypesV1(for scope: AuthorizationScopeV1) -> Set<HKObjectType> {

        guard
            let stepType             = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType     = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let restingEnergyType    = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
            let exerciseMinutesType  = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            let moveTimeType         = HKQuantityType.quantityType(forIdentifier: .appleMoveTime),
            let standTimeType        = HKQuantityType.quantityType(forIdentifier: .appleStandTime),
            let sleepType            = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType           = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            let bodyFatType          = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
            let bmiType              = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex),
            let carbsType            = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            let sugarType            = HKQuantityType.quantityType(forIdentifier: .dietarySugar),
            let proteinType          = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            let fatType              = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            let nutritionEnergyType  = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else {
            return []
        }

        let workoutType = HKObjectType.workoutType()

        var out: Set<HKObjectType> = [
            stepType,
            activeEnergyType,
            restingEnergyType,
            exerciseMinutesType,
            moveTimeType,
            standTimeType,
            sleepType,
            weightType,
            restingHeartRateType,
            bodyFatType,
            bmiType,
            carbsType,
            sugarType,
            proteinType,
            fatType,
            nutritionEnergyType,
            workoutType
        ]

        switch scope {
        case .baseOnly:
            break

        case .basePlusCGM:
            if let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) {
                out.insert(bloodGlucoseType)
            }

        case .basePlusCGMPlusInsulin:
            if let bloodGlucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) {
                out.insert(bloodGlucoseType)
            }
            if let insulinDeliveryType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery) {
                out.insert(insulinDeliveryType)
            }
        }

        return out
    }

    // ============================================================
    // MARK: - Authorization Requests
    // ============================================================

    func requestAuthorization(settings: SettingsModel) {
        if isPreview {
            GluLog.permissions.debug("Authorization request skipped | preview=true") // 🟨 UPDATED
            return
        }

        let scope: AuthorizationScopeV1
        if settings.hasCGM == false {
            scope = .baseOnly
        } else if settings.isInsulinTreated {
            scope = .basePlusCGMPlusInsulin
        } else {
            scope = .basePlusCGM
        }

        let readSet = readTypesV1(for: scope)
        guard readSet.isEmpty == false else {
            GluLog.permissions.error("Authorization request skipped | readSetEmpty=true")
            return
        }

        GluLog.permissions.notice(
            "Authorization request started | scope=\(String(describing: scope), privacy: .public) readTypes=\(readSet.count, privacy: .public)"
        )

        healthStore.requestAuthorization(toShare: [], read: readSet) { success, error in
            if let error {
                GluLog.permissions.error(
                    "Authorization request finished | success=\(success, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                return
            }

            GluLog.permissions.notice(
                "Authorization request finished | success=\(success, privacy: .public)"
            )
        }
    }

    func requestAuthorizationV1Async(settings: SettingsModel) async {
        if isPreview {
            GluLog.permissions.debug("Authorization async request skipped | preview=true") // 🟨 UPDATED
            return
        }

        let scope: AuthorizationScopeV1
        if settings.hasCGM == false {
            scope = .baseOnly
        } else if settings.isInsulinTreated {
            scope = .basePlusCGMPlusInsulin
        } else {
            scope = .basePlusCGM
        }

        let readSet = readTypesV1(for: scope)
        guard readSet.isEmpty == false else {
            GluLog.permissions.error("Authorization async request skipped | readSetEmpty=true")
            return
        }

        GluLog.permissions.notice(
            "Authorization async request started | scope=\(String(describing: scope), privacy: .public) readTypes=\(readSet.count, privacy: .public)"
        )

        await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readSet) { success, error in
                if let error {
                    GluLog.permissions.error(
                        "Authorization async request finished | success=\(success, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                    )
                } else {
                    GluLog.permissions.notice(
                        "Authorization async request finished | success=\(success, privacy: .public)"
                    )
                }

                continuation.resume()
            }
        }
    }
}
