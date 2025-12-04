//
//  SettingsView.swift
//  GluVibProbe
//

import SwiftUI

// Snapshot aller relevanten @State-Werte, um nur EINE onChange-Quelle zu haben
private struct SettingsSnapshot: Equatable {
    var gender: String
    var birthDate: Date
    var height: Int
    var weightKg: Int
    var targetWeight: Int
    var dailySleepGoalMinutes: Int   // 🔹 neu

    var glucoseUnit: GlucoseUnit
    var weightUnit: WeightUnit
    var heightUnit: HeightUnit
    var energyUnit: EnergyUnit
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
    /// 🔹 NEU: Resting Energy
    var restingEnergy: Int
}

struct SettingsView: View {

    // Zentrales Settings-Modell
    @ObservedObject private var settings = SettingsModel.shared

    // MARK: - Body / Personal

    @State private var gender: String = "Male"
    @State private var birthDate: Date = Date()
    @State private var height: Int = 170
    @State private var weightKg: Int = 75
    @State private var targetWeight: Int = 75
    @State private var dailySleepGoalMinutes: Int = 8 * 60    // 🔹 neu

    // MARK: - Units

    @State private var glucoseUnit: GlucoseUnit = .mgdL
    @State private var weightUnit: WeightUnit = .kg
    @State private var heightUnit: HeightUnit = .cm
    @State private var energyUnit: EnergyUnit = .kcal
    @State private var distanceUnit: DistanceUnit = .kilometers

    // MARK: - Activity

    @State private var dailyStepTarget: Int = 10_000

    // MARK: - Metabolic

    @State private var glucoseMin: Int = 70
    @State private var glucoseMax: Int = 180
    @State private var veryLowLimit: Int = 55
    @State private var veryHighLimit: Int = 250

    // MARK: - Nutrition

    @State private var dailyCarbs: Int = 200
    @State private var dailyProtein: Int = 80
    @State private var dailyCalories: Int = 2500
    @State private var dailyFat: Int = 70
    /// 🔹 NEU: Resting Energy (kcal)
    @State private var restingEnergy: Int = 1800

    // MARK: - Aktive Domain

    @State private var selectedDomain: SettingsDomain = .body

    // MARK: - Save Button State

    @State private var saveButtonState: SettingsSaveButtonState = .idle

    /// True, sobald die initialen Werte aus SettingsModel in die @State-Variablen geladen wurden.
    @State private var didInitialLoad: Bool = false

    /// Flag, um während Undo/Initial-Load das Unsaved-Tracking auszusetzen
    @State private var suspendUnsavedTracking: Bool = false

    /// Lokales Flag für die Button-Bar, damit Cancel sofort verschwindet
    @State private var localHasUnsavedChanges: Bool = false

    // MARK: - Snapshot für onChange

    private var snapshot: SettingsSnapshot {
        SettingsSnapshot(
            gender: gender,
            birthDate: birthDate,
            height: height,
            weightKg: weightKg,
            targetWeight: targetWeight,
            dailySleepGoalMinutes: dailySleepGoalMinutes,  // 🔹 neu
            glucoseUnit: glucoseUnit,
            weightUnit: weightUnit,
            heightUnit: heightUnit,
            energyUnit: energyUnit,
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
            restingEnergy: restingEnergy         // 🔹 neu
        )
    }

    // MARK: - Umrechnung

    func mgToMmol(_ mg: Int) -> Double {
        Double(mg) / 18.0
    }

    func mmolToMg(_ mmol: Double) -> Int {
        Int((mmol * 18.0).rounded())
    }

    // MARK: - Save / Undo Logik

    /// Schreibt alle aktuellen @State-Werte ins SettingsModel und ruft saveToDefaults().
    private func saveAllSettings() {
        // Steps
        settings.dailyStepGoal = dailyStepTarget

        // Personal / Body
        settings.gender         = gender
        settings.birthDate      = birthDate
        settings.heightCm       = height
        settings.weightKg       = weightKg
        settings.targetWeightKg = targetWeight
        settings.dailySleepGoalMinutes = dailySleepGoalMinutes   // 🔹 neu

        // Units
        settings.weightUnit     = weightUnit
        settings.heightUnit     = heightUnit
        settings.energyUnit     = energyUnit
        settings.distanceUnit   = distanceUnit
        settings.glucoseUnit    = glucoseUnit

        // Metabolic
        settings.glucoseMin    = glucoseMin
        settings.glucoseMax    = glucoseMax
        settings.veryLowLimit  = veryLowLimit
        settings.veryHighLimit = veryHighLimit

        // Nutrition
        settings.dailyCarbs    = dailyCarbs
        settings.dailyProtein  = dailyProtein
        settings.dailyCalories = dailyCalories
        settings.dailyFat      = dailyFat
        settings.restingEnergy = restingEnergy          // 🔹 neu

        // In UserDefaults speichern
        settings.saveToDefaults()
    }

    /// Stellt alle @State-Werte aus dem aktuellen SettingsModel wieder her.
    private func undoChanges() {
        // ⛔ Unsaved-Tracking während des Undo-Vorgangs deaktivieren
        suspendUnsavedTracking = true

        // Steps
        dailyStepTarget = settings.dailyStepGoal

        // Personal / Body
        gender                = settings.gender
        birthDate             = settings.birthDate
        height                = settings.heightCm
        weightKg              = settings.weightKg
        targetWeight          = settings.targetWeightKg
        dailySleepGoalMinutes = settings.dailySleepGoalMinutes   // 🔹 neu

        // Units
        weightUnit   = settings.weightUnit
        heightUnit   = settings.heightUnit
        energyUnit   = settings.energyUnit
        distanceUnit = settings.distanceUnit
        glucoseUnit  = settings.glucoseUnit

        // Metabolic
        glucoseMin    = settings.glucoseMin
        glucoseMax    = settings.glucoseMax
        veryLowLimit  = settings.veryLowLimit
        veryHighLimit = settings.veryHighLimit

        // Nutrition
        dailyCarbs    = settings.dailyCarbs
        dailyProtein  = settings.dailyProtein
        dailyCalories = settings.dailyCalories
        dailyFat      = settings.dailyFat
        restingEnergy = settings.restingEnergy          // 🔹 neu

        // UI- & Model-Flags zurücksetzen
        saveButtonState = .idle
        settings.clearUnsavedChanges()
        localHasUnsavedChanges = false

        // 🔑 Unsaved-Tracking erst NACH dem Snapshot-Update wieder aktivieren
        DispatchQueue.main.async {
            self.suspendUnsavedTracking = false
        }
    }

    // MARK: - Unsaved Helper

    private func markUnsaved() {
        // während Initial-Load oder Undo nichts tracken
        guard didInitialLoad, !suspendUnsavedTracking else { return }

        if saveButtonState == .saved {
            saveButtonState = .idle
        }

        // Globales Flag (für ContentView)
        settings.markUnsavedChanges()

        // Lokales Flag für Button-Bar
        localHasUnsavedChanges = true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // DOMAIN-PICKER
                SettingsDomainPicker(selectedDomain: $selectedDomain)

                // Inhalt pro Domain
                Form {
                    domainSectionView()
                }
                .scrollContentBackground(.hidden)

                // Untere, schwebende Button-Bar
                SettingsButtonBar(
                    saveButtonState: saveButtonState,
                    hasUnsavedChanges: localHasUnsavedChanges,
                    onSaveTapped: handleSaveTapped,
                    onUndoTapped: undoChanges
                )
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Initiales Laden: Tracking aussetzen
            suspendUnsavedTracking = true

            // Steps
            dailyStepTarget = settings.dailyStepGoal

            // Personal / Body
            gender                = settings.gender
            birthDate             = settings.birthDate
            height                = settings.heightCm
            weightKg              = settings.weightKg
            targetWeight          = settings.targetWeightKg
            dailySleepGoalMinutes = settings.dailySleepGoalMinutes   // 🔹 neu

            // Units
            weightUnit   = settings.weightUnit
            heightUnit   = settings.heightUnit
            energyUnit   = settings.energyUnit
            distanceUnit = settings.distanceUnit
            glucoseUnit  = settings.glucoseUnit

            // Metabolic
            glucoseMin    = settings.glucoseMin
            glucoseMax    = settings.glucoseMax
            veryLowLimit  = settings.veryLowLimit
            veryHighLimit = settings.veryHighLimit

            // Nutrition
            dailyCarbs    = settings.dailyCarbs
            dailyProtein  = settings.dailyProtein
            dailyCalories = settings.dailyCalories
            dailyFat      = settings.dailyFat
            restingEnergy = settings.restingEnergy          // 🔹 neu

            DispatchQueue.main.async {
                didInitialLoad = true
                settings.clearUnsavedChanges()
                localHasUnsavedChanges = false
                suspendUnsavedTracking = false
            }
        }
        // Nur eine onChange-Quelle
        .onChange(of: snapshot) { _ in
            markUnsaved()
        }
    }

    // MARK: - Save Button Tap

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

    // MARK: - Domain-Inhalt

    @ViewBuilder
    private func domainSectionView() -> some View {
        switch selectedDomain {
        case .body:
            BodySettingsSection(
                gender: $gender,
                birthDate: $birthDate,
                heightCm: $height,
                weightKg: $weightKg,
                targetWeightKg: $targetWeight,
                dailySleepGoalMinutes: $dailySleepGoalMinutes,
                heightUnit: heightUnit,
                weightUnit: weightUnit
            )

        case .activity:
            ActivitySettingsSection(
                dailyStepTarget: $dailyStepTarget
            )

        case .metabolic:
            MetabolicSettingsSection(
                glucoseUnit:   $glucoseUnit,
                glucoseMin:    $glucoseMin,
                glucoseMax:    $glucoseMax,
                veryLowLimit:  $veryLowLimit,
                veryHighLimit: $veryHighLimit
            )

        case .nutrition:
            NutritionSettingsSection(
                dailyCarbs:    $dailyCarbs,
                dailyProtein:  $dailyProtein,
                dailyFat:      $dailyFat,
                dailyCalories: $dailyCalories,
                restingEnergy: $restingEnergy      // 🔹 NEU: hier einhängen
            )

        case .units:
            UnitsSettingsSection(
                glucoseUnit:  $glucoseUnit,
                distanceUnit: $distanceUnit,
                weightUnit:   $weightUnit,
                heightUnit:   $heightUnit,
                energyUnit:   $energyUnit
            )
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthStore.preview())
}
