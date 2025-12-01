//
//  SettingsView.swift
//  GluVibProbe
//

import SwiftUI

extension View {
    /// Markiert das SettingsModel als "unsaved", sobald sich `value` ändert.
    func markDirtyOnChange<T>(_ value: T, settings: SettingsModel) -> some View where T: Equatable {
        self.onChange(of: value) { _ in
            settings.markUnsavedChanges()
        }
    }
}

// Snapshot für den zuletzt gespeicherten Settings-Zustand
private struct SettingsSnapshot {
    var gender: String
    var birthDate: Date
    var height: Int
    var weightKg: Int
    var targetWeight: Int

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
}

private enum SettingsDomain: CaseIterable {
    case body
    case activity
    case metabolic
    case nutrition
    case units
    
    var title: String {
        switch self {
        case .body:      return "Body"
        case .activity:  return "Activity"
        case .metabolic: return "Metabolic"
        case .nutrition: return "Nutrition"
        case .units:     return "Units"
        }
    }
    
    var color: Color {
        switch self {
        case .body:      return Color.Glu.bodyAccent
        case .activity:  return Color.Glu.activityAccent
        case .metabolic: return Color.Glu.accentLime
        case .nutrition: return Color.Glu.nutritionAccent
        case .units:     return Color.Glu.primaryBlue
        }
    }
}

struct SettingsView_Archive: View {
    
    // ⬇️ jetzt beobachtetes Modell (wegen hasUnsavedChanges & Undo-Button)
    @ObservedObject private var settings = SettingsModel.shared
    
    // MARK: - Body
    @State private var gender: String = "Male"
    @State private var birthDate: Date = Date()
    @State private var height: Int = 170
    @State private var weightKg: Int = 75
    @State private var targetWeight: Int = 75
    
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
    @State private var hypoLimit: Int = 70
    @State private var hyperLimit: Int = 180
    @State private var veryLowLimit: Int = 55
    @State private var veryHighLimit: Int = 250
    
    // MARK: - Nutrition
    @State private var dailyCarbs: Int = 200
    @State private var dailyProtein: Int = 80
    @State private var dailyCalories: Int = 2500
    @State private var dailyFat: Int = 70
    
    // MARK: - Aktive Domain
    @State private var selectedDomain: SettingsDomain = .body

    // MARK: - Save Button State
    private enum SaveButtonState {
        case idle
        case saving
        case saved
    }

    @State private var saveButtonState: SaveButtonState = .idle

    /// Flag, ob die initialen Werte aus dem SettingsModel schon geladen wurden.
    /// Nur Änderungen *nach* diesem Zeitpunkt zählen als "unsaved changes".
    @State private var didInitialLoad: Bool = false

    /// Flag, ob wir gerade einen Snapshot zurückspielen (Undo),
    /// damit markUnsaved() dabei NICHT feuert.
    @State private var isRestoringSnapshot: Bool = false

    /// Zuletzt gespeicherter Zustand (für "Undo Changes")
    @State private var originalSnapshot: SettingsSnapshot?
    
    // MARK: - Hilfsfunktionen mg/dL <-> mmol/L
    
    var dateRange1920: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 1920
        components.month = 1
        components.day = 1
        return calendar.date(from: components)!
    }
    
    func mgToMmol(_ mg: Int) -> Double {
        Double(mg) / 18.0
    }
    
    func mmolToMg(_ mmol: Double) -> Int {
        Int((mmol * 18.0).rounded())
    }
    
    // MARK: - Anzeige TIR
    var tirMinDisplay: String {
        if glucoseUnit == .mgdL {
            return "\(glucoseMin)"
        } else {
            return String(format: "%.1f", mgToMmol(glucoseMin))
        }
    }
    
    var tirMaxDisplay: String {
        if glucoseUnit == .mgdL {
            return "\(glucoseMax)"
        } else {
            return String(format: "%.1f", mgToMmol(glucoseMax))
        }
    }
    
    // MARK: - Anzeige Very Low / High
    var veryLowDisplay: String {
        if glucoseUnit == .mgdL {
            return "\(veryLowLimit)"
        } else {
            return String(format: "%.1f", mgToMmol(veryLowLimit))
        }
    }
    
    var veryHighDisplay: String {
        if glucoseUnit == .mgdL {
            return "\(veryHighLimit)"
        } else {
            return String(format: "%.1f", mgToMmol(veryHighLimit))
        }
    }
    
    var veryLowLineText: String {
        if glucoseUnit == .mgdL {
            return "< \(veryLowLimit) \(glucoseUnit.label)"
        } else {
            return String(format: "< %.1f %@", mgToMmol(veryLowLimit), glucoseUnit.label)
        }
    }
    
    var veryHighLineText: String {
        if glucoseUnit == .mgdL {
            return "> \(veryHighLimit) \(glucoseUnit.label)"
        } else {
            return String(format: "> %.1f %@", mgToMmol(veryHighLimit), glucoseUnit.label)
        }
    }

    // MARK: - Snapshot Helpers

    private func makeSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            gender: gender,
            birthDate: birthDate,
            height: height,
            weightKg: weightKg,
            targetWeight: targetWeight,
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
            dailyFat: dailyFat
        )
    }

    private func restoreFromSnapshot() {
        guard let snapshot = originalSnapshot else { return }

        isRestoringSnapshot = true
        defer { isRestoringSnapshot = false }

        // BODY
        gender       = snapshot.gender
        birthDate    = snapshot.birthDate
        height       = snapshot.height
        weightKg     = snapshot.weightKg
        targetWeight = snapshot.targetWeight

        // UNITS
        glucoseUnit  = snapshot.glucoseUnit
        weightUnit   = snapshot.weightUnit
        heightUnit   = snapshot.heightUnit
        energyUnit   = snapshot.energyUnit
        distanceUnit = snapshot.distanceUnit

        // ACTIVITY
        dailyStepTarget = snapshot.dailyStepTarget

        // METABOLIC
        glucoseMin    = snapshot.glucoseMin
        glucoseMax    = snapshot.glucoseMax
        veryLowLimit  = snapshot.veryLowLimit
        veryHighLimit = snapshot.veryHighLimit

        // NUTRITION
        dailyCarbs    = snapshot.dailyCarbs
        dailyProtein  = snapshot.dailyProtein
        dailyCalories = snapshot.dailyCalories
        dailyFat      = snapshot.dailyFat

        saveButtonState = .idle
        settings.clearUnsavedChanges()
    }
    
    // MARK: - Save Logic Button
    
    private func saveAllSettings() {
        // Steps
        settings.dailyStepGoal = dailyStepTarget
        
        // Personal / Body
        settings.gender         = gender
        settings.birthDate      = birthDate
        settings.heightCm       = height
        settings.weightKg       = weightKg
        settings.targetWeightKg = targetWeight
        
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
        
        // Persistenz
        settings.saveToDefaults()          // setzt intern Unsaved-Flag zurück

        // Neuer "gespeicherter" Referenzzustand für künftige Undos
        originalSnapshot = makeSnapshot()
    }
    
    // MARK: - Unsaved Helper

    private func markUnsaved() {
        // Während des initialen Ladens oder beim Snapshot-Restore: NICHT markieren
        guard didInitialLoad, !isRestoringSnapshot else { return }

        if saveButtonState == .saved {
            saveButtonState = .idle
        }

        settings.markUnsavedChanges()
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            
                // --------------------------
                // Domain-Kacheln (Chips)
                // --------------------------
                let firstRow: [SettingsDomain] = [
                    .body,
                    .activity,
                    .nutrition,
                    .metabolic
                ]

                let secondRow: [SettingsDomain] = [
                    .units
                ]

                VStack(spacing: 8) {

                    // 1. Zeile: Body, Activity, Nutrition, Metabolic
                    HStack(spacing: 10) {
                        ForEach(firstRow, id: \.self) { domain in
                            let isSelected = (domain == selectedDomain)

                            let strokeOpacity: Double = isSelected ? 1.0 : 0.6
                            let strokeWidth: CGFloat  = isSelected ? 1.5 : 1.0
                            let fillOpacity: Double   = isSelected ? 0.15 : 0.0

                            Button {
                                selectedDomain = domain
                            } label: {
                                Text(domain.title)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule()
                                            .fill(domain.color.opacity(fillOpacity))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                domain.color.opacity(strokeOpacity),
                                                lineWidth: strokeWidth
                                            )
                                    )
                                    .foregroundColor(Color.Glu.primaryBlue)
                            }
                        }
                    }
                    .frame(minWidth: 0,
                           maxWidth: .infinity,
                           alignment: .center)

                    // 2. Zeile: Units
                    HStack(spacing: 10) {
                        ForEach(secondRow, id: \.self) { domain in
                            let isSelected = (domain == selectedDomain)

                            let strokeOpacity: Double = isSelected ? 1.0 : 0.6
                            let strokeWidth: CGFloat  = isSelected ? 1.5 : 1.0
                            let fillOpacity: Double   = isSelected ? 0.15 : 0.0

                            Button {
                                selectedDomain = domain
                            } label: {
                                Text(domain.title)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule()
                                            .fill(domain.color.opacity(fillOpacity))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                domain.color.opacity(strokeOpacity),
                                                lineWidth: strokeWidth
                                            )
                                    )
                                    .foregroundColor(Color.Glu.primaryBlue)
                            }
                        }
                    }
                    .frame(minWidth: 0,
                           maxWidth: .infinity,
                           alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 0)
                
                // --------------------------
                // Inhalt pro gewählter Domain
                // --------------------------
                Form {
                    
                    if selectedDomain == .body {
                        BodySettingsSection(
                            gender: $gender,
                            birthDate: $birthDate,
                            heightCm: $height,
                            weightKg: $weightKg,
                            targetWeightKg: $targetWeight,
                            heightUnit: heightUnit,
                            weightUnit: weightUnit)
                    }
                    
                    if selectedDomain == .activity {
                        ActivitySettingsSection(dailyStepTarget: $dailyStepTarget)
                    }
                    
                    if selectedDomain == .metabolic {
                        MetabolicSettingsSection(
                            glucoseUnit:   $glucoseUnit,
                            glucoseMin:    $glucoseMin,
                            glucoseMax:    $glucoseMax,
                            veryLowLimit:  $veryLowLimit,
                            veryHighLimit: $veryHighLimit)
                    }
                    
                    if selectedDomain == .nutrition {
                        NutritionSettingsSection(
                            dailyCarbs:    $dailyCarbs,
                            dailyProtein:  $dailyProtein,
                            dailyFat:      $dailyFat,
                            dailyCalories: $dailyCalories)
                    }
                    
                    if selectedDomain == .units {
                        UnitsSettingsSection(
                            glucoseUnit: $glucoseUnit,
                            distanceUnit: $distanceUnit,
                            weightUnit: $weightUnit,
                            heightUnit: $heightUnit)
                    }
                }
                .scrollContentBackground(.hidden)
                
                // --------------------------
                // BUTTON-BEREICH
                // --------------------------
                HStack(spacing: 12) {
                    Spacer()
                    
                    // 👉 Undo-Button nur, wenn wirklich unsaved changes existieren
                    if settings.hasUnsavedChanges {
                        Button("Undo Changes") {
                            restoreFromSnapshot()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button {
                        guard saveButtonState != .saving else { return }
                        
                        saveButtonState = .saving
                        saveAllSettings()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            saveButtonState = .saved
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if saveButtonState == .saved {
                                    saveButtonState = .idle
                                }
                            }
                        }
                    } label: {
                        switch saveButtonState {
                        case .idle:
                            Text("Save Settings")
                        case .saving:
                            Text("Saving…")
                        case .saved:
                            Text("Saved ✓")
                        }
                    }
                    .buttonStyle(GluVibPrimaryButtonStyle())
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Steps
            dailyStepTarget = settings.dailyStepGoal
            
            // Personal / Body
            gender       = settings.gender
            birthDate    = settings.birthDate
            height       = settings.heightCm
            weightKg     = settings.weightKg
            targetWeight = settings.targetWeightKg
            
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

            // Initial: Snapshot aus aktuellem (gespeicherten) Zustand
            DispatchQueue.main.async {
                originalSnapshot = makeSnapshot()
                didInitialLoad = true
                settings.clearUnsavedChanges()
            }
        }
        // BODY
        .onChange(of: gender)       { _ in markUnsaved() }
        .onChange(of: birthDate)    { _ in markUnsaved() }
        .onChange(of: height)       { _ in markUnsaved() }
        .onChange(of: weightKg)     { _ in markUnsaved() }
        .onChange(of: targetWeight) { _ in markUnsaved() }
        
        // UNITS
        .onChange(of: glucoseUnit)  { _ in markUnsaved() }
        .onChange(of: weightUnit)   { _ in markUnsaved() }
        .onChange(of: heightUnit)   { _ in markUnsaved() }
        .onChange(of: distanceUnit) { _ in markUnsaved() }
        
        // ACTIVITY
        .onChange(of: dailyStepTarget) { _ in markUnsaved() }
        
        // METABOLIC
        .onChange(of: glucoseMin)    { _ in markUnsaved() }
        .onChange(of: glucoseMax)    { _ in markUnsaved() }
        .onChange(of: veryLowLimit)  { _ in markUnsaved() }
        .onChange(of: veryHighLimit) { _ in markUnsaved() }
        
        // NUTRITION
        .onChange(of: dailyCarbs)    { _ in markUnsaved() }
        .onChange(of: dailyProtein)  { _ in markUnsaved() }
        .onChange(of: dailyCalories) { _ in markUnsaved() }
        .onChange(of: dailyFat)      { _ in markUnsaved() }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthStore())
}
