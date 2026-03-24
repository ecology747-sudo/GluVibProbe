//
//  ActivitySettingsSection.swift
//  GluVibProbe
//
//  Settings — Activity Section
//  Purpose:
//  - Renders the daily step target setting for the activity domain.
//  - Uses the shared wheel picker flow for a consistent settings experience.
//
//  Data Flow (SSoT):
//  - SettingsDomainCardScreen local @State -> binding -> ActivitySettingsSection -> UI
//
//  Key Connections:
//  - WheelPickerSheet
//  - dailyStepTarget binding
//

import SwiftUI

struct ActivitySettingsSection: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    @Binding var dailyStepTarget: Int

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var showStepsPicker: Bool = false

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let minSteps: Int = 1_000
    private let maxSteps: Int = 30_000
    private let step: Int = 500

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let sectionSpacing: CGFloat = 18

    // ============================================================
    // MARK: - Display Mapping
    // ============================================================

    private func stepsLabel(_ value: Int) -> String { // 🟨 UPDATED
        L10n.Avatar.ActivitySettings.stepsValue(value)
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            dailyStepsRow
        }
        .padding(.vertical, 6)
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    private var dailyStepsRow: some View {
        Button { showStepsPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Daily Step Target",
                        defaultValue: "Daily Step Target",
                        comment: "Section title for daily step target in activity settings"
                    )
                ) // 🟨 UPDATED
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
                title: String(
                    localized: "Daily Step Target",
                    defaultValue: "Daily Step Target",
                    comment: "Wheel picker title for daily step target in activity settings"
                ),
                selection: $dailyStepTarget,
                values: values,
                valueLabel: { stepsLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("ActivitySettingsSection – Wheel Picker") {
    NavigationStack {
        Form {
            ActivitySettingsSection(dailyStepTarget: .constant(10_000))
        }
        .tint(Color.Glu.systemForeground)
    }
}
