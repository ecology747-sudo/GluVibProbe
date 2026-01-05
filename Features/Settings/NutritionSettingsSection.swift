//
//  NutritionSettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: NUTRITION – Targets für Carbs, Protein, Fat, Calories
///
/// - Nutzt die zentrale Domain-Farbe: Color.Glu.nutritionAccent (Aqua)
/// - Zeigt nur den Nutrition-Bereich (Daily Carbs, Protein, Fat, Calories)
/// - Optik wie eine Domain-Kachel (analog BodySettingsSection / ActivitySettingsSection)
struct NutritionSettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var dailyCarbs: Int
    @Binding var dailyProtein: Int
    @Binding var dailyFat: Int
    @Binding var dailyCalories: Int

    // MARK: - Sheet Flags

    @State private var showCarbsSheet: Bool = false
    @State private var showProteinSheet: Bool = false
    @State private var showFatSheet: Bool = false
    @State private var showCaloriesSheet: Bool = false

    // MARK: - Label-Helper

    private func carbsLabel(_ grams: Int) -> String { "\(grams) g" }
    private func proteinLabel(_ grams: Int) -> String { "\(grams) g" }
    private func fatLabel(_ grams: Int) -> String { "\(grams) g" }
    private func caloriesLabel(_ kcal: Int) -> String { "\(kcal) kcal" }

    // MARK: - GluVibe Done-Button (gleich wie in BodySettingsSection)

    private func doneButton(_ title: String, action: @escaping () -> Void) -> some View {
        let color = Color.Glu.primaryBlue

        return Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 22)
                .background(
                    Capsule().fill(color.opacity(0.15))
                )
                .overlay(
                    Capsule().stroke(color, lineWidth: 1)
                )
                .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                carbsRow
                proteinRow
                fatRow
                caloriesRow
            }
            .padding(16)
            // !!! UPDATED: Domain-tinted Innenfläche bleibt (wie vorher Fill), aber ohne eigenen Stroke
            .background( // !!! UPDATED
                RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous) // !!! UPDATED
                    .fill(Color.Glu.nutritionAccent.opacity(0.06))                                // !!! UPDATED
            )
            // !!! UPDATED: zentraler Card-Style (Stroke-Dicke + Highlight + Shadow)
            .gluVibCardFrame(domainColor: Color.Glu.nutritionAccent)                              // !!! UPDATED
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    // MARK: - Rows

    private var carbsRow: some View {
        Button { showCarbsSheet = true } label: {
            HStack {
                Text("Daily Carbohydrates")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(carbsLabel(dailyCarbs))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCarbsSheet) { carbsSheet }
    }

    private var proteinRow: some View {
        Button { showProteinSheet = true } label: {
            HStack {
                Text("Daily Protein")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(proteinLabel(dailyProtein))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showProteinSheet) { proteinSheet }
    }

    private var fatRow: some View {
        Button { showFatSheet = true } label: {
            HStack {
                Text("Daily Fat")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(fatLabel(dailyFat))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFatSheet) { fatSheet }
    }

    private var caloriesRow: some View {
        Button { showCaloriesSheet = true } label: {
            HStack {
                Text("Daily Calories")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(caloriesLabel(dailyCalories))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCaloriesSheet) { caloriesSheet }
    }

    // MARK: - Sheets

    private var carbsSheet: some View {
        VStack(spacing: 16) {
            Text("Daily Carbohydrates")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)

            Picker("", selection: $dailyCarbs) {
                ForEach(Array(stride(from: 50, through: 3000, by: 10)), id: \.self) { grams in
                    Text(carbsLabel(grams))
                        .font(.title2)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(grams)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 260)

            doneButton("Done") { showCarbsSheet = false }
        }
        .padding()
        .presentationDetents([.fraction(0.45)])
    }

    private var proteinSheet: some View {
        VStack(spacing: 16) {
            Text("Daily Protein")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)

            Picker("", selection: $dailyProtein) {
                ForEach(Array(stride(from: 40, through: 400, by: 10)), id: \.self) { grams in
                    Text(proteinLabel(grams))
                        .font(.title2)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(grams)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 260)

            doneButton("Done") { showProteinSheet = false }
        }
        .padding()
        .presentationDetents([.fraction(0.45)])
    }

    private var fatSheet: some View {
        VStack(spacing: 16) {
            Text("Daily Fat")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)

            Picker("", selection: $dailyFat) {
                ForEach(Array(stride(from: 20, through: 250, by: 10)), id: \.self) { grams in
                    Text(fatLabel(grams))
                        .font(.title2)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(grams)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 260)

            doneButton("Done") { showFatSheet = false }
        }
        .padding()
        .presentationDetents([.fraction(0.45)])
    }

    private var caloriesSheet: some View {
        VStack(spacing: 16) {
            Text("Daily Calories")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)

            Picker("", selection: $dailyCalories) {
                ForEach(Array(stride(from: 1000, through: 10_000, by: 50)), id: \.self) { kcal in
                    Text(caloriesLabel(kcal))
                        .font(.title2)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(kcal)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 260)

            doneButton("Done") { showCaloriesSheet = false }
        }
        .padding()
        .presentationDetents([.fraction(0.45)])
    }
}

// MARK: - Preview

#Preview("NutritionSettingsSection") {
    NavigationStack {
        Form {
            NutritionSettingsSection(
                dailyCarbs:    .constant(200),
                dailyProtein:  .constant(80),
                dailyFat:      .constant(70),
                dailyCalories: .constant(2500)
            )
        }
    }
}
