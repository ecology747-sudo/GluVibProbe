//
//  SettingsDomainCardScreen.swift
//  GluVibProbe
//
//  Settings — Domain Detail Screen
//  Purpose:
//  - Renders one domain-specific settings screen (Units / Activity / Body / Nutrition / Metabolic).
//  - Holds local editable state, compares it against an initial snapshot, and saves changes back to SettingsModel.
//
//  Data Flow (SSoT):
//  - SettingsModel (SSoT) -> local @State editing snapshot -> save back to SettingsModel -> persisted defaults
//
//  Key Connections:
//  - SettingsModel.shared
//  - SettingsDomain
//  - Domain section views
//  - Unsaved-changes guard
//

import SwiftUI
import UIKit

// ============================================================
// MARK: - Snapshot Model
// ============================================================

private struct SettingsSnapshot: Equatable {

    var targetWeight: Int
    var dailySleepGoalMinutes: Int

    var glucoseUnit: GlucoseUnit
    var weightUnit: WeightUnit
    var distanceUnit: DistanceUnit

    var dailyStepTarget: Int

    var glucoseMin: Int
    var glucoseMax: Int
    var veryLowLimit: Int
    var veryHighLimit: Int

    var dailyCarbs: Int
    var dailySugar: Int
    var dailyProtein: Int
    var dailyCalories: Int
    var dailyFat: Int

    var hba1cEntries: [HbA1cEntry]

    var isInsulinTreated: Bool
    var hasCGM: Bool

    var tirTargetPercent: Int
    var gmi90TargetPercent: Double
    var cvTargetPercent: Int

    var excludeBolusPriming: Bool
    var bolusPrimingThresholdU: Double
    var excludeBasalPriming: Bool
    var basalPrimingThresholdU: Double
}

// ============================================================
// MARK: - Settings Domain Card Screen
// ============================================================

struct SettingsDomainCardScreen: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.dismiss) private var dismiss

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let domain: SettingsDomain
    let onBackToSettingsHome: () -> Void

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var targetWeight: Int = 75
    @State private var dailySleepGoalMinutes: Int = 8 * 60

    @State private var glucoseUnit: GlucoseUnit = .mgdL
    @State private var weightUnit: WeightUnit = .kg
    @State private var distanceUnit: DistanceUnit = .kilometers

    @State private var dailyStepTarget: Int = 10_000

    @State private var isInsulinTreated: Bool = false
    @State private var hasCGM: Bool = false

    @State private var glucoseMin: Int = 70
    @State private var glucoseMax: Int = 180
    @State private var veryLowLimit: Int = 55
    @State private var veryHighLimit: Int = 250

    @State private var hba1cEntries: [HbA1cEntry] = []

    @State private var dailyCarbs: Int = 200
    @State private var dailySugar: Int = 50
    @State private var dailyProtein: Int = 80
    @State private var dailyCalories: Int = 2500
    @State private var dailyFat: Int = 70

    @State private var tirTargetPercent: Int = 70
    @State private var gmi90TargetPercent: Double = 7.0
    @State private var cvTargetPercent: Int = 36

    @State private var excludeBolusPriming: Bool = false
    @State private var bolusPrimingThresholdU: Double = 1.0
    @State private var excludeBasalPriming: Bool = false
    @State private var basalPrimingThresholdU: Double = 1.0

    @State private var saveButtonState: SettingsSaveButtonState = .idle
    @State private var initialSnapshot: SettingsSnapshot? = nil
    @State private var showUnsavedDialog: Bool = false

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var snapshot: SettingsSnapshot {
        SettingsSnapshot(
            targetWeight: targetWeight,
            dailySleepGoalMinutes: dailySleepGoalMinutes,
            glucoseUnit: glucoseUnit,
            weightUnit: weightUnit,
            distanceUnit: distanceUnit,
            dailyStepTarget: dailyStepTarget,
            glucoseMin: glucoseMin,
            glucoseMax: glucoseMax,
            veryLowLimit: veryLowLimit,
            veryHighLimit: veryHighLimit,
            dailyCarbs: dailyCarbs,
            dailySugar: dailySugar,
            dailyProtein: dailyProtein,
            dailyCalories: dailyCalories,
            dailyFat: dailyFat,
            hba1cEntries: hba1cEntries,
            isInsulinTreated: isInsulinTreated,
            hasCGM: hasCGM,
            tirTargetPercent: tirTargetPercent,
            gmi90TargetPercent: gmi90TargetPercent,
            cvTargetPercent: cvTargetPercent,
            excludeBolusPriming: excludeBolusPriming,
            bolusPrimingThresholdU: bolusPrimingThresholdU,
            excludeBasalPriming: excludeBasalPriming,
            basalPrimingThresholdU: basalPrimingThresholdU
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    private var domainTitle: String { // 🟨 UPDATED
        switch domain {
        case .units:
            return L10n.Avatar.Menu.units
        case .metabolic:
            return String(
                localized: "Metabolic",
                defaultValue: "Metabolic",
                comment: "Domain title for metabolic settings screen"
            )
        case .body:
            return String(
                localized: "Body",
                defaultValue: "Body",
                comment: "Domain title for body settings screen"
            )
        case .activity:
            return String(
                localized: "Activity",
                defaultValue: "Activity",
                comment: "Domain title for activity settings screen"
            )
        case .nutrition:
            return String(
                localized: "Nutrition",
                defaultValue: "Nutrition",
                comment: "Domain title for nutrition settings screen"
            )
        }
    }

    private var saveButtonText: String { // 🟨 UPDATED
        switch saveButtonState {
        case .idle:
            return String(
                localized: "Save",
                defaultValue: "Save",
                comment: "Save button title in settings domain detail screen"
            )
        case .saving:
            return L10n.Avatar.Common.saving
        case .saved:
            return L10n.Avatar.Common.saved
        }
    }

    // ============================================================
    // MARK: - Lifecycle / Sync
    // ============================================================

    private func loadFromSettings() {
        dailyStepTarget = settings.dailyStepGoal

        targetWeight = settings.targetWeightKg
        dailySleepGoalMinutes = settings.dailySleepGoalMinutes

        weightUnit = settings.weightUnit
        distanceUnit = settings.distanceUnit
        glucoseUnit = settings.glucoseUnit

        isInsulinTreated = settings.isInsulinTreated
        hasCGM = settings.hasCGM

        glucoseMin = settings.glucoseMin
        glucoseMax = settings.glucoseMax
        veryLowLimit = settings.veryLowLimit
        veryHighLimit = settings.veryHighLimit

        hba1cEntries = settings.hba1cEntries

        dailyCarbs = settings.dailyCarbs
        dailySugar = settings.dailySugar
        dailyProtein = settings.dailyProtein
        dailyCalories = settings.dailyCalories
        dailyFat = settings.dailyFat

        tirTargetPercent = settings.tirTargetPercent
        gmi90TargetPercent = settings.gmi90TargetPercent
        cvTargetPercent = settings.cvTargetPercent

        excludeBolusPriming = settings.excludeBolusPriming
        bolusPrimingThresholdU = settings.bolusPrimingThresholdU
        excludeBasalPriming = settings.excludeBasalPriming
        basalPrimingThresholdU = settings.basalPrimingThresholdU

        initialSnapshot = snapshot
        saveButtonState = .idle
        settings.clearUnsavedChanges()
    }

    private func saveAllSettings() {
        settings.dailyStepGoal = dailyStepTarget

        settings.targetWeightKg = targetWeight
        settings.dailySleepGoalMinutes = dailySleepGoalMinutes

        settings.weightUnit = weightUnit
        settings.distanceUnit = distanceUnit
        settings.glucoseUnit = glucoseUnit

        settings.isInsulinTreated = isInsulinTreated
        settings.hasCGM = hasCGM

        settings.glucoseMin = glucoseMin
        settings.glucoseMax = glucoseMax
        settings.veryLowLimit = veryLowLimit
        settings.veryHighLimit = veryHighLimit

        settings.hba1cEntries = hba1cEntries

        settings.dailyCarbs = dailyCarbs
        settings.dailySugar = dailySugar
        settings.dailyProtein = dailyProtein
        settings.dailyCalories = dailyCalories
        settings.dailyFat = dailyFat

        settings.tirTargetPercent = tirTargetPercent
        settings.gmi90TargetPercent = gmi90TargetPercent
        settings.cvTargetPercent = cvTargetPercent

        settings.excludeBolusPriming = excludeBolusPriming
        settings.bolusPrimingThresholdU = bolusPrimingThresholdU
        settings.excludeBasalPriming = excludeBasalPriming
        settings.basalPrimingThresholdU = basalPrimingThresholdU

        settings.saveToDefaults()

        initialSnapshot = snapshot
        settings.clearUnsavedChanges()
    }

    // ============================================================
    // MARK: - Navigation / Actions
    // ============================================================

    private func popOneLevel() {
        onBackToSettingsHome()
    }

    private func requestBack() {
        if hasUnsavedChanges {
            showUnsavedDialog = true
        } else {
            popOneLevel()
        }
    }

    private func handleSave() {
        guard hasUnsavedChanges else { return }

        saveButtonState = .saving
        saveAllSettings()
        saveButtonState = .saved

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            saveButtonState = .idle
        }
    }

    private func discardAndLeave() {
        loadFromSettings()
        popOneLevel()
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        ZStack {
            Color("GluSoftGray").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    Text(domainTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.Glu.systemForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    domainContent()
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(NavigationPopGestureDisabler())
        .toolbar {

            ToolbarItem(placement: .topBarLeading) {
                Button(action: requestBack) {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(Color.Glu.systemForeground)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(saveButtonText) { handleSave() }
                    .font(.callout.weight(.semibold))
                    .disabled(!hasUnsavedChanges || saveButtonState == .saving)
                    .foregroundStyle(Color.Glu.systemForeground)
            }
        }
        .tint(Color.Glu.systemForeground)
        .onAppear {
            if initialSnapshot == nil { loadFromSettings() }
        }
        .onChange(of: snapshot) { _ in
            guard initialSnapshot != nil else { return }
            if hasUnsavedChanges {
                settings.markUnsavedChanges()
            }
        }
        .confirmationDialog(
            String(
                localized: "Unsaved Changes",
                defaultValue: "Unsaved Changes",
                comment: "Confirmation dialog title for unsaved settings changes"
            ),
            isPresented: $showUnsavedDialog,
            titleVisibility: .visible
        ) {
            Button(
                String(
                    localized: "Save",
                    defaultValue: "Save",
                    comment: "Save action in unsaved changes dialog"
                )
            ) {
                handleSave()
                popOneLevel()
            }

            Button(
                String(
                    localized: "Discard Changes",
                    defaultValue: "Discard Changes",
                    comment: "Discard action in unsaved changes dialog"
                ),
                role: .destructive
            ) {
                discardAndLeave()
            }

            Button(
                String(
                    localized: "Keep Editing",
                    defaultValue: "Keep Editing",
                    comment: "Cancel action in unsaved changes dialog"
                ),
                role: .cancel
            ) { }
        } message: {
            Text(
                String(
                    localized: "You have unsaved changes. Save before leaving?",
                    defaultValue: "You have unsaved changes. Save before leaving?",
                    comment: "Unsaved changes dialog message in settings domain detail screen"
                )
            )
        }
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    @ViewBuilder
    private func domainContent() -> some View {
        switch domain {

        case .units:
            UnitsSettingsSection(
                glucoseUnit: $glucoseUnit,
                distanceUnit: $distanceUnit,
                weightUnit: $weightUnit
            )

        case .activity:
            ActivitySettingsSection(
                dailyStepTarget: $dailyStepTarget
            )

        case .metabolic:
            MetabolicSettingsSection(
                isInsulinTreated: $isInsulinTreated,
                hasCGM: $hasCGM,
                glucoseUnit: $glucoseUnit,
                glucoseMin: $glucoseMin,
                glucoseMax: $glucoseMax,
                veryLowLimit: $veryLowLimit,
                veryHighLimit: $veryHighLimit,
                hba1cEntries: $hba1cEntries,
                tirTargetPercent: $tirTargetPercent,
                gmi90TargetPercent: $gmi90TargetPercent,
                cvTargetPercent: $cvTargetPercent,
                excludeBolusPriming: $excludeBolusPriming,
                bolusPrimingThresholdU: $bolusPrimingThresholdU,
                excludeBasalPriming: $excludeBasalPriming,
                basalPrimingThresholdU: $basalPrimingThresholdU
            )

        case .body:
            BodySettingsSection(
                targetWeightKg: $targetWeight,
                dailySleepGoalMinutes: $dailySleepGoalMinutes
            )

        case .nutrition:
            NutritionSettingsSection(
                dailyCarbs: $dailyCarbs,
                dailySugar: $dailySugar,
                dailyProtein: $dailyProtein,
                dailyFat: $dailyFat,
                dailyCalories: $dailyCalories
            )
        }
    }
}

// ============================================================
// MARK: - Swipe-Back Disabler
// ============================================================

private struct NavigationPopGestureDisabler: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    private final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}
