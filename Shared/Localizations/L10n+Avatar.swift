//
//  L10n+Avatar.swift
//  GluVibProbe
//
//  Domain: Avatar / Account / Settings Helper Localization
//  Screen Type: Shared L10n Helper
//
//  Purpose
//  - Provides only supplementary helper keys for avatar/account/settings flows.
//  - Does NOT contain Privacy Policy localization helpers.
//  - Privacy texts are localized directly via the String Catalog in the corresponding view.
//
//  Data Flow (SSoT)
//  - SwiftUI View → L10n.Avatar helper → String Catalog
//
//  Key Connections
//  - AccountMenuSheetView
//  - AccountSettingsMenuView
//  - ManageAccountHomeView
//  - ActivitySettingsSection
//  - BodySettingsSection
//  - HelpAndFeedbackView
//  - AppInfoView
//  - MetabolicSettingsSection
//

import Foundation

extension L10n {

    enum Avatar {

        // ============================================================
        // MARK: - Status
        // ============================================================

        enum Status {

            static var premium: String {
                String(
                    localized: "avatar.status.premium",
                    defaultValue: "Premium",
                    comment: "Premium access status title in the avatar account menu sheet"
                )
            }

            static var free: String {
                String(
                    localized: "avatar.status.free",
                    defaultValue: "Free",
                    comment: "Free access status title in the avatar account menu sheet"
                )
            }

            static var unlockedOnThisDevice: String {
                String(
                    localized: "avatar.status.unlocked_on_this_device",
                    defaultValue: "Unlocked on this device",
                    comment: "Secondary premium status line in the avatar account menu sheet"
                )
            }

            static var active: String {
                String(
                    localized: "avatar.status.active",
                    defaultValue: "Active",
                    comment: "Secondary trial status line in the avatar account menu sheet"
                )
            }

            static var noActiveAccess: String {
                String(
                    localized: "avatar.status.no_active_access",
                    defaultValue: "No active access",
                    comment: "Secondary free status line in the avatar account menu sheet"
                )
            }

            static func trialDaysLeft(_ days: Int) -> String {
                String(
                    format: String(
                        localized: "avatar.status.trial_days_left",
                        defaultValue: "(%lld days left)",
                        comment: "Trial days remaining text in the avatar account menu sheet"
                    ),
                    locale: Locale.current,
                    days
                )
            }
        }

        // ============================================================
        // MARK: - Mode
        // ============================================================

        enum Mode {

            static var cgmOff: String {
                String(
                    localized: "avatar.mode.cgm_off",
                    defaultValue: "CGM Off",
                    comment: "Mode status line when CGM mode is disabled in the avatar account menu sheet"
                )
            }

            static var cgmOnInsulinOn: String {
                String(
                    localized: "avatar.mode.cgm_on_insulin_on",
                    defaultValue: "CGM On • Insulin On",
                    comment: "Mode status line when CGM and insulin mode are enabled in the avatar account menu sheet"
                )
            }

            static var cgmOnInsulinOff: String {
                String(
                    localized: "avatar.mode.cgm_on_insulin_off",
                    defaultValue: "CGM On • Insulin Off",
                    comment: "Mode status line when CGM is enabled and insulin mode is disabled in the avatar account menu sheet"
                )
            }
        }

        // ============================================================
        // MARK: - Menu
        // ============================================================

        enum Menu {

            static var frequentlyAskedQuestions: String {
                String(
                    localized: "avatar.menu.frequently_asked_questions",
                    defaultValue: "Frequently Asked Questions",
                    comment: "Menu item title for FAQs in the avatar account menu sheet"
                )
            }

            static var legalInformation: String {
                String(
                    localized: "avatar.menu.legal_information",
                    defaultValue: "Legal Information",
                    comment: "Menu item title for legal information in the avatar account menu sheet"
                )
            }

            static var appStatus: String {
                String(
                    localized: "avatar.menu.app_status",
                    defaultValue: "App Status",
                    comment: "Menu item title for app status in the account settings menu"
                )
            }

            static var units: String {
                String(
                    localized: "avatar.menu.units",
                    defaultValue: "Units",
                    comment: "Menu item title for units in the account settings menu"
                )
            }

            static var metabolicHome: String {
                String(
                    localized: "avatar.menu.metabolic_home",
                    defaultValue: "Metabolic (Home)",
                    comment: "Menu item title for metabolic home in settings view"
                )
            }
        }

        // ============================================================
        // MARK: - Common
        // ============================================================

        enum Common {

            static var saving: String {
                String(
                    localized: "avatar.common.saving",
                    defaultValue: "Saving…",
                    comment: "Intermediate save button title while settings are being saved"
                )
            }

            static var saved: String {
                String(
                    localized: "avatar.common.saved",
                    defaultValue: "Saved",
                    comment: "Temporary save button title after settings were saved"
                )
            }
        }

        // ============================================================
        // MARK: - Metabolic Settings
        // ============================================================

        enum MetabolicSettings {

            static var disclaimer: String {
                String(
                    localized: "avatar.metabolic_settings.disclaimer",
                    defaultValue: "These targets and thresholds are user-controlled settings and should be set only based on professional medical advice; GluVib is for informational purposes only and does not provide medical advice, diagnosis, or treatment.",
                    comment: "Disclaimer text shown at the top of metabolic settings"
                )
            }

            static var bolusPrimingThreshold: String {
                String(
                    localized: "avatar.metabolic_settings.bolus_priming_threshold",
                    defaultValue: "Bolus Priming Threshold",
                    comment: "Title of the bolus priming threshold sheet"
                )
            }

            static var basalPrimingThreshold: String {
                String(
                    localized: "avatar.metabolic_settings.basal_priming_threshold",
                    defaultValue: "Basal Priming Threshold",
                    comment: "Title of the basal priming threshold sheet"
                )
            }

            static func appliesToDosesAtMost(_ thresholdText: String) -> String {
                String(
                    localized: "avatar.metabolic_settings.applies_to_doses_at_most",
                    defaultValue: "Applies to doses ≤ %@.",
                    comment: "Hint text for priming threshold sheets"
                )
                .replacingOccurrences(of: "%@", with: thresholdText)
            }
        }

        // ============================================================
        // MARK: - Activity Settings
        // ============================================================

        enum ActivitySettings {

            static func stepsValue(_ value: Int) -> String {
                String(
                    format: String(
                        localized: "avatar.activity_settings.steps_value",
                        defaultValue: "%lld steps",
                        comment: "Formatted daily step target value in activity settings"
                    ),
                    locale: Locale.current,
                    value
                )
            }
        }

        // ============================================================
        // MARK: - Body Settings
        // ============================================================

        enum BodySettings {

            static func weightValue(_ value: Int, unit: String) -> String {
                String(
                    format: String(
                        localized: "avatar.body_settings.weight_value",
                        defaultValue: "%1$lld %2$@",
                        comment: "Formatted target weight value with localized unit in body settings"
                    ),
                    locale: Locale.current,
                    value,
                    unit
                )
            }

            static func sleepHoursOnly(_ hours: Int) -> String {
                String(
                    format: String(
                        localized: "avatar.body_settings.sleep_hours_only",
                        defaultValue: "%lld h",
                        comment: "Formatted sleep duration with hours only in body settings"
                    ),
                    locale: Locale.current,
                    hours
                )
            }

            static func sleepHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
                String(
                    format: String(
                        localized: "avatar.body_settings.sleep_hours_minutes",
                        defaultValue: "%1$lld h %2$lld min",
                        comment: "Formatted sleep duration with hours and minutes in body settings"
                    ),
                    locale: Locale.current,
                    hours,
                    minutes
                )
            }
        }

        // ============================================================
        // MARK: - Help & Feedback
        // ============================================================

        enum HelpFeedback {

            static var feedback: String {
                String(
                    localized: "avatar.help_feedback.category.feedback",
                    defaultValue: "Feedback",
                    comment: "Category title for feedback messages in help and feedback view"
                )
            }

            static var help: String {
                String(
                    localized: "avatar.help_feedback.category.help",
                    defaultValue: "Help",
                    comment: "Category title for help messages in help and feedback view"
                )
            }

            static var other: String {
                String(
                    localized: "avatar.help_feedback.category.other",
                    defaultValue: "Other",
                    comment: "Category title for other messages in help and feedback view"
                )
            }
        }

        // ============================================================
        // MARK: - App Info
        // ============================================================

        enum AppInfo {

            static var device: String {
                String(
                    localized: "avatar.app_info.device",
                    defaultValue: "Device",
                    comment: "Label for device information in app info view"
                )
            }

            static var system: String {
                String(
                    localized: "avatar.app_info.system",
                    defaultValue: "System",
                    comment: "Label for device information in app info view"
                )
            }
        }
    }
}
