//
//  BodySettingsSection.swift
//  GluVibProbe
//
//  Domain: BODY – Targets only (V1)
//
//  UI scaled to match Units & Metabolic Settings
//  - Uses the shared WheelPickerSheet (Apple-style, consistent everywhere)
//  - Displays Target Weight in the currently selected weight unit (kg/lbs)
//  - Stores targetWeightKg as base unit (kg) in SettingsModel (SSoT)
//

import SwiftUI

struct BodySettingsSection: View {

    // MARK: - Bindings (SSoT)

    @Binding var targetWeightKg: Int
    @Binding var dailySleepGoalMinutes: Int

    // MARK: - Settings (Units)

    @ObservedObject private var settings = SettingsModel.shared

    // MARK: - Sheet Flags

    @State private var showWeightPicker: Bool = false
    @State private var showSleepPicker: Bool = false

    // MARK: - Units-Style Tokens (MATCH UnitsSettingsSection)

    private let titleColor: Color = Color.Glu.primaryBlue
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let blockSpacing: CGFloat = 14

    // MARK: - Conversions (base = kg)

    private let kgToLbsFactor: Double = 2.2046226218

    private func kgToLbs(_ kg: Int) -> Int {
        Int((Double(kg) * kgToLbsFactor).rounded())
    }

    private func lbsToKg(_ lbs: Int) -> Int {
        Int((Double(lbs) / kgToLbsFactor).rounded())
    }

    // MARK: - Labels

    private var weightUnitLabel: String {
        settings.weightUnit.label
    }

    private func weightDisplayText(fromKg kg: Int) -> String {
        switch settings.weightUnit {
        case .kg:
            return "\(kg) \(weightUnitLabel)"
        case .lbs:
            return "\(kgToLbs(kg)) \(weightUnitLabel)"
        }
    }

    private func sleepLabel(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    // MARK: - Picker Values (in display unit)

    private var weightPickerValues: [Int] {
        switch settings.weightUnit {
        case .kg:
            return Array(40...250)
        case .lbs:
            let minLbs = kgToLbs(40)   // ~88
            let maxLbs = kgToLbs(250)  // ~551
            return Array(minLbs...maxLbs)
        }
    }

    // MARK: - Display Binding (Int) for WheelPickerSheet

    private var displayedWeightBinding: Binding<Int> {
        Binding<Int>(
            get: {
                switch settings.weightUnit {
                case .kg:
                    return targetWeightKg
                case .lbs:
                    return kgToLbs(targetWeightKg)
                }
            },
            set: { newDisplayed in
                switch settings.weightUnit {
                case .kg:
                    targetWeightKg = newDisplayed
                case .lbs:
                    targetWeightKg = lbsToKg(newDisplayed)
                }
            }
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: blockSpacing) {
                targetWeightRow
            }

            Divider()

            VStack(alignment: .leading, spacing: blockSpacing) {
                targetSleepRow
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Rows (TYPO MATCH Units)

    private var targetWeightRow: some View {
        Button { showWeightPicker = true } label: {
            HStack {
                Text("Target Weight")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Spacer()

                Text(weightDisplayText(fromKg: targetWeightKg))
                    .font(segmentFont)
                    .foregroundColor(titleColor)

                Image(systemName: "chevron.up.chevron.down")
                    .font(segmentFont)
                    .foregroundColor(titleColor.opacity(0.7))
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showWeightPicker) {

            WheelPickerSheet<Int>(
                title: "Target Weight",
                selection: displayedWeightBinding,
                values: weightPickerValues,
                valueLabel: { "\($0) \(weightUnitLabel)" },
                detent: .fraction(0.75) // per deinem aktuellen Wunsch ~70–75%
            )
        }
    }

    private var targetSleepRow: some View {
        Button { showSleepPicker = true } label: {
            HStack {
                Text("Target Sleep")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Spacer()

                Text(sleepLabel(dailySleepGoalMinutes))
                    .font(segmentFont)
                    .foregroundColor(titleColor)

                Image(systemName: "chevron.up.chevron.down")
                    .font(segmentFont)
                    .foregroundColor(titleColor.opacity(0.7))
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSleepPicker) {

            let values = Array(stride(from: 300, through: 720, by: 15))

            WheelPickerSheet<Int>(
                title: "Target Sleep",
                selection: $dailySleepGoalMinutes,
                values: values,
                valueLabel: { sleepLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }
}

// MARK: - Preview

#Preview("BodySettingsSection – Scaled") {
    NavigationStack {
        Form {
            BodySettingsSection(
                targetWeightKg: .constant(75),
                dailySleepGoalMinutes: .constant(8 * 60)
            )
        }
        .tint(Color.Glu.primaryBlue)
    }
}
