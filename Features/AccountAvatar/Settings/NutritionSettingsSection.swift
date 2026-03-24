//
//  NutritionSettingsSection.swift
//  GluVibProbe
//
//  Settings — Nutrition Section
//  Purpose:
//  - Renders editable nutrition targets for carbs, sugar, protein, fat, and calories.
//  - Uses shared wheel pickers and existing localized value formats.
//
//  Data Flow (SSoT):
//  - SettingsDomainCardScreen local @State -> bindings -> NutritionSettingsSection -> UI
//
//  Key Connections:
//  - WheelPickerSheet
//  - Nutrition target bindings
//  - Existing string catalog value formats
//

import SwiftUI

struct NutritionSettingsSection: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    @Binding var dailyCarbs: Int
    @Binding var dailySugar: Int
    @Binding var dailyProtein: Int
    @Binding var dailyFat: Int
    @Binding var dailyCalories: Int

    // ============================================================
    // MARK: - Local State
    // ============================================================

    @State private var showCarbsPicker: Bool = false
    @State private var showSugarPicker: Bool = false
    @State private var showProteinPicker: Bool = false
    @State private var showFatPicker: Bool = false
    @State private var showCaloriesPicker: Bool = false

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let sectionSpacing: CGFloat = 18
    private let blockSpacing: CGFloat = 14

    // ============================================================
    // MARK: - Display Mapping
    // ============================================================

    private func gramsLabel(_ value: Int) -> String { // 🟨 UPDATED
        String(
            format: String(
                localized: "format.grams_value",
                defaultValue: "%lld g",
                comment: "Formatted grams value in nutrition settings"
            ),
            locale: Locale.current,
            value
        )
    }

    private func caloriesLabel(_ value: Int) -> String { // 🟨 UPDATED
        String(
            format: String(
                localized: "format.kcal_value",
                defaultValue: "%lld kcal",
                comment: "Formatted kilocalorie value in nutrition settings"
            ),
            locale: Locale.current,
            value
        )
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {

            VStack(alignment: .leading, spacing: blockSpacing) {
                carbsRow
            }

            Divider()

            VStack(alignment: .leading, spacing: blockSpacing) {
                sugarRow
            }

            Divider()

            VStack(alignment: .leading, spacing: blockSpacing) {
                proteinRow
            }

            Divider()

            VStack(alignment: .leading, spacing: blockSpacing) {
                fatRow
            }

            Divider()

            VStack(alignment: .leading, spacing: blockSpacing) {
                caloriesRow
            }
        }
        .padding(.vertical, 6)
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    private var carbsRow: some View {
        Button { showCarbsPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Daily Carbohydrates",
                        defaultValue: "Daily Carbohydrates",
                        comment: "Section title for daily carbohydrate target in nutrition settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(gramsLabel(dailyCarbs))
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
        .sheet(isPresented: $showCarbsPicker) {
            let values = Array(stride(from: 50, through: 3000, by: 10))

            WheelPickerSheet<Int>(
                title: String(
                    localized: "Daily Carbohydrates",
                    defaultValue: "Daily Carbohydrates",
                    comment: "Wheel picker title for daily carbohydrate target in nutrition settings"
                ),
                selection: $dailyCarbs,
                values: values,
                valueLabel: { gramsLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }

    private var sugarRow: some View {
        Button { showSugarPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Daily Sugar",
                        defaultValue: "Daily Sugar",
                        comment: "Section title for daily sugar target in nutrition settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(gramsLabel(dailySugar))
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
        .sheet(isPresented: $showSugarPicker) {
            let values = Array(stride(from: 0, through: 500, by: 5))

            WheelPickerSheet<Int>(
                title: String(
                    localized: "Daily Sugar",
                    defaultValue: "Daily Sugar",
                    comment: "Wheel picker title for daily sugar target in nutrition settings"
                ),
                selection: $dailySugar,
                values: values,
                valueLabel: { gramsLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }

    private var proteinRow: some View {
        Button { showProteinPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Daily Protein",
                        defaultValue: "Daily Protein",
                        comment: "Section title for daily protein target in nutrition settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(gramsLabel(dailyProtein))
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
        .sheet(isPresented: $showProteinPicker) {
            let values = Array(stride(from: 40, through: 400, by: 10))

            WheelPickerSheet<Int>(
                title: String(
                    localized: "Daily Protein",
                    defaultValue: "Daily Protein",
                    comment: "Wheel picker title for daily protein target in nutrition settings"
                ),
                selection: $dailyProtein,
                values: values,
                valueLabel: { gramsLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }

    private var fatRow: some View {
        Button { showFatPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Daily Fat",
                        defaultValue: "Daily Fat",
                        comment: "Section title for daily fat target in nutrition settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(gramsLabel(dailyFat))
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
        .sheet(isPresented: $showFatPicker) {
            let values = Array(stride(from: 20, through: 250, by: 10))

            WheelPickerSheet<Int>(
                title: String(
                    localized: "Daily Fat",
                    defaultValue: "Daily Fat",
                    comment: "Wheel picker title for daily fat target in nutrition settings"
                ),
                selection: $dailyFat,
                values: values,
                valueLabel: { gramsLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }

    private var caloriesRow: some View {
        Button { showCaloriesPicker = true } label: {
            HStack {
                Text(
                    String(
                        localized: "Daily Calories",
                        defaultValue: "Daily Calories",
                        comment: "Section title for daily calories target in nutrition settings"
                    )
                ) // 🟨 UPDATED
                .font(sectionTitleFont)
                .foregroundColor(titleColor)

                Spacer()

                Text(caloriesLabel(dailyCalories))
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
        .sheet(isPresented: $showCaloriesPicker) {
            let values = Array(stride(from: 1000, through: 10_000, by: 50))

            WheelPickerSheet<Int>(
                title: String(
                    localized: "Daily Calories",
                    defaultValue: "Daily Calories",
                    comment: "Wheel picker title for daily calories target in nutrition settings"
                ),
                selection: $dailyCalories,
                values: values,
                valueLabel: { caloriesLabel($0) },
                detent: .fraction(0.75)
            )
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("NutritionSettingsSection – Scaled") {
    NavigationStack {
        Form {
            NutritionSettingsSection(
                dailyCarbs: .constant(200),
                dailySugar: .constant(50),
                dailyProtein: .constant(80),
                dailyFat: .constant(70),
                dailyCalories: .constant(2500)
            )
        }
        .tint(Color.Glu.systemForeground)
    }
}
