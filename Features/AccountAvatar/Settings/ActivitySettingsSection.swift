//
//  ActivitySettingsSection.swift
//  GluVibProbe
//
//  Domain: ACTIVITY – Daily Step Target (V1)
//
//  UI scaled to match Units & Body Settings
//  - Uses the shared WheelPickerSheet (Apple-style, consistent everywhere)
//  - No tiles / no card frames
//

import SwiftUI

struct ActivitySettingsSection: View {

    // MARK: - Bindings (SSoT)

    @Binding var dailyStepTarget: Int

    // MARK: - Sheet Flags

    @State private var showStepsPicker: Bool = false

    // MARK: - Units-Style Tokens (MATCH UnitsSettingsSection)

    private let titleColor: Color = Color.Glu.primaryBlue
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let blockSpacing: CGFloat = 14

    // MARK: - Range

    private let minSteps: Int = 1_000
    private let maxSteps: Int = 30_000
    private let step: Int = 500

    // MARK: - Label

    private func stepsLabel(_ v: Int) -> String {
        "\(v.formatted(.number.grouping(.automatic))) steps"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: blockSpacing) {
                dailyStepsRow
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Row (TYPO MATCH Units/Body)

    private var dailyStepsRow: some View {
        Button { showStepsPicker = true } label: {
            HStack {
                Text("Daily Step Target")
                    .font(sectionTitleFont)
                    .foregroundColor(titleColor)

                Spacer()

                Text(stepsLabel(dailyStepTarget))
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
        .sheet(isPresented: $showStepsPicker) {

            let values = Array(stride(from: minSteps, through: maxSteps, by: step))

            WheelPickerSheet<Int>(
                title: "Daily Step Target",
                selection: $dailyStepTarget,
                values: values,
                valueLabel: { stepsLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }
}

// MARK: - Preview

#Preview("ActivitySettingsSection – Wheel Picker") {
    NavigationStack {
        Form {
            ActivitySettingsSection(dailyStepTarget: .constant(10_000))
        }
        .tint(Color.Glu.primaryBlue)
    }
}

