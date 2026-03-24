//
//  L10n+FAQ.swift
//  GluVib
//
//  Domain: Avatar / FAQ / Long Text
//  Screen Type: Static Content Localization
//
//  Purpose
//  - Centralizes all FAQ content for FrequentlyAskedQuestionsView.
//  - Uses long-text localization blocks: each section title, question, and answer
//    remains a complete semantic text block.
//  - Avoids sentence fragmentation for better translation quality and maintenance.
//

import Foundation

extension L10n {

    enum FAQ {

        // ============================================================
        // MARK: - Common
        // ============================================================

        static var navigationTitle: String {
            String(
                localized: "faq.navigation.title",
                defaultValue: "FAQs",
                comment: "Navigation title for the frequently asked questions screen"
            )
        }

        // ============================================================
        // MARK: - General
        // ============================================================

        enum General {

            static var title: String {
                String(
                    localized: "faq.general.title",
                    defaultValue: "General",
                    comment: "Section title for the general FAQ chapter"
                )
            }

            enum WhatIsGluVib {
                static var question: String {
                    String(
                        localized: "faq.general.what_is_gluvib.question",
                        defaultValue: "What is GluVib?",
                        comment: "Question asking what GluVib is in the general FAQ section"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.general.what_is_gluvib.answer",
                        defaultValue: "GluVib is a read-only app for analyzing, aggregating, and visualizing your personal health data. It displays trends, summaries, and charts based on the data available in Apple Health. GluVib does not modify, upload, or share health data. All information is processed and displayed locally on the device, and no personal health data is transmitted to external services. The app can be used fully offline, as long as the required data is available on the device via Apple Health. Exception: if you manually add lab values (for example HbA1c), those entries are stored locally inside the app, are not synced to other devices via iCloud, and are removed if the app is uninstalled.",
                        comment: "Answer explaining what GluVib is in the general FAQ section"
                    )
                }
            }

            enum WhoIsGluVibFor {
                static var question: String {
                    String(
                        localized: "faq.general.who_is_gluvib_for.question",
                        defaultValue: "Who is GluVib for?",
                        comment: "Question asking who GluVib is for in the general FAQ section"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.general.who_is_gluvib_for.answer",
                        defaultValue: "GluVib is for people who want a structured view of their Apple Health data, including trends over time and consistent metric summaries across Nutrition, Body, and Activity. Metabolic analytics (glucose-related views) are optional Premium features and are only available when CGM (Sensor) data exists in Apple Health.",
                        comment: "Answer explaining who GluVib is for in the general FAQ section"
                    )
                }
            }

            enum IsCoachingApp {
                static var question: String {
                    String(
                        localized: "faq.general.is_coaching_app.question",
                        defaultValue: "Is GluVib a coaching app?",
                        comment: "Question asking whether GluVib is a coaching app in the general FAQ section"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.general.is_coaching_app.answer",
                        defaultValue: "No. GluVib is not a coaching, motivational, or behavior-change app. It does not provide prompts, goals for behavior change, or personalized action guidance.",
                        comment: "Answer explaining whether GluVib is a coaching app in the general FAQ section"
                    )
                }
            }

            enum MedicalRecommendations {
                static var question: String {
                    String(
                        localized: "faq.general.medical_recommendations.question",
                        defaultValue: "Does GluVib provide medical recommendations?",
                        comment: "Question asking whether GluVib provides medical recommendations in the general FAQ section"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.general.medical_recommendations.answer",
                        defaultValue: "No. GluVib does not provide medical advice, diagnosis, therapy recommendations, or treatment guidance. Any values and charts are informational displays of available data.",
                        comment: "Answer explaining whether GluVib provides medical recommendations in the general FAQ section"
                    )
                }
            }

            enum ReplaceProfessionalCare {
                static var question: String {
                    String(
                        localized: "faq.general.replace_professional_care.question",
                        defaultValue: "Does GluVib replace professional care?",
                        comment: "Question asking whether GluVib replaces professional care in the general FAQ section"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.general.replace_professional_care.answer",
                        defaultValue: "No. GluVib is not a substitute for professional medical care. The app is designed for personal data review and does not replace clinical evaluation.",
                        comment: "Answer explaining whether GluVib replaces professional care in the general FAQ section"
                    )
                }
            }

            enum MainLimitations {
                static var question: String {
                    String(
                        localized: "faq.general.main_limitations.question",
                        defaultValue: "What are the main limitations of GluVib?",
                        comment: "Question asking about the main limitations of GluVib in the general FAQ section"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.general.main_limitations.answer",
                        defaultValue: "GluVib’s output is limited by the completeness, timing, and quality of the data present in Apple Health. If values are missing, delayed, or recorded differently by data sources, certain metrics, charts, and summaries may be unavailable or may differ from other apps. GluVib does not modify or “repair” missing data. The level of detail and accuracy that GluVib can display directly depends on the data available in Apple Health: more complete and consistently recorded input enables more comprehensive and meaningful visualizations within the app.",
                        comment: "Answer explaining the main limitations of GluVib in the general FAQ section"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Data Basics
        // ============================================================

        enum DataBasics {

            static var title: String {
                String(
                    localized: "faq.data_basics.title",
                    defaultValue: "Data Basics — How GluVib Works",
                    comment: "Section title for the data basics FAQ chapter"
                )
            }

            enum DataSource {
                static var question: String {
                    String(
                        localized: "faq.data_basics.data_source.question",
                        defaultValue: "Where does GluVib get its data from?",
                        comment: "Question asking where GluVib gets its data from"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.data_source.answer",
                        defaultValue: "GluVib reads data exclusively from Apple Health. Apple Health is the single source of truth for all data shown in the app.",
                        comment: "Answer explaining where GluVib gets its data from"
                    )
                }
            }

            enum WithoutAppleHealth {
                static var question: String {
                    String(
                        localized: "faq.data_basics.without_apple_health.question",
                        defaultValue: "Can GluVib work without Apple Health?",
                        comment: "Question asking whether GluVib can work without Apple Health"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.without_apple_health.answer",
                        defaultValue: "No. GluVib requires Apple Health access to read and display your data. If Apple Health access is not granted or is later revoked, GluVib may show limited or no content for affected metrics.",
                        comment: "Answer explaining whether GluVib can work without Apple Health"
                    )
                }
            }

            enum ImprovesOverTime {
                static var question: String {
                    String(
                        localized: "faq.data_basics.improves_over_time.question",
                        defaultValue: "Why does GluVib improve over time?",
                        comment: "Question asking why GluVib improves over time"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.improves_over_time.answer",
                        defaultValue: "What GluVib can display depends on how complete your Apple Health data is over time. More recorded days and more consistent data availability can increase the amount of information that can be visualized and summarized in a meaningful way.",
                        comment: "Answer explaining why GluVib improves over time"
                    )
                }
            }

            enum RealTimeUpdates {
                static var question: String {
                    String(
                        localized: "faq.data_basics.real_time_updates.question",
                        defaultValue: "Does GluVib update data in real time?",
                        comment: "Question asking whether GluVib updates data in real time"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.real_time_updates.answer",
                        defaultValue: "GluVib displays most data as soon as it becomes available in Apple Health. This applies to metrics such as Nutrition entries, Activity and movement data, workouts, and insulin records. Continuous glucose monitoring (CGM) (Sensor) data is an exception (see next).",
                        comment: "Answer explaining whether GluVib updates data in real time"
                    )
                }
            }

            enum CGMRealTime {
                static var question: String {
                    String(
                        localized: "faq.data_basics.cgm_real_time.question",
                        defaultValue: "Are CGM (Sensor) values shown in real time?",
                        comment: "Question asking whether CGM sensor values are shown in real time"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.cgm_real_time.answer",
                        defaultValue: "No. GluVib does not receive real-time sensor readings. CGM (Sensor) values appear in GluVib only after they are available in Apple Health.",
                        comment: "Answer explaining whether CGM sensor values are shown in real time"
                    )
                }
            }

            enum CGMDelay {
                static var question: String {
                    String(
                        localized: "faq.data_basics.cgm_delay.question",
                        defaultValue: "Why can CGM (Sensor) data appear delayed?",
                        comment: "Question asking why CGM sensor data can appear delayed"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.cgm_delay.answer",
                        defaultValue: "CGM (Sensor) readings are typically collected by the sensor and its source app first, and then synced into Apple Health. That synchronization can be delayed or intermittent depending on the system, the source app, background sync behavior, and the overall setup. GluVib can only display what has already arrived in Apple Health.",
                        comment: "Answer explaining why CGM sensor data can appear delayed"
                    )
                }
            }

            enum CGMCoverage {
                static var question: String {
                    String(
                        localized: "faq.data_basics.cgm_coverage.question",
                        defaultValue: "What does “CGM (Sensor) Coverage 86%” mean?",
                        comment: "Question asking what the CGM coverage percentage means"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.cgm_coverage.answer",
                        defaultValue: "This is a 24-hour coverage indicator based on Apple Health CGM (Sensor) data. The percentage shows how much of the last 24 hours is covered by CGM (Sensor) readings that are currently available in Apple Health. GluVib uses minutes internally to compute this value in a device-agnostic way, because sampling frequency and sync behavior can vary across CGM (Sensor) systems. If coverage is lower, it usually means fewer readings have arrived in Apple Health yet (for example due to delayed or intermittent sync).",
                        comment: "Answer explaining what the CGM coverage percentage means"
                    )
                }
            }

            enum SmallInsulinDosesDisappear {
                static var question: String {
                    String(
                        localized: "faq.data_basics.small_insulin_doses_disappear.question",
                        defaultValue: "Why can small insulin doses disappear in GluVib?",
                        comment: "Question asking why small insulin doses can disappear in GluVib"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.data_basics.small_insulin_doses_disappear.answer",
                        defaultValue: "If you enabled the Priming (Pen Air Shot) filter in Settings, GluVib can automatically exclude very small insulin entries (≤ your threshold). This is designed for typical air shot / priming doses. A small dose is only removed if there is a larger dose of the same type (Bolus or Basal) within 2 minutes. Priming filtering is intended for pen air shots. If you use an insulin pump with micro-doses, keep this option off.",
                        comment: "Answer explaining why small insulin doses can disappear in GluVib"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Hardware & System Requirements
        // ============================================================

        enum HardwareSystemRequirements {

            static var title: String {
                String(
                    localized: "faq.hardware_system_requirements.title",
                    defaultValue: "Hardware & System Requirements",
                    comment: "Section title for the hardware and system requirements FAQ chapter"
                )
            }

            enum IPhoneRequirements {
                static var question: String {
                    String(
                        localized: "faq.hardware_system_requirements.iphone_requirements.question",
                        defaultValue: "Which iPhone devices and system version are required?",
                        comment: "Question asking which iPhone devices and system version are required"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.hardware_system_requirements.iphone_requirements.answer",
                        defaultValue: "GluVib runs on iPhone models starting with iPhone SE (3rd generation) or newer and requires iOS 17 or later. The app reads health data from Apple Health, which must be connected to GluVib so the required Health permissions can be granted.",
                        comment: "Answer explaining which iPhone devices and system version are required"
                    )
                }
            }

            enum IPadRequirements {
                static var question: String {
                    String(
                        localized: "faq.hardware_system_requirements.ipad_requirements.question",
                        defaultValue: "Which iPad devices and system version are required?",
                        comment: "Question asking which iPad devices and system version are required"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.hardware_system_requirements.ipad_requirements.answer",
                        defaultValue: "GluVib runs on iPad models that support iPadOS 17 or later. Apple Health must be available on the device and connected to GluVib so the app can read health data.",
                        comment: "Answer explaining which iPad devices and system version are required"
                    )
                }
            }

            enum AppleWatchNeeded {
                static var question: String {
                    String(
                        localized: "faq.hardware_system_requirements.apple_watch_needed.question",
                        defaultValue: "Do I need an Apple Watch?",
                        comment: "Question asking whether an Apple Watch is needed"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.hardware_system_requirements.apple_watch_needed.answer",
                        defaultValue: "No. An Apple Watch is optional. If present, it can improve data completeness for certain metrics such as activity, heart rate, and sleep, depending on what is recorded into Apple Health.",
                        comment: "Answer explaining whether an Apple Watch is needed"
                    )
                }
            }

            enum CGMHardwareNeeded {
                static var question: String {
                    String(
                        localized: "faq.hardware_system_requirements.cgm_hardware_needed.question",
                        defaultValue: "Do I need CGM (Sensor) hardware?",
                        comment: "Question asking whether CGM sensor hardware is needed"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.hardware_system_requirements.cgm_hardware_needed.answer",
                        defaultValue: "No. CGM (Sensor) hardware is optional. However, metabolic analytics in GluVib rely on CGM (Sensor) data. To use the Metabolic domain and its Premium features, CGM (Sensor) data must be available in Apple Health.",
                        comment: "Answer explaining whether CGM sensor hardware is needed"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Free vs Premium
        // ============================================================

        enum FreeVsPremium {

            static var title: String {
                String(
                    localized: "faq.free_vs_premium.title",
                    defaultValue: "Free vs Premium — What’s the Difference?",
                    comment: "Section title for the free vs premium FAQ chapter"
                )
            }

            enum WhatIsFreeVsPremium {
                static var question: String {
                    String(
                        localized: "faq.free_vs_premium.what_is_free_vs_premium.question",
                        defaultValue: "What is Free vs Premium in GluVib?",
                        comment: "Question asking what Free versus Premium means in GluVib"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.free_vs_premium.what_is_free_vs_premium.answer",
                        defaultValue: "GluVib offers two access levels. Free includes the main Overviews for Nutrition, Activity, and Body, plus one core metric per domain. Premium unlocks full access to all metrics and deeper analysis across those domains and enables the complete Metabolic domain when CGM (Sensor) data is available in Apple Health. Premium affects visibility and access only; your Apple Health data remains unchanged.",
                        comment: "Answer explaining what Free versus Premium means in GluVib"
                    )
                }
            }

            enum Trial30Days {
                static var question: String {
                    String(
                        localized: "faq.free_vs_premium.trial_30_days.question",
                        defaultValue: "Is there a 30-day trial?",
                        comment: "Question asking whether there is a 30-day trial"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.free_vs_premium.trial_30_days.answer",
                        defaultValue: "Yes. After installation, GluVib includes a free 30-day Premium trial. During the free trial, all Premium features are available, including full domain access and Metabolic features (when CGM (Sensor) data exists in Apple Health).",
                        comment: "Answer explaining whether there is a 30-day trial"
                    )
                }
            }

            enum AfterTrialEnds {
                static var question: String {
                    String(
                        localized: "faq.free_vs_premium.after_trial_ends.question",
                        defaultValue: "What happens after the free 30-day trial ends?",
                        comment: "Question asking what happens after the free trial ends"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.free_vs_premium.after_trial_ends.answer",
                        defaultValue: "After the free trial ends, GluVib automatically continues in Free mode unless a Premium subscription is started through the App Store. You will keep access to the Overviews and the core metrics included in Free, while Premium-only metrics and the Metabolic domain become unavailable. No data is deleted; everything remains stored in Apple Health.",
                        comment: "Answer explaining what happens after the free trial ends"
                    )
                }
            }

            enum WhatPremiumUnlocks {
                static var question: String {
                    String(
                        localized: "faq.free_vs_premium.what_premium_unlocks.question",
                        defaultValue: "What does Premium unlock?",
                        comment: "Question asking what Premium unlocks"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.free_vs_premium.what_premium_unlocks.answer",
                        defaultValue: "Premium unlocks full access to all metrics in Nutrition, Activity, and Body, plus the Metabolic domain (CGM (Sensor)-based analytics when CGM (Sensor) data is available in Apple Health). Premium also enables period-based analytical summaries and structured reports derived from the selected time range. If insulin data exists in Apple Health and is enabled in Settings, optional insulin-related evaluations can appear within the Metabolic domain.",
                        comment: "Answer explaining what Premium unlocks"
                    )
                }
            }

            enum WhyMetabolicNeedsCGM {
                static var question: String {
                    String(
                        localized: "faq.free_vs_premium.why_metabolic_needs_cgm.question",
                        defaultValue: "Why do metabolic features require CGM (Sensor) data?",
                        comment: "Question asking why metabolic features require CGM sensor data"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.free_vs_premium.why_metabolic_needs_cgm.answer",
                        defaultValue: "Metabolic analytics in GluVib are designed around continuous glucose data. If CGM (Sensor) data is not available through Apple Health, those analytics cannot be computed or displayed.",
                        comment: "Answer explaining why metabolic features require CGM sensor data"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Using the App
        // ============================================================

        enum UsingTheApp {

            static var title: String {
                String(
                    localized: "faq.using_the_app.title",
                    defaultValue: "Using the App — Everyday Questions",
                    comment: "Section title for the everyday usage FAQ chapter"
                )
            }

            enum RefreshData {
                static var question: String {
                    String(
                        localized: "faq.using_the_app.refresh_data.question",
                        defaultValue: "How do I refresh my data?",
                        comment: "Question asking how to refresh data in the app"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.using_the_app.refresh_data.answer",
                        defaultValue: "Some screens support pull-to-refresh. Today’s values can change as new data becomes available in Apple Health. Past days typically remain unchanged because they represent historical records.",
                        comment: "Answer explaining how to refresh data in the app"
                    )
                }
            }

            enum TodayVsPastDays {
                static var question: String {
                    String(
                        localized: "faq.using_the_app.today_vs_past_days.question",
                        defaultValue: "Why does “Today” behave differently from past days?",
                        comment: "Question asking why Today behaves differently from past days"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.using_the_app.today_vs_past_days.answer",
                        defaultValue: "Today is an in-progress day where new data may still arrive in Apple Health throughout the day. This applies in particular to data that is synced with a delay, such as CGM (Sensor) readings, which may appear hours after they were measured. As a result, today’s charts, KPIs, and coverage indicators can change as additional data becomes available. Past days, by contrast, represent completed records and are treated as historical data in the app.",
                        comment: "Answer explaining why Today behaves differently from past days"
                    )
                }
            }

            enum GoalsTargetsRanges {
                static var question: String {
                    String(
                        localized: "faq.using_the_app.goals_targets_ranges.question",
                        defaultValue: "Where can I set goals, targets & ranges?",
                        comment: "Question asking where goals, targets, and ranges can be set"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.using_the_app.goals_targets_ranges.answer",
                        defaultValue: "Goals and targets can be configured in Settings. They are used as reference values for charts and KPIs and do not change the underlying data stored in Apple Health. In the Metabolic domain, additional ranges can be configured. These ranges define how time-based metrics such as Time in Range are evaluated and how related metabolic summaries and calculations are derived. Changing goals or ranges affects how data is displayed and summarized, while the underlying Apple Health data remains unchanged.",
                        comment: "Answer explaining where goals, targets, and ranges can be set"
                    )
                }
            }

            enum ChangeUnits {
                static var question: String {
                    String(
                        localized: "faq.using_the_app.change_units.question",
                        defaultValue: "Where can I change units?",
                        comment: "Question asking where units can be changed"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.using_the_app.change_units.answer",
                        defaultValue: "Units can be changed in Settings. Unit changes affect how values are displayed (format and conversion), while the underlying Apple Health data remains unchanged. For example, body weight can be displayed in kilograms or pounds, and distance values can be shown in different unit formats depending on your selection.",
                        comment: "Answer explaining where units can be changed"
                    )
                }
            }

            enum AddLabResults {
                static var question: String {
                    String(
                        localized: "faq.using_the_app.add_lab_results.question",
                        defaultValue: "How can I add lab results (e.g., HbA1c)?",
                        comment: "Question asking how lab results such as HbA1c can be added"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.using_the_app.add_lab_results.answer",
                        defaultValue: "GluVib supports manual entry of HbA1c laboratory values. These values can be entered in Settings with a specific date for display and reporting purposes. HbA1c entries are stored locally within the app and are separate from Apple Health records. They are not synced to other devices via iCloud and are removed if the app is uninstalled.",
                        comment: "Answer explaining how lab results such as HbA1c can be added"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Glossary
        // ============================================================

        enum Glossary {

            static var title: String {
                String(
                    localized: "faq.glossary.title",
                    defaultValue: "Abbreviations & Metrics (Glossary)",
                    comment: "Section title for the glossary FAQ chapter"
                )
            }

            enum TIR {
                static var question: String {
                    String(
                        localized: "faq.glossary.tir.question",
                        defaultValue: "What does TIR mean?",
                        comment: "Question asking what TIR means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.tir.answer",
                        defaultValue: "TIR stands for Time in Range. It is a descriptive metric that summarizes how much of a selected time window has glucose values within a defined target range, based on available CGM (Sensor) data in Apple Health. The target range used for this calculation can be adjusted in Settings and affects how TIR and related summaries are evaluated.",
                        comment: "Answer explaining what TIR means in the glossary"
                    )
                }
            }

            enum GMI {
                static var question: String {
                    String(
                        localized: "faq.glossary.gmi.question",
                        defaultValue: "What does GMI mean?",
                        comment: "Question asking what GMI means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.gmi.answer",
                        defaultValue: "GMI stands for Glucose Management Indicator (%). It is a computed summary metric derived from available glucose data over a defined time period. GluVib displays GMI values based on the data present in Apple Health and provides these computed values for different selectable time periods, depending on data availability.",
                        comment: "Answer explaining what GMI means in the glossary"
                    )
                }
            }

            enum CV {
                static var question: String {
                    String(
                        localized: "faq.glossary.cv.question",
                        defaultValue: "What does CV (%) mean?",
                        comment: "Question asking what CV means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.cv.answer",
                        defaultValue: "CV stands for Coefficient of Variation (%CV). It is a variability metric commonly used in CGM (Sensor) analysis to describe glucose variability. %CV represents the relationship between the standard deviation of glucose values and their mean over a defined time period. Lower %CV values indicate lower relative glucose variability. In GluVib, CV can be displayed for today, for individual days, and as averages across selectable time periods. Deeper metric views provide period-based summaries and trend visualizations based on available CGM (Sensor) data. Target ranges and thresholds used for evaluation can be adjusted in Settings.",
                        comment: "Answer explaining what CV means in the glossary"
                    )
                }
            }

            enum SD {
                static var question: String {
                    String(
                        localized: "faq.glossary.sd.question",
                        defaultValue: "What does SD mean?",
                        comment: "Question asking what SD means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.sd.answer",
                        defaultValue: "SD stands for Standard Deviation. It is a statistical measure that describes the spread or variability of glucose values around the mean glucose level over a defined time period. A higher SD indicates larger fluctuations with more high and low values, while a lower SD indicates more stable glucose values with smaller deviations from the mean. In GluVib, SD can be displayed on a daily basis, as well as across longer selectable time periods, including average values and trend visualizations based on available CGM (Sensor) data.",
                        comment: "Answer explaining what SD means in the glossary"
                    )
                }
            }

            enum BolusAndBasal {
                static var question: String {
                    String(
                        localized: "faq.glossary.bolus_and_basal.question",
                        defaultValue: "What do Bolus and Basal mean?",
                        comment: "Question asking what Bolus and Basal mean in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.bolus_and_basal.answer",
                        defaultValue: "Bolus and Basal describe two categories of insulin delivery. Bolus insulin typically refers to discrete insulin doses given to cover meals or corrections, while Basal insulin refers to background insulin delivered continuously or at scheduled intervals. Insulin can be administered using pens or insulin pumps, and corresponding entries can be written into Apple Health either manually or via connected apps and devices. In GluVib, insulin data is displayed based on the records available in Apple Health and can be reviewed on a daily basis, across recent days, and as averages over selectable time periods. Optional filtering options, such as priming (air shot) handling, can be configured in Settings and affect how insulin entries are displayed.",
                        comment: "Answer explaining what Bolus and Basal mean in the glossary"
                    )
                }
            }

            enum CarbohydrateBolusRatio {
                static var question: String {
                    String(
                        localized: "faq.glossary.carbohydrate_bolus_ratio.question",
                        defaultValue: "What is the carbohydrate–bolus ratio (ICR)?",
                        comment: "Question asking what the carbohydrate bolus ratio means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.carbohydrate_bolus_ratio.answer",
                        defaultValue: "The carbohydrate–bolus ratio, often referred to as the insulin-to-carbohydrate ratio (ICR), describes the relationship between the amount of carbohydrates and the amount of fast-acting insulin recorded for meals. It expresses how many grams of carbohydrates are associated with one unit of bolus insulin, based on insulin and nutrition entries available in Apple Health. In GluVib, this ratio is shown as an analytical metric derived from recorded carbohydrate intake and bolus insulin data. All calculations are based on the data present in Apple Health and are displayed for informational purposes only.",
                        comment: "Answer explaining what the carbohydrate bolus ratio means in the glossary"
                    )
                }
            }

            enum BolusBasalRatio {
                static var question: String {
                    String(
                        localized: "faq.glossary.bolus_basal_ratio.question",
                        defaultValue: "What is the bolus–basal ratio?",
                        comment: "Question asking what the bolus basal ratio means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.bolus_basal_ratio.answer",
                        defaultValue: "The bolus–basal ratio describes the proportional split of total recorded daily insulin into basal insulin (background insulin) and bolus insulin (meal- or correction-related insulin). In GluVib, the bolus–basal ratio is displayed as an analytical summary derived from insulin entries recorded in Apple Health. All values are calculated from available Apple Health data and are shown for informational and analytical purposes only.",
                        comment: "Answer explaining what the bolus basal ratio means in the glossary"
                    )
                }
            }

            enum IG {
                static var question: String {
                    String(
                        localized: "faq.glossary.ig.question",
                        defaultValue: "What does IG (Interstitial Glucose) mean?",
                        comment: "Question asking what IG means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.ig.answer",
                        defaultValue: "IG stands for Interstitial Glucose (tissue glucose). It refers to glucose values measured by a continuous glucose monitoring (CGM) (Sensor) sensor in the interstitial fluid and recorded as CGM (Sensor) samples in Apple Health. In GluVib, IG is displayed as soon as CGM (Sensor) values are available in Apple Health and is shown with visual context based on the configured thresholds and target range. All IG displays are based on the CGM (Sensor) data available in Apple Health and are presented for informational review.",
                        comment: "Answer explaining what IG means in the glossary"
                    )
                }
            }

            enum MovementSplit {
                static var question: String {
                    String(
                        localized: "faq.glossary.movement_split.question",
                        defaultValue: "What is the Movement Split?",
                        comment: "Question asking what the Movement Split means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.movement_split.answer",
                        defaultValue: "The Movement Split provides an analytical breakdown of how time within a day is distributed across different movement states, such as active time, sedentary time, and rest or sleep, based on the data available in Apple Health. Devices that continuously track movement, such as Apple Watch, typically provide more complete and granular activity data, while iPhone-only setups may result in less detailed coverage. This view is intended to provide contextual insight into daily activity patterns based solely on what is recorded in Apple Health.",
                        comment: "Answer explaining what the Movement Split means in the glossary"
                    )
                }
            }

            enum BMI {
                static var question: String {
                    String(
                        localized: "faq.glossary.bmi.question",
                        defaultValue: "What is Body Mass Index (BMI)?",
                        comment: "Question asking what BMI means in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.bmi.answer",
                        defaultValue: "Body Mass Index (BMI) is a descriptive metric that relates body weight to height and is commonly used as a standardized way to summarize body mass. In GluVib, BMI is calculated based on weight and height data available in Apple Health. If weight data is missing, BMI cannot be calculated or displayed. All BMI displays are derived from Apple Health data and are presented for informational analysis only.",
                        comment: "Answer explaining what BMI means in the glossary"
                    )
                }
            }

            enum ActiveVsNutritionEnergy {
                static var question: String {
                    String(
                        localized: "faq.glossary.active_vs_nutrition_energy.question",
                        defaultValue: "What is the difference between Active Energy and Nutrition Energy?",
                        comment: "Question asking about the difference between Active Energy and Nutrition Energy in the glossary"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.glossary.active_vs_nutrition_energy.answer",
                        defaultValue: "Active Energy refers to energy expenditure attributed to physical activity, as recorded in Apple Health. Nutrition Energy refers to energy intake recorded from nutrition entries. In GluVib, both metrics are displayed based on the data available in Apple Health and can be reviewed on a daily basis and across selectable time periods. Target values can be configured to provide context for charts and summaries, while the underlying Apple Health data remains unchanged.",
                        comment: "Answer explaining the difference between Active Energy and Nutrition Energy in the glossary"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Reports
        // ============================================================

        enum Reports {

            static var title: String {
                String(
                    localized: "faq.reports.title",
                    defaultValue: "Reports — GluVib Metabolic & Lifestyle Report",
                    comment: "Section title for the reports FAQ chapter"
                )
            }

            enum WhatIsReport {
                static var question: String {
                    String(
                        localized: "faq.reports.what_is_report.question",
                        defaultValue: "What is the GluVib Metabolic & Lifestyle Report?",
                        comment: "Question asking what the GluVib Metabolic & Lifestyle Report is"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.reports.what_is_report.answer",
                        defaultValue: "The GluVib Metabolic & Lifestyle Report is a Premium-only, printable and shareable PDF report designed for structured review of personal health data based on what is available in Apple Health. The report focuses primarily on metabolic analytics, including CGM (Sensor)-based glucose metrics and visualizations. Insulin-related analyses can be included when insulin data is available and enabled in Settings. The report is intended for informational and analytical purposes only and does not provide medical advice, diagnosis, or therapy recommendations.",
                        comment: "Answer explaining what the GluVib Metabolic & Lifestyle Report is"
                    )
                }
            }

            enum HowUsedAndShared {
                static var question: String {
                    String(
                        localized: "faq.reports.how_used_and_shared.question",
                        defaultValue: "How can the report be used and shared?",
                        comment: "Question asking how the report can be used and shared"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.reports.how_used_and_shared.answer",
                        defaultValue: "The GluVib Metabolic & Lifestyle Report can be exported as a PDF for printing or shared digitally. Because the report may contain sensitive personal health information, GluVib presents a confirmation step before export or sharing. All report content is derived from the data available in Apple Health and reflects the selected time period and enabled features at the time of generation.",
                        comment: "Answer explaining how the report can be used and shared"
                    )
                }
            }
        }

        // ============================================================
        // MARK: - Troubleshooting
        // ============================================================

        enum Troubleshooting {

            static var title: String {
                String(
                    localized: "faq.troubleshooting.title",
                    defaultValue: "Troubleshooting",
                    comment: "Section title for the troubleshooting FAQ chapter"
                )
            }

            enum ExclamationMarkMetric {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.exclamation_mark_metric.question",
                        defaultValue: "What does the exclamation mark (!) mean on a metric?",
                        comment: "Question asking what the exclamation mark means on a metric"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.exclamation_mark_metric.answer",
                        defaultValue: "The exclamation mark means GluVib currently cannot read that specific data type from Apple Health. Depending on where you see it, this can refer to data such as Steps (Activity), Sleep, Nutrition entries (Carbs/Protein/Fat/Energy), or Body metrics (Weight/BMI/Body Fat). It does not mean your values are “bad” — it only indicates that GluVib does not have permission to read that data type, or that access was later disabled in Apple Health / iOS settings.",
                        comment: "Answer explaining what the exclamation mark means on a metric"
                    )
                }
            }

            enum HideExclamationMarks {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.hide_exclamation_marks.question",
                        defaultValue: "Can I hide the exclamation marks?",
                        comment: "Question asking whether the exclamation marks can be hidden"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.hide_exclamation_marks.answer",
                        defaultValue: "Yes. You can turn off Permission Warnings in Settings. When disabled, GluVib will not show exclamation marks or permission warning messages. You can enable them again at any time, or review the Health permissions for GluVib in Apple Health / iOS settings.",
                        comment: "Answer explaining whether the exclamation marks can be hidden"
                    )
                }
            }

            enum MetricEmpty {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.metric_empty.question",
                        defaultValue: "Why is a metric empty?",
                        comment: "Question asking why a metric is empty"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.metric_empty.answer",
                        defaultValue: "A metric can be empty when Apple Health does not contain values for the selected period, when data is delayed, or when GluVib does not have permission to read that data type. GluVib does not generate or repair health data; it can only read and display what is available in Apple Health. If no data is present in Apple Health, GluVib cannot retrieve or present values for that metric. Some metrics also require a minimum amount of data coverage to produce meaningful summaries.",
                        comment: "Answer explaining why a metric is empty"
                    )
                }
            }

            enum DifferentValues {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.different_values.question",
                        defaultValue: "Why does GluVib show different values compared to another app?",
                        comment: "Question asking why GluVib can show different values compared to another app"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.different_values.answer",
                        defaultValue: "Differences can occur when data sources write values differently into Apple Health, when time windows or units differ, or when the data in Apple Health is incomplete or delayed. GluVib does not modify health data and can only display what is recorded in Apple Health, so the output reflects Apple Health’s available values and timestamps.",
                        comment: "Answer explaining why GluVib can show different values compared to another app"
                    )
                }
            }

            enum FeaturesNotVisible {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.features_not_visible.question",
                        defaultValue: "Why are some features or sections not visible?",
                        comment: "Question asking why some features or sections are not visible"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.features_not_visible.answer",
                        defaultValue: "Feature and section visibility depends on your access level (Free vs Premium), your Settings configuration, and whether relevant data exists in Apple Health. Metabolic sections require CGM (Sensor) data in Apple Health, and optional insulin-related views require insulin data plus the corresponding Settings status.",
                        comment: "Answer explaining why some features or sections are not visible"
                    )
                }
            }

            enum NoDataForToday {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.no_data_for_today.question",
                        defaultValue: "Why do I see a message saying “No data for today”?",
                        comment: "Question asking why the no data for today message appears"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.no_data_for_today.answer",
                        defaultValue: "This message means that GluVib has access to historical data for this metric, but no value has been recorded yet for today. This is common for metrics that depend on daily measurements or events, such as body metrics, nutrition entries, insulin doses, or resting heart rate. As soon as Apple Health receives a value for today, the message will disappear automatically.",
                        comment: "Answer explaining why the no data for today message appears"
                    )
                }
            }

            enum NoDataAtAll {
                static var question: String {
                    String(
                        localized: "faq.troubleshooting.no_data_at_all.question",
                        defaultValue: "Why do I see a message saying that no data is available at all?",
                        comment: "Question asking why the no data available at all message appears"
                    )
                }

                static var answer: String {
                    String(
                        localized: "faq.troubleshooting.no_data_at_all.answer",
                        defaultValue: "This message means that GluVib cannot find any usable data for this metric in Apple Health. This can happen if the metric has never been recorded, if the source app or device has not written or synced any values to Apple Health, or if GluVib does not have permission to read the required data type. Because GluVib only reads and displays data from Apple Health, metrics will remain empty if no relevant data is present there or if Apple Health access has been revoked.",
                        comment: "Answer explaining why the no data available at all message appears"
                    )
                }
            }
        }
    }
}
