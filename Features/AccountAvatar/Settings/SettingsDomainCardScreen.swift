//
//  SettingsDomainCardScreen.swift
//  GluVibProbe
//
//  Level 3 — Generic Domain Screen (Back + Save + Unsaved Guard)
//
//  FIXES (PATCH 5):
//  - REMOVE path-binding navigation (no more Level-jumps / no more popping to Level 1)
//  - Back ALWAYS returns to Level 2 via injected closure (root NavigationStack controls path)
//  - Unsaved guard cannot be bypassed (swipe-back disabled)
//  - Save logic remains generic for all domains
//

import SwiftUI
import UIKit

// ============================================================
// MARK: - Snapshot (for unsaved detection)
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
    var dailyProtein: Int
    var dailyCalories: Int
    var dailyFat: Int

    var hba1cEntries: [HbA1cEntry]

    var isInsulinTreated: Bool
    var hasCGM: Bool

    var tirTargetPercent: Int
    var gmi90TargetPercent: Double
    var cvTargetPercent: Int
}

// ============================================================
// MARK: - Screen
// ============================================================

struct SettingsDomainCardScreen: View {

    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.dismiss) private var dismiss

    let domain: SettingsDomain

    // UPDATED: Root (AccountSheetRootView) controls nav path.
    // Level 3 requests "go back to Level 2" via this closure.
    let onBackToSettingsHome: () -> Void

    // MARK: - Local State

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
    @State private var dailyProtein: Int = 80
    @State private var dailyCalories: Int = 2500
    @State private var dailyFat: Int = 70

    @State private var tirTargetPercent: Int = 70
    @State private var gmi90TargetPercent: Double = 7.0
    @State private var cvTargetPercent: Int = 36

    // MARK: - Save / Unsaved

    @State private var saveButtonState: SettingsSaveButtonState = .idle
    @State private var initialSnapshot: SettingsSnapshot? = nil
    @State private var showUnsavedDialog: Bool = false

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
            dailyProtein: dailyProtein,
            dailyCalories: dailyCalories,
            dailyFat: dailyFat,
            hba1cEntries: hba1cEntries,
            isInsulinTreated: isInsulinTreated,
            hasCGM: hasCGM,
            tirTargetPercent: tirTargetPercent,
            gmi90TargetPercent: gmi90TargetPercent,
            cvTargetPercent: cvTargetPercent
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return snapshot != initialSnapshot
    }

    // MARK: - Load / Save

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
        dailyProtein = settings.dailyProtein
        dailyCalories = settings.dailyCalories
        dailyFat = settings.dailyFat

        tirTargetPercent = settings.tirTargetPercent
        gmi90TargetPercent = settings.gmi90TargetPercent
        cvTargetPercent = settings.cvTargetPercent

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
        settings.dailyProtein = dailyProtein
        settings.dailyCalories = dailyCalories
        settings.dailyFat = dailyFat

        settings.tirTargetPercent = tirTargetPercent
        settings.gmi90TargetPercent = gmi90TargetPercent
        settings.cvTargetPercent = cvTargetPercent

        settings.saveToDefaults()

        initialSnapshot = snapshot
        settings.clearUnsavedChanges()
    }

    // MARK: - Navigation helpers (ONE LEVEL only)

    private func popOneLevel() {
        onBackToSettingsHome()
    }

    // MARK: - Actions

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

    // MARK: - UI

    var body: some View {
        ZStack {
            Color("GluSoftGray").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    Text(domainTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.Glu.primaryBlue)
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
                .foregroundStyle(Color.Glu.primaryBlue)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(saveButtonText) { handleSave() }
                    .font(.callout.weight(.semibold))
                    .disabled(!hasUnsavedChanges || saveButtonState == .saving)
                    .foregroundStyle(Color.Glu.primaryBlue)
            }
        }
        .tint(Color.Glu.primaryBlue)
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
            "Unsaved Changes",
            isPresented: $showUnsavedDialog,
            titleVisibility: .visible
        ) {
            Button("Save") {
                handleSave()
                popOneLevel()
            }
            Button("Discard Changes", role: .destructive) {
                discardAndLeave()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Save before leaving?")
        }
    }

    // MARK: - Content

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
                cvTargetPercent: $cvTargetPercent
            )

        case .body:
            BodySettingsSection(
                targetWeightKg: $targetWeight,
                dailySleepGoalMinutes: $dailySleepGoalMinutes
            )

        case .nutrition:
            NutritionSettingsSection(
                dailyCarbs: $dailyCarbs,
                dailyProtein: $dailyProtein,
                dailyFat: $dailyFat,            // ✅ Reihenfolge korrigiert
                dailyCalories: $dailyCalories   // ✅
            )        }
    }

    private var domainTitle: String {
        switch domain {
        case .units:     return "Units"
        case .metabolic: return "Metabolic"
        case .body:      return "Body"
        case .activity:  return "Activity"
        case .nutrition: return "Nutrition"
        }
    }

    private var saveButtonText: String {
        switch saveButtonState {
        case .idle:   return "Save"
        case .saving: return "Saving…"
        case .saved:  return "Saved"
        }
    }
}

// ============================================================
// MARK: - Disable Interactive Swipe-Back (so unsaved guard cannot be bypassed)
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
