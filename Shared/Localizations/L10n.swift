//
//  L10n.swift
//  GluVib
//

import Foundation

enum L10n {

    enum Common {

        // MARK: - Domain / Generic UI

        static var activity: String {
            String(
                localized: "common.activity",
                defaultValue: "Activity",
                comment: "Activity domain header title"
            )
        }

        static var nutritionOverviewTitle: String {
            String(
                localized: "common.nutrition_overview.title",
                defaultValue: "Nutrition Overview",
                comment: "Header title for the nutrition overview screen"
            )
        }

        static var metabolicOverviewTitle: String { // 🟨 NEW
            String(
                localized: "common.metabolic_overview.title",
                defaultValue: "Metabolic",
                comment: "Header title for the metabolic premium overview screen"
            )
        }

        static var insulinUnitSingular: String {
            String(
                localized: "common.insulin_unit.singular",
                defaultValue: "Unit",
                comment: "Singular label for one insulin unit"
            )
        }

        static var insulinUnitPlural: String {
            String(
                localized: "common.insulin_unit.plural",
                defaultValue: "Units",
                comment: "Plural label for multiple insulin units"
            )
        }

        static var metabolicHeader: String {
            String(
                localized: "common.metabolic_header",
                defaultValue: "Metabolic",
                comment: "Header title for the metabolic domain"
            )
        }

        static var target: String {
            String(
                localized: "common.target",
                defaultValue: "Target",
                comment: "KPI card title for target value"
            )
        }

        static var current: String {
            String(
                localized: "common.current",
                defaultValue: "Current",
                comment: "KPI card title for current value"
            )
        }

        static var delta: String {
            String(
                localized: "common.delta",
                defaultValue: "Delta",
                comment: "KPI card title for difference to target"
            )
        }

        static var month: String {
            String(
                localized: "common.month",
                defaultValue: "Month",
                comment: "Common label for monthly chart titles"
            )
        }

        static var unitsLabel: String {
            String(
                localized: "common.units_label",
                defaultValue: "Units",
                comment: "Localized unit label for insulin units"
            )
        }

        static var tabMetabolic: String {
            String(
                localized: "common.tab.metabolic",
                defaultValue: "Metabolic",
                comment: "Bottom tab title for the metabolic domain"
            )
        }

        static var tabActivity: String {
            String(
                localized: "common.tab.activity",
                defaultValue: "Activity",
                comment: "Bottom tab title for the activity domain"
            )
        }

        static var tabBody: String {
            String(
                localized: "common.tab.body",
                defaultValue: "Body",
                comment: "Bottom tab title for the body domain"
            )
        }

        static var tabNutrition: String {
            String(
                localized: "common.tab.nutrition",
                defaultValue: "Nutrition",
                comment: "Bottom tab title for the nutrition domain"
            )
        }

        static var tabHistory: String {
            String(
                localized: "common.tab.history",
                defaultValue: "History",
                comment: "Bottom tab title for the history domain"
            )
        }

        static var todayUpper: String {
            String(
                localized: "common.today_upper",
                defaultValue: "TODAY",
                comment: "Uppercase label for today in overview header subtitles"
            )
        }

        static var yesterdayUpper: String {
            String(
                localized: "common.yesterday_upper",
                defaultValue: "YESTERDAY",
                comment: "Uppercase label for yesterday in overview header subtitles"
            )
        }

        static var kcalUnit: String {
            String(
                localized: "common.unit.kcal",
                defaultValue: "kcal",
                comment: "Unit label for kilocalories"
            )
        }

        static var languageCode: String { // 🟨 NEW
            String(
                localized: "common.language_code",
                defaultValue: "en",
                comment: "Language code used for localized web routes"
            )
        }

        // MARK: - Compact Number Suffixes

        static var thousandSuffix: String {
            String(
                localized: "common.number_suffix.thousand",
                defaultValue: "K",
                comment: "Suffix for thousands in compact chart axis labels"
            )
        }

        // MARK: - Period Labels

        static var period7d: String {
            String(
                localized: "common.period.7d",
                defaultValue: "7 D",
                comment: "Period label for 7 days"
            )
        }

        static var period14d: String {
            String(
                localized: "common.period.14d",
                defaultValue: "14 D",
                comment: "Period label for 14 days"
            )
        }

        static var period30d: String {
            String(
                localized: "common.period.30d",
                defaultValue: "30 D",
                comment: "Period label for 30 days"
            )
        }

        static var period90d: String {
            String(
                localized: "common.period.90d",
                defaultValue: "90 D",
                comment: "Period label for 90 days"
            )
        }

        static var period180d: String {
            String(
                localized: "common.period.180d",
                defaultValue: "180 D",
                comment: "Period label for 180 days"
            )
        }

        static var period365d: String {
            String(
                localized: "common.period.365d",
                defaultValue: "365 D",
                comment: "Period label for 365 days"
            )
        }
    }
}
