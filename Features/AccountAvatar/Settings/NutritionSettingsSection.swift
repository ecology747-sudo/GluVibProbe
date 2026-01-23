//
//  NutritionSettingsSection.swift
//  GluVibProbe
//
//  Domain: NUTRITION – Targets only (V1)
//
//  UI scaled to match Units & Body Settings
//  - Uses the shared WheelPickerSheet (Apple-style, consistent everywhere)
//  - No tiles / no custom card styling
//

import SwiftUI

struct NutritionSettingsSection: View {

    // MARK: - Bindings (SSoT)

    @Binding var dailyCarbs: Int
    @Binding var dailyProtein: Int
    @Binding var dailyFat: Int
    @Binding var dailyCalories: Int

    // MARK: - Sheet Flags

    @State private var showCarbsPicker: Bool = false
    @State private var showProteinPicker: Bool = false
    @State private var showFatPicker: Bool = false
    @State private var showCaloriesPicker: Bool = false

    // MARK: - Units-Style Tokens (MATCH UnitsSettingsSection / BodySettingsSection)

    private let titleColor: Color = Color.Glu.primaryBlue
    private let sectionTitleFont: Font = .title3.weight(.semibold)
    private let segmentFont: Font = .body.weight(.bold)
    private let blockSpacing: CGFloat = 14

    // MARK: - Formatters

    private func gramsLabel(_ grams: Int) -> String { "\(grams) g" }
    private func caloriesLabel(_ kcal: Int) -> String { "\(kcal) kcal" }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: blockSpacing) {
                carbsRow
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

    // MARK: - Rows (TYPO MATCH Units / Body)

    private var carbsRow: some View {
        Button { showCarbsPicker = true } label: {
            HStack {
                Text("Daily Carbohydrates")
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
                title: "Daily Carbohydrates",
                selection: $dailyCarbs,
                values: values,
                valueLabel: { "\(String($0)) g" },
                detent: .fraction(0.75)
            )
        }
    }

    private var proteinRow: some View {
        Button { showProteinPicker = true } label: {
            HStack {
                Text("Daily Protein")
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
                title: "Daily Protein",
                selection: $dailyProtein,
                values: values,
                valueLabel: { "\(String($0)) g" },
                detent: .fraction(0.75)
            )
        }
    }

    private var fatRow: some View {
        Button { showFatPicker = true } label: {
            HStack {
                Text("Daily Fat")
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
                title: "Daily Fat",
                selection: $dailyFat,
                values: values,
                valueLabel: { "\(String($0)) g" },
                detent: .fraction(0.75)
            )
        }
    }

    private var caloriesRow: some View {
        Button { showCaloriesPicker = true } label: {
            HStack {
                Text("Daily Calories")
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
                title: "Daily Calories",
                selection: $dailyCalories,
                values: values,
                valueLabel: { "\(String($0)) kcal" },
                detent: .fraction(0.75)
            )
        }
    }
}

// MARK: - Preview

#Preview("NutritionSettingsSection – Scaled") {
    NavigationStack {
        Form {
            NutritionSettingsSection(
                dailyCarbs: .constant(200),
                dailyProtein: .constant(80),
                dailyFat: .constant(70),
                dailyCalories: .constant(2500)
            )
        }
        .tint(Color.Glu.primaryBlue)
    }
}
