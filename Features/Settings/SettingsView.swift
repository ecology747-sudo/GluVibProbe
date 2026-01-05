//
//  SettingsView.swift
//  GluVibProbe
//

import SwiftUI

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

    // !!! NEW
    var tirTargetPercent: Int
}

struct SettingsView: View {

    @ObservedObject private var settings = SettingsModel.shared

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

    // !!! NEW
    @State private var tirTargetPercent: Int = 70

    @State private var selectedDomain: SettingsDomain

    init(startDomain: SettingsDomain = .body) {
        _selectedDomain = State(initialValue: startDomain)
    }

    @State private var saveButtonState: SettingsSaveButtonState = .idle
    @State private var didInitialLoad: Bool = false
    @State private var suspendUnsavedTracking: Bool = false
    @State private var localHasUnsavedChanges: Bool = false

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

            tirTargetPercent: tirTargetPercent // !!! NEW
        )
    }

    private func saveAllSettings() {
        settings.dailyStepGoal = dailyStepTarget

        settings.targetWeightKg = targetWeight
        settings.dailySleepGoalMinutes = dailySleepGoalMinutes

        settings.weightUnit   = weightUnit
        settings.distanceUnit = distanceUnit
        settings.glucoseUnit  = glucoseUnit

        settings.isInsulinTreated = isInsulinTreated
        settings.hasCGM = hasCGM

        settings.glucoseMin    = glucoseMin
        settings.glucoseMax    = glucoseMax
        settings.veryLowLimit  = veryLowLimit
        settings.veryHighLimit = veryHighLimit

        settings.hba1cEntries = hba1cEntries

        settings.dailyCarbs    = dailyCarbs
        settings.dailyProtein  = dailyProtein
        settings.dailyCalories = dailyCalories
        settings.dailyFat      = dailyFat

        // !!! NEW
        settings.tirTargetPercent = tirTargetPercent

        settings.saveToDefaults()
    }

    private func undoChanges() {
        suspendUnsavedTracking = true

        dailyStepTarget = settings.dailyStepGoal

        targetWeight = settings.targetWeightKg
        dailySleepGoalMinutes = settings.dailySleepGoalMinutes

        weightUnit   = settings.weightUnit
        distanceUnit = settings.distanceUnit
        glucoseUnit  = settings.glucoseUnit

        isInsulinTreated = settings.isInsulinTreated
        hasCGM = settings.hasCGM

        glucoseMin    = settings.glucoseMin
        glucoseMax    = settings.glucoseMax
        veryLowLimit  = settings.veryLowLimit
        veryHighLimit = settings.veryHighLimit

        hba1cEntries  = settings.hba1cEntries

        dailyCarbs    = settings.dailyCarbs
        dailyProtein  = settings.dailyProtein
        dailyCalories = settings.dailyCalories
        dailyFat      = settings.dailyFat

        // !!! NEW
        tirTargetPercent = settings.tirTargetPercent

        saveButtonState = .idle
        settings.clearUnsavedChanges()
        localHasUnsavedChanges = false

        DispatchQueue.main.async {
            self.suspendUnsavedTracking = false
        }
    }

    private func markUnsaved() {
        guard didInitialLoad, !suspendUnsavedTracking else { return }

        if saveButtonState == .saved {
            saveButtonState = .idle
        }

        settings.markUnsavedChanges()
        localHasUnsavedChanges = true
    }

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Settings",
            headerTint: Color.Glu.primaryBlue,
            onBack: nil,
            onRefresh: nil,
            background: {
                // !!! UPDATED: neutraler Settings-Background (GluSoftGray + dezenter Gradient)
                ZStack {
                    Color("GluSoftGray")
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.black.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.softLight)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {

                    // ✅ Chips bleiben (oben wie Metric-Seite)
                    SettingsDomainPicker(selectedDomain: $selectedDomain)

                    // !!! UPDATED: Domain-Inhalt DIREKT, ohne extra Außenrahmen/Title
                    domainSectionView()

                    // !!! UPDATED: ButtonBar ohne extra Card-Rahmen (kein doppeltes Framing)
                    SettingsButtonBar(
                        saveButtonState: saveButtonState,
                        hasUnsavedChanges: localHasUnsavedChanges,
                        onSaveTapped: handleSaveTapped,
                        onUndoTapped: undoChanges
                    )
                }
            }
        )
        .onAppear {
            suspendUnsavedTracking = true

            dailyStepTarget = settings.dailyStepGoal

            targetWeight = settings.targetWeightKg
            dailySleepGoalMinutes = settings.dailySleepGoalMinutes

            weightUnit   = settings.weightUnit
            distanceUnit = settings.distanceUnit
            glucoseUnit  = settings.glucoseUnit

            isInsulinTreated = settings.isInsulinTreated
            hasCGM = settings.hasCGM

            glucoseMin    = settings.glucoseMin
            glucoseMax    = settings.glucoseMax
            veryLowLimit  = settings.veryLowLimit
            veryHighLimit = settings.veryHighLimit

            hba1cEntries  = settings.hba1cEntries

            dailyCarbs    = settings.dailyCarbs
            dailyProtein  = settings.dailyProtein
            dailyCalories = settings.dailyCalories
            dailyFat      = settings.dailyFat

            // !!! NEW
            tirTargetPercent = settings.tirTargetPercent

            DispatchQueue.main.async {
                didInitialLoad = true
                settings.clearUnsavedChanges()
                localHasUnsavedChanges = false
                suspendUnsavedTracking = false
            }
        }
        .onChange(of: snapshot) { _ in
            markUnsaved()
        }
    }

    private func handleSaveTapped() {
        guard saveButtonState != .saving else { return }

        saveButtonState = .saving
        saveAllSettings()
        localHasUnsavedChanges = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            saveButtonState = .saved

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if saveButtonState == .saved {
                    saveButtonState = .idle
                }
            }
        }
    }

    @ViewBuilder
    private func domainSectionView() -> some View {
        switch selectedDomain {
        case .body:
            BodySettingsSection(
                targetWeightKg: $targetWeight,
                dailySleepGoalMinutes: $dailySleepGoalMinutes
            )

        case .activity:
            ActivitySettingsSection(
                dailyStepTarget: $dailyStepTarget
            )

        case .metabolic:
            MetabolicSettingsSection(
                isInsulinTreated: $isInsulinTreated,
                hasCGM: $hasCGM,
                glucoseUnit:   $glucoseUnit,
                glucoseMin:    $glucoseMin,
                glucoseMax:    $glucoseMax,
                veryLowLimit:  $veryLowLimit,
                veryHighLimit: $veryHighLimit,
                hba1cEntries:  $hba1cEntries,
                tirTargetPercent: $tirTargetPercent // !!! NEW
            )

        case .nutrition:
            NutritionSettingsSection(
                dailyCarbs:    $dailyCarbs,
                dailyProtein:  $dailyProtein,
                dailyFat:      $dailyFat,
                dailyCalories: $dailyCalories
            )

        case .units:
            UnitsSettingsSection(
                glucoseUnit:  $glucoseUnit,
                distanceUnit: $distanceUnit,
                weightUnit:   $weightUnit
            )
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthStore.preview())
}
