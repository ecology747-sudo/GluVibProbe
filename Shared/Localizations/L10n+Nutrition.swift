//
//  L10n+Nutrition.swift
//  GluVib
//

import Foundation

extension L10n {
    
    enum NutritionOverview { // 🟨 NEW

        static var scoreLabel: String {
            String(
                localized: "overview.nutrition.score_label",
                defaultValue: "Nutrition Score",
                comment: "Label above the nutrition score badge in nutrition overview"
            )
        }

        static var carbsShort: String { // 🟨 NEW
            String(
                localized: "overview.nutrition.carbs_short",
                defaultValue: "KH",
                comment: "Short carbs label for nutrition overview pie and legend"
            )
        }

        static var sugarOfCarbsLabel: String {
            String(
                localized: "overview.nutrition.sugar_of_carbs_label",
                defaultValue: "Sugar (of Carbs)",
                comment: "Label for sugar row shown as part of carbs in nutrition overview"
            )
        }

        static var pieIOS17Only: String {
            String(
                localized: "overview.nutrition.pie.ios17_only",
                defaultValue: "iOS 17 Pie only",
                comment: "Fallback label shown when pie chart is unavailable before iOS 17"
            )
        }
    }
    
    enum NutritionOverviewFormat { // 🟨 NEW

        static var gramsValue: String {
            String(
                localized: "format.grams_value",
                defaultValue: "%lld g",
                comment: "Formatted grams value"
            )
        }

        static var kcalValue: String {
            String(
                localized: "format.kcal_value",
                defaultValue: "%lld kcal",
                comment: "Formatted kilocalorie value"
            )
        }

        static var macroTargetProgress: String {
            String(
                localized: "format.macro_target_progress",
                defaultValue: "%1$@ / %2$@  (%3$lld%%)",
                comment: "Formatted macro progress showing current value, target value and percent"
            )
        }

        static var macroShare: String {
            String(
                localized: "format.macro_share",
                defaultValue: "%1$lld g (%2$lld%%)",
                comment: "Formatted macro share showing grams and percent"
            )
        }
        
        
    }
    
    
    
    enum NutritionOverviewEnergy { // 🟨 NEW

        static var sectionTitle: String {
            String(
                localized: "overview.nutrition.energy.section_title",
                defaultValue: "Energy Balance (kcal)",
                comment: "Section title for the 7-day energy balance chart in nutrition overview"
            )
        }

        static var burned: String {
            String(
                localized: "overview.nutrition.energy.burned",
                defaultValue: "Burned",
                comment: "Title for burned energy card in nutrition overview"
            )
        }

        static var active: String {
            String(
                localized: "overview.nutrition.energy.active",
                defaultValue: "Active",
                comment: "Label for active energy row in nutrition overview"
            )
        }

        static var resting: String {
            String(
                localized: "overview.nutrition.energy.resting",
                defaultValue: "Resting",
                comment: "Label for resting energy row in nutrition overview"
            )
        }

        static var intake: String {
            String(
                localized: "overview.nutrition.energy.intake",
                defaultValue: "Intake",
                comment: "Title for intake energy card in nutrition overview"
            )
        }

        static var nutrition: String {
            String(
                localized: "overview.nutrition.energy.nutrition",
                defaultValue: "Nutrition",
                comment: "Label for nutrition intake row in nutrition overview"
            )
        }

        static var remaining: String {
            String(
                localized: "overview.nutrition.energy.remaining",
                defaultValue: "kcal remaining",
                comment: "Label for remaining energy balance in nutrition overview ring"
            )
        }

        static var over: String {
            String(
                localized: "overview.nutrition.energy.over",
                defaultValue: "kcal over",
                comment: "Label for exceeded energy balance in nutrition overview ring"
            )
        }
    }
    
    enum NutritionOverviewInsight { // 🟨 NEW

        static var title: String {
            String(
                localized: "overview.nutrition.insight.title",
                defaultValue: "Insight",
                comment: "Title of the insight card in nutrition overview"
            )
        }

        static var emptyToday: String {
            String(
                localized: "overview.nutrition.insight.empty_today",
                defaultValue: "No nutrition data recorded yet today.",
                comment: "Fallback insight text when no nutrition data is available for today"
            )
        }

        static var noDataToday: String { // 🟨 NEW
            String(
                localized: "overview.nutrition.insight.no_data_today",
                defaultValue: "No nutrition data recorded yet today.",
                comment: "Insight text when no nutrition data has been recorded today"
            )
        }

        static var carbsAboveTarget: String { // 🟨 NEW
            String(
                localized: "overview.nutrition.insight.carbs_above_target",
                defaultValue: "Your carbs are above target today.",
                comment: "Insight text when carbs are above the daily target"
            )
        }

        static var proteinLow: String { // 🟨 NEW
            String(
                localized: "overview.nutrition.insight.protein_low",
                defaultValue: "Protein is still low today — a protein-rich meal could help.",
                comment: "Insight text when protein intake is still low today"
            )
        }

        static var energyRemaining: String { // 🟨 NEW
            String(
                localized: "overview.nutrition.insight.energy_remaining",
                defaultValue: "You still have energy remaining for today.",
                comment: "Insight text when energy intake is still below total burned energy"
            )
        }

        static var energyOver: String { // 🟨 NEW
            String(
                localized: "overview.nutrition.insight.energy_over",
                defaultValue: "You are currently above your daily energy burn.",
                comment: "Insight text when energy intake is above total burned energy"
            )
        }
    }

    enum Carbs {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.carbs.title",
                defaultValue: "Carbs",
                comment: "Metric title for carbohydrates"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.carbs.kpi.today",
                defaultValue: "Carbs Today",
                comment: "KPI title for today's carbohydrate intake"
            )
        }

        static var monthlyTitle: String {
            String(
                localized: "metric.carbs.monthly_title",
                defaultValue: "Carbs / Month",
                comment: "Monthly chart title for carbohydrates"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.carbs.hint.no_data_or_permission",
                defaultValue: "No carbohydrate data available. Please check Apple Health permissions and whether carbohydrates have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible carbohydrate data is available because permission is missing and/or no readable carbohydrate history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.carbs.hint.no_today",
                defaultValue: "No carbohydrates recorded today yet.",
                comment: "Hint shown when no carbohydrates are recorded today yet"
            )
        }
    }

    enum CarbsDayparts {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.carbs_dayparts.title",
                defaultValue: "Carbs Split",
                comment: "Metric title for carbohydrate daypart split"
            )
        }

        static var chartTitle: String { // 🟨 UPDATED
            String(
                localized: "metric.carbs_dayparts.chart_title",
                defaultValue: "Ø Carbs Split (g)",
                comment: "Chart title for average carbohydrate split by daypart"
            )
        }

        static var morning: String {
            String(
                localized: "metric.carbs_dayparts.morning",
                defaultValue: "Morning",
                comment: "Label for morning carbs segment"
            )
        }

        static var afternoon: String {
            String(
                localized: "metric.carbs_dayparts.afternoon",
                defaultValue: "Afternoon",
                comment: "Label for afternoon carbs segment"
            )
        }

        static var night: String {
            String(
                localized: "metric.carbs_dayparts.night",
                defaultValue: "Night",
                comment: "Label for night carbs segment"
            )
        }

        static var morningWindow: String {
            String(
                localized: "metric.carbs_dayparts.morning_window",
                defaultValue: "06–12",
                comment: "Time window label for morning carbs segment"
            )
        }

        static var afternoonWindow: String {
            String(
                localized: "metric.carbs_dayparts.afternoon_window",
                defaultValue: "12–18",
                comment: "Time window label for afternoon carbs segment"
            )
        }

        static var nightWindow: String {
            String(
                localized: "metric.carbs_dayparts.night_window",
                defaultValue: "18–06",
                comment: "Time window label for night carbs segment"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.carbs_dayparts.hint.no_data_or_permission",
                defaultValue: "No carb split data available. Please check Apple Health permissions and whether carbohydrates have already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible carb split data is available because permission is missing and/or no readable carbohydrate history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.carbs_dayparts.hint.no_today",
                defaultValue: "No carb split data recorded today yet.",
                comment: "Hint shown when no carb split data is available for today yet, but historical carbohydrate data exists"
            )
        }
    }

    enum Sugar {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.sugar.title",
                defaultValue: "Sugar",
                comment: "Metric title for sugar"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.sugar.kpi.today",
                defaultValue: "Sugar Today",
                comment: "KPI title for today's sugar intake"
            )
        }

        static var todayOfCarbsKPI: String { // 🟨 NEW
            String(
                localized: "metric.sugar.kpi.today_of_carbs",
                defaultValue: "Sugar (of Carbs) Today",
                comment: "KPI title for today's sugar intake shown as part of carbs"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.sugar.hint.no_data_or_permission",
                defaultValue: "No sugar data available. Please check Apple Health permissions and whether sugar has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible sugar data is available because permission is missing and/or no readable sugar history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.sugar.hint.no_today",
                defaultValue: "No sugar recorded today yet.",
                comment: "Hint shown when no sugar is recorded today yet"
            )
        }
    }

    enum Protein { // 🟨 UPDATED

            static var title: String {
                String(
                    localized: "metric.protein.title",
                    defaultValue: "Protein",
                    comment: "Metric title for protein"
                )
            }

            static var todayKPI: String {
                String(
                    localized: "metric.protein.kpi.today",
                    defaultValue: "Protein Today",
                    comment: "KPI title for today's protein intake"
                )
            }

            static var monthlyTitle: String {
                String(
                    localized: "metric.protein.monthly_title",
                    defaultValue: "Protein / Month",
                    comment: "Monthly chart title for protein"
                )
            }

            static var hintNoDataOrPermission: String {
                String(
                    localized: "metric.protein.hint.no_data_or_permission",
                    defaultValue: "No protein data available. Please check Apple Health permissions and whether protein has already been recorded in Apple Health.",
                    comment: "Combined hint shown when no visible protein data is available because permission is missing and/or no readable protein history exists"
                )
            }

            static var hintNoToday: String {
                String(
                    localized: "metric.protein.hint.no_today",
                    defaultValue: "No protein recorded today yet.",
                    comment: "Hint shown when no protein is recorded today yet"
                )
            }
        }

    enum Fat { // 🟨 NEW

            // MARK: - Titles

            static var title: String {
                String(
                    localized: "metric.fat.title",
                    defaultValue: "Fat",
                    comment: "Metric title for dietary fat"
                )
            }

            static var todayKPI: String {
                String(
                    localized: "metric.fat.kpi.today",
                    defaultValue: "Fat Today",
                    comment: "KPI title for today's fat intake"
                )
            }

            static var monthlyTitle: String {
                String(
                    localized: "metric.fat.monthly_title",
                    defaultValue: "Fat / Month",
                    comment: "Monthly chart title for fat"
                )
            }

            // MARK: - Hints

            static var hintNoDataOrPermission: String {
                String(
                    localized: "metric.fat.hint.no_data_or_permission",
                    defaultValue: "No fat data available. Please check Apple Health permissions and whether fat has already been recorded in Apple Health.",
                    comment: "Combined hint shown when no visible fat data is available because permission is missing and/or no readable fat history exists"
                )
            }

            static var hintNoToday: String {
                String(
                    localized: "metric.fat.hint.no_today",
                    defaultValue: "No fat recorded today yet.",
                    comment: "Hint shown when no fat is recorded today yet"
                )
            }
        }

    enum NutritionEnergy { // 🟨 NEW

        static var title: String {
            String(
                localized: "metric.nutrition_energy.title",
                defaultValue: "Calories",
                comment: "Metric title for nutrition energy"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.nutrition_energy.kpi.today",
                defaultValue: "Calories Today",
                comment: "KPI title for today's nutrition energy"
            )
        }

        static var monthlyTitle: String {
            String(
                localized: "metric.nutrition_energy.monthly_title",
                defaultValue: "Calories / Month",
                comment: "Monthly chart title for nutrition energy"
            )
        }

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.nutrition_energy.hint.no_data_or_permission",
                defaultValue: "No nutrition energy data available. Please check Apple Health permissions and whether nutrition energy has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible nutrition energy data is available because permission is missing and/or no readable nutrition energy history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.nutrition_energy.hint.no_today",
                defaultValue: "No calories recorded today yet.",
                comment: "Hint shown when no calories are recorded today yet"
            )
        }
    }
}
