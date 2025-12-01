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

    // MARK: - Body

    var body: some View {
        Section {
            ZStack {
                // Hintergrundkarte
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.nutritionAccent.opacity(0.06))

                // Rahmen in Nutrition-Farbe (Aqua)
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.nutritionAccent.opacity(0.7), lineWidth: 1)

                VStack(alignment: .leading, spacing: 16) {

                    // DAILY CARBOHYDRATES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Carbohydrates")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()

                            Picker("", selection: $dailyCarbs) {
                                ForEach(Array(stride(from: 50, through: 3000, by: 50)), id: \.self) { grams in
                                    Text("\(grams) g")
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(grams)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }

                    // DAILY PROTEIN
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Protein")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()

                            Picker("", selection: $dailyProtein) {
                                ForEach(Array(stride(from: 40, through: 400, by: 10)), id: \.self) { grams in
                                    Text("\(grams) g")
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(grams)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }

                    // DAILY FAT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Fat")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()

                            Picker("", selection: $dailyFat) {
                                ForEach(Array(stride(from: 20, through: 250, by: 5)), id: \.self) { grams in
                                    Text("\(grams) g")
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(grams)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }

                    // DAILY CALORIES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Calories")
                            .font(.subheadline)
                            .foregroundColor(Color.Glu.primaryBlue)

                        HStack {
                            Spacer()

                            Picker("", selection: $dailyCalories) {
                                ForEach(stride(from: 1000, through: 10000, by: 50).map { $0 }, id: \.self) { kcal in
                                    Text("\(kcal) kcal")
                                        .foregroundColor(Color.Glu.primaryBlue)
                                        .tag(kcal)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 160, height: 80)
                            .clipped()
                        }
                    }
                }
                .padding(16)
            }
            // exakt wie bei ActivitySettingsSection
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

// MARK: - Preview

#Preview("NutritionSettingsSection") {
    NavigationStack {
        Form {
            NutritionSettingsSection(
                dailyCarbs: .constant(200),
                dailyProtein: .constant(80),
                dailyFat: .constant(70),
                dailyCalories: .constant(2500)
            )
        }
    }
}
