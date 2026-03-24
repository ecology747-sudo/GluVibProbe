//
//  BodySettingsSection.swift
//  GluVibProbe
//
//  Settings — Body Section
//  Purpose:
//  - Renders target weight and target sleep settings for the body domain.
//  - Displays target weight in the selected unit while storing the SSoT value in kg.
//
//  Data Flow (SSoT):
//  - SettingsDomainCardScreen local @State -> bindings -> BodySettingsSection -> UI
//  - Weight unit display depends on SettingsModel.shared
//
//  Key Connections:
//  - SettingsModel.shared
//  - WheelPickerSheet
//  - targetWeightKg binding
//  - dailySleepGoalMinutes binding
//

import SwiftUI

struct BodySettingsSection: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    @Binding var targetWeightKg: Int
    @Binding var dailySleepGoalMinutes: Int

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @ObservedObject private var settings = SettingsModel.shared

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var showWeightPicker: Bool = false
    @State private var showSleepPicker: Bool = false

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let kgToLbsFactor: Double = 2.2046226218

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let sectionSpacing: CGFloat = 18
    private let blockSpacing: CGFloat = 14

    // ============================================================
    // MARK: - Conversion Helpers
    // ============================================================

    private func kgToLbs(_ kg: Int) -> Int {
        Int((Double(kg) * kgToLbsFactor).rounded())
    }

    private func lbsToKg(_ lbs: Int) -> Int {
        Int((Double(lbs) / kgToLbsFactor).rounded())
    }

    // ============================================================
    // MARK: - Display Mapping
    // ============================================================

    private var weightUnitLabel: String {
        settings.weightUnit.label
    }

    private func weightDisplayText(fromKg kg: Int) -> String { // 🟨 UPDATED
        switch settings.weightUnit {
        case .kg:
            return L10n.Avatar.BodySettings.weightValue(kg, unit: weightUnitLabel)
        case .lbs:
            return L10n.Avatar.BodySettings.weightValue(kgToLbs(kg), unit: weightUnitLabel)
        }
    }

    private func sleepLabel(_ minutes: Int) -> String { // 🟨 UPDATED
        let h = minutes / 60
        let m = minutes % 60
        return m == 0
            ? L10n.Avatar.BodySettings.sleepHoursOnly(h)
            : L10n.Avatar.BodySettings.sleepHoursMinutes(h, m)
    }

    // ============================================================
    // MARK: - Picker Values
    // ============================================================

    private var weightPickerValues: [Int] {
        switch settings.weightUnit {
        case .kg:
            return Array(40...250)
        case .lbs:
            let minLbs = kgToLbs(40)
            let maxLbs = kgToLbs(250)
            return Array(minLbs...maxLbs)
        }
    }

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

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {

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

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    private var targetWeightRow: some View {
        Button { showWeightPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Target Weight",
                        defaultValue: "Target Weight",
                        comment: "Section title for target weight in body settings"
                    )
                ) // 🟨 UPDATED
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
                title: String(
                    localized: "Target Weight",
                    defaultValue: "Target Weight",
                    comment: "Wheel picker title for target weight in body settings"
                ),
                selection: displayedWeightBinding,
                values: weightPickerValues,
                valueLabel: { L10n.Avatar.BodySettings.weightValue($0, unit: weightUnitLabel) },
                detent: .fraction(0.75)
            )
        }
    }

    private var targetSleepRow: some View {
        Button { showSleepPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Target Sleep",
                        defaultValue: "Target Sleep",
                        comment: "Section title for target sleep in body settings"
                    )
                ) // 🟨 UPDATED
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
                title: String(
                    localized: "Target Sleep",
                    defaultValue: "Target Sleep",
                    comment: "Wheel picker title for target sleep in body settings"
                ),
                selection: $dailySleepGoalMinutes,
                values: values,
                valueLabel: { sleepLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("BodySettingsSection – Scaled") {
    NavigationStack {
        Form {
            BodySettingsSection(
                targetWeightKg: .constant(75),
                dailySleepGoalMinutes: .constant(8 * 60)
            )
        }
        .tint(Color.Glu.systemForeground)
    }
}
