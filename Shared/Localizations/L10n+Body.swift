//
//  L10n+Body.swift
//  GluVib
//

import Foundation

extension L10n {

    enum BodyOverview {
        
        enum BodyOverviewFormat {

            static var targetValue: String {
                String(
                    localized: "overview.body.format.target_value",
                    defaultValue: "Target: %@",
                    comment: "Formatted target label in the body overview weight card"
                )
            }
        }

        static var title: String {
            String(
                localized: "overview.body.title",
                defaultValue: "Body Overview",
                comment: "Header title for the body overview screen"
            )
        }

        static var lastNight: String {
            String(
                localized: "overview.body.last_night",
                defaultValue: "Last night",
                comment: "Subtitle label for last night's sleep in the body overview"
            )
        }

        static var restingHeartRateSubtitle: String {
            String(
                localized: "overview.body.resting_heart_rate_subtitle",
                defaultValue: "Resting heart rate",
                comment: "Subtitle below the resting heart rate value in the body overview"
            )
        }

        static var estimatedBodyFat: String {
            String(
                localized: "overview.body.estimated_body_fat",
                defaultValue: "Estimated body fat",
                comment: "Subtitle below the body fat value in the body overview"
            )
        }

        static var insightTitle: String {
            String(
                localized: "overview.body.insight_title",
                defaultValue: "Insight",
                comment: "Title for the body overview insight card"
            )
        }

        static var sleepGoalProgressFormat: String {
            String(
                localized: "overview.body.sleep_goal_progress_format",
                defaultValue: "%1$lld%% of %2$@",
                comment: "Sleep goal progress text showing percent and formatted goal value"
            )
        }

        static var hrvTodayFormat: String {
            String(
                localized: "overview.body.hrv_today_format",
                defaultValue: "%1$lld ms · HRV today",
                comment: "HRV subtitle in the heart card of the body overview"
            )
        }
    }

    enum BodyOverviewFormat {

        static var targetValue: String {
            String(
                localized: "overview.body.format.target_value",
                defaultValue: "Target: %@",
                comment: "Target label with formatted target value in body overview"
            )
        }

        static var minutesOnly: String {
            String(
                localized: "overview.body.format.minutes_only",
                defaultValue: "%lld min",
                comment: "Formatted duration with minutes only"
            )
        }

        static var hoursOnly: String {
            String(
                localized: "overview.body.format.hours_only",
                defaultValue: "%lld h",
                comment: "Formatted duration with hours only"
            )
        }

        static var hoursMinutes: String {
            String(
                localized: "overview.body.format.hours_minutes",
                defaultValue: "%1$lld h %2$lld min",
                comment: "Formatted duration with hours and minutes"
            )
        }
    }

    enum BodyOverviewBMI {

        static var underweight: String {
            String(
                localized: "overview.body.bmi.underweight",
                defaultValue: "Underweight",
                comment: "BMI category label for underweight"
            )
        }

        static var normalRange: String {
            String(
                localized: "overview.body.bmi.normal_range",
                defaultValue: "Normal range",
                comment: "BMI category label for normal range"
            )
        }

        static var overweight: String {
            String(
                localized: "overview.body.bmi.overweight",
                defaultValue: "Overweight",
                comment: "BMI category label for overweight"
            )
        }

        static var obesityRange: String {
            String(
                localized: "overview.body.bmi.obesity_range",
                defaultValue: "Obesity range",
                comment: "BMI category label for obesity range"
            )
        }
    }
    
    enum Weight {

            // MARK: - Titles

            static var title: String {
                String(
                    localized: "metric.weight.title",
                    defaultValue: "Weight",
                    comment: "Metric title for body weight"
                )
            }

            static var todayKPI: String {
                String(
                    localized: "metric.weight.kpi.today",
                    defaultValue: "Weight Today",
                    comment: "KPI title for today's body weight"
                )
            }

            static var monthlyTitle: String {
                String(
                    localized: "metric.weight.monthly_title",
                    defaultValue: "Weight / Month",
                    comment: "Monthly chart title for body weight"
                )
            }

            // MARK: - Hints

            static var hintNoDataOrPermission: String {
                String(
                    localized: "metric.weight.hint.no_data_or_permission",
                    defaultValue: "No weight data available. Please check Apple Health permissions and whether body weight has already been recorded in Apple Health.",
                    comment: "Combined hint shown when no visible weight data is available because permission is missing and/or no readable weight history exists"
                )
            }

            static var hintNoToday: String {
                String(
                    localized: "metric.weight.hint.no_today",
                    defaultValue: "No weight recorded today yet.",
                    comment: "Hint shown when no weight is recorded today yet"
                )
            }
        }

    enum Sleep {

            // MARK: - Titles

            static var title: String {
                String(
                    localized: "metric.sleep.title",
                    defaultValue: "Sleep",
                    comment: "Metric title for sleep"
                )
            }

            static var todayKPI: String {
                String(
                    localized: "metric.sleep.kpi.today",
                    defaultValue: "Sleep Today",
                    comment: "KPI title for today's sleep"
                )
            }

            static var monthlyTitle: String {
                String(
                    localized: "metric.sleep.monthly_title",
                    defaultValue: "Sleep / Month",
                    comment: "Monthly chart title for sleep"
                )
            }

            // MARK: - Hints

            static var hintNoDataOrPermission: String {
                String(
                    localized: "metric.sleep.hint.no_data_or_permission",
                    defaultValue: "No sleep data available. Please check Apple Health permissions and whether sleep data has already been recorded in Apple Health.",
                    comment: "Combined hint shown when no visible sleep data is available because permission is missing and/or no readable sleep history exists"
                )
            }

            static var hintNoToday: String {
                String(
                    localized: "metric.sleep.hint.no_today",
                    defaultValue: "No sleep data available today yet.",
                    comment: "Hint shown when no sleep data is available for today yet"
                )
            }
        }
    enum BMI {

            // MARK: - Titles

            static var title: String {
                String(
                    localized: "metric.bmi.title",
                    defaultValue: "BMI",
                    comment: "Metric title for body mass index"
                )
            }

            static var todayKPI: String {
                String(
                    localized: "metric.bmi.kpi.today",
                    defaultValue: "BMI Today",
                    comment: "KPI title for today's body mass index"
                )
            }

            static var monthlyTitle: String {
                String(
                    localized: "metric.bmi.monthly_title",
                    defaultValue: "BMI / Month",
                    comment: "Monthly chart title for body mass index"
                )
            }

            // MARK: - Hints

            static var hintNoDataOrPermission: String {
                String(
                    localized: "metric.bmi.hint.no_data_or_permission",
                    defaultValue: "No BMI data available. Please check Apple Health permissions and whether BMI has already been recorded in Apple Health.",
                    comment: "Combined hint shown when no visible BMI data is available because permission is missing and/or no readable BMI history exists"
                )
            }

            static var hintNoToday: String {
                String(
                    localized: "metric.bmi.hint.no_today",
                    defaultValue: "No BMI recorded today yet.",
                    comment: "Hint shown when no BMI is recorded today yet"
                )
            }
        }
    

    enum BodyFat {

            // MARK: - Titles

            static var title: String {
                String(
                    localized: "metric.body_fat.title",
                    defaultValue: "Body Fat",
                    comment: "Metric title for body fat percentage"
                )
            }

            static var todayKPI: String {
                String(
                    localized: "metric.body_fat.kpi.today",
                    defaultValue: "Body Fat Today",
                    comment: "KPI title for today's body fat percentage"
                )
            }

            static var monthlyTitle: String {
                String(
                    localized: "metric.body_fat.monthly_title",
                    defaultValue: "Body Fat / Month",
                    comment: "Monthly chart title for body fat percentage"
                )
            }

            // MARK: - Hints

            static var hintNoDataOrPermission: String {
                String(
                    localized: "metric.body_fat.hint.no_data_or_permission",
                    defaultValue: "No body fat data available. Please check Apple Health permissions and whether body fat has already been recorded in Apple Health.",
                    comment: "Combined hint shown when no visible body fat data is available because permission is missing and/or no readable body fat history exists"
                )
            }

            static var hintNoToday: String {
                String(
                    localized: "metric.body_fat.hint.no_today",
                    defaultValue: "No body fat recorded today yet.",
                    comment: "Hint shown when no body fat is recorded today yet"
                )
            }
        }

    enum RestingHeartRate {

        // MARK: - Titles

        static var title: String {
            String(
                localized: "metric.resting_heart_rate.title",
                defaultValue: "Resting HR",
                comment: "Metric title for resting heart rate"
            )
        }

        static var todayKPI: String {
            String(
                localized: "metric.resting_heart_rate.kpi.today",
                defaultValue: "Resting HR Today",
                comment: "KPI title for today's resting heart rate"
            )
        }

        static var monthlyTitle: String {
            String(
                localized: "metric.resting_heart_rate.monthly_title",
                defaultValue: "Resting HR / Month",
                comment: "Monthly chart title for resting heart rate"
            )
        }

        // MARK: - Hints

        static var hintNoDataOrPermission: String {
            String(
                localized: "metric.resting_heart_rate.hint.no_data_or_permission",
                defaultValue: "No resting heart rate data available. Please check Apple Health permissions and whether resting heart rate has already been recorded in Apple Health.",
                comment: "Combined hint shown when no visible resting heart rate data is available because permission is missing and/or no readable resting heart rate history exists"
            )
        }

        static var hintNoToday: String {
            String(
                localized: "metric.resting_heart_rate.hint.no_today",
                defaultValue: "No resting heart rate recorded today yet.",
                comment: "Hint shown when no resting heart rate is recorded today yet"
            )
        }
    }
    
    enum BodyOverviewInsight {

        static var notEnoughData: String {
            String(
                localized: "overview.body.insight.not_enough_data",
                defaultValue: "There is not enough data yet to generate a meaningful body insight.",
                comment: "Fallback body insight when not enough body data is available"
            )
        }

        static var sleepShort: String {
            String(
                localized: "overview.body.insight.sleep_short",
                defaultValue: "Sleep has been on the short side.",
                comment: "Short body insight phrase for insufficient sleep"
            )
        }

        static var sleepSolid: String {
            String(
                localized: "overview.body.insight.sleep_solid",
                defaultValue: "Sleep looks solid overall.",
                comment: "Short body insight phrase for solid sleep"
            )
        }

        static var sleepOnTarget: String {
            String(
                localized: "overview.body.insight.sleep_on_target",
                defaultValue: "Sleep has been roughly on target.",
                comment: "Short body insight phrase for sleep near target"
            )
        }

        static var bmiPrefixVeryHigh: String {
            String(
                localized: "overview.body.insight.bmi_prefix_very_high",
                defaultValue: "Given your current BMI, even small, steady changes can be helpful. ",
                comment: "Insight prefix for very high BMI situations"
            )
        }

        static var bmiPrefixHigh: String {
            String(
                localized: "overview.body.insight.bmi_prefix_high",
                defaultValue: "With your current BMI, gentle trends already matter. ",
                comment: "Insight prefix for high BMI situations"
            )
        }

        static var recoveryNudge: String {
            String(
                localized: "overview.body.insight.recovery_nudge",
                defaultValue: " Also keep an eye on recovery and stress.",
                comment: "Optional extra body insight sentence for higher stress or recovery load"
            )
        }

        static var weightStable: String {
            String(
                localized: "overview.body.insight.weight_stable",
                defaultValue: "Your weight has been fairly stable over the last days.",
                comment: "Body insight sentence for stable weight trend"
            )
        }

        static var weightUp: String {
            String(
                localized: "overview.body.insight.weight_up",
                defaultValue: "Your weight has slightly increased over the last days.",
                comment: "Body insight sentence for increasing weight trend"
            )
        }

        static var weightDown: String {
            String(
                localized: "overview.body.insight.weight_down",
                defaultValue: "Your weight has slightly decreased over the last days.",
                comment: "Body insight sentence for decreasing weight trend"
            )
        }
    }
}
