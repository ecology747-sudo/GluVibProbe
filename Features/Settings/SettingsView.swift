import SwiftUI

struct SettingsView: View {
    
    // MARK: - State Personal & Units
    @State private var gender: String = "Male"
    @State private var birthDate: Date = Date()
    @State private var height: Int = 170
    @State private var weightKg: Int = 75
    @State private var targetWeight: Int = 75
    @State private var glucoseUnit: GlucoseUnit = .mgdL
    @State private var weightUnit: WeightUnit = .kg
    @State private var heightUnit: HeightUnit = .cm
    @State private var energyUnit: EnergyUnit = .kcal
    @State private var distanceUnit: DistanceUnit = .kilometers
    @State private var dailyStepTarget: Int = 10_000   // ⬅️ NEU: Zielwert Schritte
    
    // MARK: - State Metabolic Targets
    @State private var glucoseMin: Int = 70
    @State private var glucoseMax: Int = 180
    @State private var hypoLimit: Int = 70
    @State private var hyperLimit: Int = 180
    @State private var veryLowLimit: Int = 55
    @State private var veryHighLimit: Int = 250
    
    // MARK: - State Nutrition Targets
    @State private var dailyCarbs: Int = 200
    @State private var dailyProtein: Int = 80
    @State private var dailyCalories: Int = 2500
    @State private var dailyFat: Int = 70
    
    // MARK: - Hilfsfunktionen mg/dL <-> mmol/L
    // lowest selectable Birth year 1920
    var dateRange1920: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 1920
        components.month = 1
        components.day = 1
        return calendar.date(from: components)!
    }
    //mg/dL <-> mmol/L
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
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack {                    // Form + Button untereinander
                
                Form {
                    
                    // --------------------------
                    // Section: Personal & Units
                    // --------------------------
                    Section(header: Text("Personal Data & Units")) {
                        
                        // Gender
                        HStack {
                            Text("Gender")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Picker("", selection: $gender) {
                                Text("Male").tag("Male")
                                Text("Female").tag("Female")
                                Text("Other").tag("Other")
                            }
                            .pickerStyle(.segmented)   // oder .segmented, je nach UI
                        }
                        
                        // Birth Date
                        HStack {
                            Text("Birth Date")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $birthDate,
                                in: dateRange1920...Date(),          // 🔥 Bereich: 1920 bis heute
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .frame(width: 130, height: 50)
                            .clipped()
                            .padding(.trailing, 4)
                        }
                        
                        // BODY HEIGHT
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Body Height")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("", selection: $height) {          // height = cm
                                    ForEach(130...220, id: \.self) { cm in
                                        if heightUnit == .cm {
                                            Text("\(cm) cm").tag(cm)
                                        } else {
                                            let totalInches = Int((Double(cm) / 2.54).rounded())
                                            let feet = totalInches / 12
                                            let inches = totalInches % 12
                                            
                                            Text("\(feet) ft \(inches) in")
                                                .tag(cm)
                                        }
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 120, height: 50)
                                .clipped()
                            }
                            
                            HStack {
                                Picker("", selection: $heightUnit) {
                                    ForEach(HeightUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        
                        // BODY WEIGHT
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Body Weight")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("", selection: $weightKg) {
                                    ForEach(40...300, id: \.self) { kg in
                                        if weightUnit == .kg {
                                            Text("\(kg) kg")
                                        } else {
                                            let lbs = Int((Double(kg) * 2.20462).rounded())
                                            Text("\(lbs) lbs")
                                        }
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 50)
                                .clipped()
                            }
                            
                            HStack {
                                Picker("", selection: $weightUnit) {
                                    ForEach(WeightUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        
                        // TARGET WEIGHT
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Target Weight")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("", selection: $targetWeight) {
                                    ForEach(40...250, id: \.self) { kg in
                                        if weightUnit == .kg {
                                            Text("\(kg) kg").tag(kg)
                                        } else {
                                            let lbs = Int((Double(kg) * 2.20462).rounded())
                                            Text("\(lbs) lbs").tag(kg)
                                        }
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 50)
                                .clipped()
                            }
                            
                            HStack {
                                Picker("", selection: $weightUnit) {
                                    ForEach(WeightUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        // 🆕 DAILY STEP TARGET – hier neu dazwischen
                       VStack(alignment: .leading, spacing: 8) {
                           HStack {
                               Text("Daily Step Target")
                                   .font(.subheadline)
                                   .foregroundColor(.secondary)
                               
                               Spacer()
                               
                               Picker("", selection: $dailyStepTarget) {
                                   ForEach(Array(stride(from: 1_000, through: 30_000, by: 500)), id: \.self) { steps in
                                       Text("\(steps) steps").tag(steps)
                                   }
                               }
                               .pickerStyle(.wheel)
                               .frame(width: 150, height: 50)
                               .clipped()
                           }
                       }
                        
                        // BLOOD GLUCOSE UNIT
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blood Glucose")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $glucoseUnit) {
                                ForEach(GlucoseUnit.allCases) { unit in
                                    Text(unit.label).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // DISTANCE UNIT
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distance")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $distanceUnit) {
                                ForEach(DistanceUnit.allCases) { unit in
                                    Text(unit.label).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    // ---------------------------------
                    // Section: Metabolic Targets & TIR
                    // ---------------------------------
                    Section(header: Text("Metabolic Targets & Thresholds")) {
                        
                        
                            // TIR WITH RangeSlider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Glucose Target Range")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(tirMinDisplay)–\(tirMaxDisplay) \(glucoseUnit.label)")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                
                                RangeSlider(
                                    lowerValue: Binding(
                                        get: {
                                            glucoseUnit == .mgdL
                                            ? Double(glucoseMin)
                                            : mgToMmol(glucoseMin)
                                        },
                                        set: { newVal in
                                            if glucoseUnit == .mgdL {
                                                glucoseMin = min(Int(newVal.rounded()), glucoseMax)
                                            } else {
                                                let mg = mmolToMg(newVal)
                                                glucoseMin = min(mg, glucoseMax)
                                            }
                                        }
                                    ),
                                    upperValue: Binding(
                                        get: {
                                            glucoseUnit == .mgdL
                                            ? Double(glucoseMax)
                                            : mgToMmol(glucoseMax)
                                        },
                                        set: { newVal in
                                            if glucoseUnit == .mgdL {
                                                glucoseMax = max(Int(newVal.rounded()), glucoseMin)
                                            } else {
                                                let mg = mmolToMg(newVal)
                                                glucoseMax = max(mg, glucoseMin)
                                            }
                                        }
                                    ),
                                    range: glucoseUnit == .mgdL
                                    ? 50.0...300.0        // mg/dL
                                    : 2.775...16.65          // mmol/L
                                    ,
                                    // 🔹 unterschiedliches minGap nach Einheit:
                                    minGap: glucoseUnit == .mgdL
                                    ? 25.0                // z.B. 25 mg/dL
                                    : 1.5                 // z.B. 1.5 mmol/L
                                )
                                .frame(height: 40)
                            }
                        // VERY LOW / HIGH GLUCOSE LIMITS
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Very Low / Very High Glucose Thresholds")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            LowerUpperRangeGlucoseSlider(
                                lowerValue: Binding(
                                    get: {
                                        glucoseUnit == .mgdL
                                        ? Double(veryLowLimit)
                                        : mgToMmol(veryLowLimit)
                                    },
                                    set: { newVal in
                                        if glucoseUnit == .mgdL {
                                            // mg/dL → direkter Wert, aber <= veryHighLimit
                                            veryLowLimit = min(Int(newVal.rounded()), veryHighLimit)
                                        } else {
                                            // mmol → zurückrechnen zu mg/dL
                                            let mg = mmolToMg(newVal)
                                            veryLowLimit = min(mg, veryHighLimit)
                                        }
                                    }
                                ),
                                upperValue: Binding(
                                    get: {
                                        glucoseUnit == .mgdL
                                        ? Double(veryHighLimit)
                                        : mgToMmol(veryHighLimit)
                                    },
                                    set: { newVal in
                                        if glucoseUnit == .mgdL {
                                            // mg/dL → direkter Wert, aber >= veryLowLimit
                                            veryHighLimit = max(Int(newVal.rounded()), veryLowLimit)
                                        } else {
                                            // mmol → zurückrechnen zu mg/dL
                                            let mg = mmolToMg(newVal)
                                            veryHighLimit = max(mg, veryLowLimit)
                                        }
                                    }
                                ),
                                
                                // Wertebereich je nach Einheit
                                range: glucoseUnit == .mgdL
                                ? 40.0...400.0
                                : 2.2...22.2,
                                
                                // Mindestabstand zwischen den Slider-Knobs
                                minGap: glucoseUnit == .mgdL
                                ? 25.0            // mg/dL Sicherheitsabstand
                                : 1.5             // mmol/L Sicherheitsabstand
                            )
                            .frame(height: 40)
                            
                            HStack {
                                Text("Very Low Glucose")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(veryLowLineText)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            
                            HStack {
                                Text("Very High Glucose")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(veryHighLineText)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }}
                            }
                        
                        
                        // -------------------------------
                        // Section: Nutrition Targets ...
                        // -------------------------------
                        Section(header: Text("Nutrition Targets")) {
                            
                            // DAILY CARBOHYDRATES
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Daily Carbohydrates")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $dailyCarbs) {
                                        ForEach(Array(stride(from: 50, through: 3000, by: 50)), id: \.self) { grams in
                                            Text("\(grams) g").tag(grams)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 120, height: 50)
                                    .clipped()
                                }
                            }
                            
                            // DAILY PROTEIN
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Daily Protein")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $dailyProtein) {
                                        ForEach(Array(stride(from: 40, through: 400, by: 10)), id: \.self) { grams in
                                            Text("\(grams) g").tag(grams)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 120, height: 50)
                                    .clipped()
                                }
                            }
                            
                            // DAILY FAT
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Daily Fat")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $dailyFat) {
                                        ForEach(Array(stride(from: 20, through: 250, by: 5)), id: \.self) { grams in
                                            Text("\(grams) g").tag(grams)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 120, height: 50)
                                    .clipped()
                                }
                            }
                            
                            // DAILY CALORIES
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Daily Calories")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $dailyCalories) {
                                        ForEach(stride(from: 1000, through: 10000, by: 50).map { $0 }, id: \.self) { kcal in
                                            Text("\(kcal) kcal").tag(kcal)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 130, height: 50)
                                    .clipped()
                                }
                            }
                        }
                        
                        // Section Time & Localization
                        Section(header: Text("Time & Localization")) {
                            Text("GluVib uses your iPhone system settings for time, date and region.")
                                .font(.footnote)
                                .foregroundColor(.black)
                        }
                        
                        // Section Data Sources & HealthKit
                        Section(header: Text("Data Sources & HealthKit Integration")) {
                            // später: HealthKit Permissions etc.
                        }
                    }
                    
                    // SAVE BUTTON
                    HStack {
                        Spacer()
                        Button("Save Settings") {
                            // später: saveSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
            }
        }
}

#Preview {
    SettingsView()
        .environmentObject(HealthStore())
}

// MARK: - Units

enum GlucoseUnit: String, CaseIterable, Identifiable {
    case mgdL = "mg/dL"
    case mmolL = "mmol/L"
    
    var id: String { rawValue }
    var label: String { rawValue }
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg = "kg"
    case lbs = "lbs"
    
    var id: String { rawValue }
    var label: String { rawValue }
}

enum HeightUnit: String, CaseIterable, Identifiable {
    case cm = "cm"
    case feetInches = "ft/in"
    
    var id: String { rawValue }
    var label: String { rawValue }
}

enum EnergyUnit: String, CaseIterable, Identifiable {
    case kcal = "kcal"
    case kilojoules = "kJ"
    
    var id: String { rawValue }
    var label: String { rawValue }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case kilometers = "km"
    case miles = "mi"
    
    var id: String { rawValue }
    var label: String { rawValue }
}
