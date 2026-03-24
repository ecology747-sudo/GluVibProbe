//
//  L10n+Onboarding.swift
//  GluVib
//

import Foundation

extension L10n {

    enum OnboardingFlow {

        // MARK: - General

        static var appSetupTitle: String {
            String(
                localized: "onboarding.flow.app_setup_title",
                defaultValue: "GluVib App Setup",
                comment: "Main title on the onboarding flow screen"
            )
        }

        static func stepCounter(_ current: Int, _ total: Int) -> String {
            String(
                localized: "onboarding.flow.step_counter",
                defaultValue: "Step \(current) of \(total)",
                comment: "Step counter in onboarding flow"
            )
        }

      

        // MARK: - Acknowledgement Alert

        static var acknowledgementRequiredTitle: String {
            String(
                localized: "onboarding.flow.acknowledgement_required.title",
                defaultValue: "Acknowledgement required",
                comment: "Title of the alert shown when disclaimer acknowledgement is denied"
            )
        }

        static var acknowledgementRequiredMessage: String {
            String(
                localized: "onboarding.flow.acknowledgement_required.message",
                defaultValue: "To use GluVib, you must acknowledge the informational-only disclaimer. Without acknowledgement, setup cannot be continued.",
                comment: "Message of the alert shown when disclaimer acknowledgement is denied"
            )
        }

        static var openDisclaimer: String {
            String(
                localized: "onboarding.flow.acknowledgement_required.open_disclaimer",
                defaultValue: "Open Disclaimer",
                comment: "Button title to open disclaimer from onboarding acknowledgement alert"
            )
        }

        static var openPrivacyPolicy: String {
            String(
                localized: "onboarding.flow.acknowledgement_required.open_privacy_policy",
                defaultValue: "Open Privacy Policy",
                comment: "Button title to open privacy policy from onboarding acknowledgement alert"
            )
        }

        static var openTerms: String {
            String(
                localized: "onboarding.flow.acknowledgement_required.open_terms",
                defaultValue: "Open Terms",
                comment: "Button title to open terms from onboarding acknowledgement alert"
            )
        }

        static var ok: String {
            String(
                localized: "onboarding.flow.common.ok",
                defaultValue: "OK",
                comment: "Generic OK button title in onboarding flow"
            )
        }

        // MARK: - Sensor Visibility Step

        static var sensorVisibilityTitle: String {
            String(
                localized: "onboarding.flow.sensor_visibility.title",
                defaultValue: "Show sensor (CGM) data",
                comment: "Title for the sensor visibility onboarding step"
            )
        }

        static var sensorVisibilityBody: String {
            String(
                localized: "onboarding.flow.sensor_visibility.body",
                defaultValue: "This enables visibility of sensor-based data dashboards and charts. Sensor values can only be shown if compatible sensor data is available in Apple Health. You can change this anytime in the settings.",
                comment: "Description text for the sensor visibility onboarding step"
            )
        }

        static var showSensorData: String {
            String(
                localized: "onboarding.flow.sensor_visibility.show_button",
                defaultValue: "Show sensor data",
                comment: "Primary action button title for enabling sensor data visibility in onboarding"
            )
        }

        static var doNotShowSensorData: String {
            String(
                localized: "onboarding.flow.sensor_visibility.hide_button",
                defaultValue: "Do not show sensor data",
                comment: "Secondary action button title for disabling sensor data visibility in onboarding"
            )
        }

        // MARK: - Insulin Visibility Step

        static var insulinVisibilityTitle: String {
            String(
                localized: "onboarding.flow.insulin_visibility.title",
                defaultValue: "Show insulin data",
                comment: "Title for the insulin visibility onboarding step"
            )
        }

        static var insulinVisibilityBody: String {
            String(
                localized: "onboarding.flow.insulin_visibility.body",
                defaultValue: "This enables visibility of insulin-related metrics and stats. Insulin values can only be shown if insulin delivery data is available in Apple Health. You can change this anytime in the settings.",
                comment: "Description text for the insulin visibility onboarding step"
            )
        }

        static var showInsulinData: String {
            String(
                localized: "onboarding.flow.insulin_visibility.show_button",
                defaultValue: "Show insulin data",
                comment: "Primary action button title for enabling insulin data visibility in onboarding"
            )
        }

        static var doNotShowInsulinData: String {
            String(
                localized: "onboarding.flow.insulin_visibility.hide_button",
                defaultValue: "Do not show insulin data",
                comment: "Secondary action button title for disabling insulin data visibility in onboarding"
            )
        }

        // MARK: - Apple Health Permission Step

        static var healthPermissionTitle: String {
            String(
                localized: "onboarding.flow.health_permission.title",
                defaultValue: "Connect Apple Health",
                comment: "Title for the Apple Health permission onboarding step"
            )
        }

        static var healthPermissionBody: String {
            String(
                localized: "onboarding.flow.health_permission.body",
                defaultValue: "GluVib needs permissions to read your Apple Health data. If you skip this step for now, the app will show empty stats until permissions are granted.",
                comment: "Description text for the Apple Health permission onboarding step"
            )
        }

        static var connectAppleHealth: String {
            String(
                localized: "onboarding.flow.health_permission.connect_button",
                defaultValue: "Connect Apple Health",
                comment: "Primary action button title for starting Apple Health authorization in onboarding"
            )
        }

        static var waitingForAppleHealth: String {
            String(
                localized: "onboarding.flow.health_permission.waiting_button",
                defaultValue: "Waiting for Apple Health...",
                comment: "Button title shown while Apple Health authorization is in progress during onboarding"
            )
        }

        static var skipForNow: String {
            String(
                localized: "onboarding.flow.health_permission.skip_button",
                defaultValue: "Skip for now",
                comment: "Secondary action button title for skipping Apple Health authorization in onboarding"
            )
        }

        // MARK: - Ready Step

        static var readyTitle: String {
            String(
                localized: "onboarding.flow.ready.title",
                defaultValue: "Congratulations!",
                comment: "Title for the final ready step in onboarding"
            )
        }

        static var readyBody: String {
            String(
                localized: "onboarding.flow.ready.body",
                defaultValue: "GluVib is now fully set up and ready for you to explore. Experience your free 30-day trial with access to all features. You can personalize units, goals, and visibility anytime in the settings. If you have feedback, we’d love to hear it. Enjoy your journey! Your Team GluVib!",
                comment: "Description text for the final ready step in onboarding"
            )
        }

        static var exploreNow: String {
            String(
                localized: "onboarding.flow.ready.explore_button",
                defaultValue: "Explore GluVib now",
                comment: "Primary action button title for finishing onboarding and entering the app"
            )
        }
    }

    enum OnboardingDisclaimer {

        // MARK: - Titles & Body

        static var welcomeTitle: String {
            String(
                localized: "onboarding.disclaimer.welcome_title",
                defaultValue: "Welcome to GluVib",
                comment: "Title on the disclaimer step during onboarding"
            )
        }

        static var welcomeBody: String {
            String(
                localized: "onboarding.disclaimer.welcome_body",
                defaultValue: "GluVib is a read-only health data visualization application. It is intended strictly and only for informational purposes and does not provide medical advice, diagnosis, or treatment recommendations. Neither it is a medical device or substitutes medical treatment. Always consult a qualified healthcare professional for diagnosis and treatment options.",
                comment: "Main disclaimer text block shown during onboarding"
            )
        }

        static var moreInformation: String {
            String(
                localized: "onboarding.disclaimer.more_information",
                defaultValue: "For more information please visit our:",
                comment: "Helper text above legal links in disclaimer onboarding step"
            )
        }

        // MARK: - Links

        static var disclaimerLink: String {
            String(
                localized: "onboarding.disclaimer.link.disclaimer",
                defaultValue: "Disclaimer",
                comment: "Link title for disclaimer in onboarding disclaimer step"
            )
        }

        static var privacyPolicyLink: String {
            String(
                localized: "onboarding.disclaimer.link.privacy_policy",
                defaultValue: "Privacy Policy",
                comment: "Link title for privacy policy in onboarding disclaimer step"
            )
        }

        static var termsLink: String {
            String(
                localized: "onboarding.disclaimer.link.terms",
                defaultValue: "Terms",
                comment: "Link title for terms in onboarding disclaimer step"
            )
        }

        // MARK: - Actions

        static var accept: String {
            String(
                localized: "onboarding.disclaimer.accept",
                defaultValue: "I understand & accept",
                comment: "Primary action button title for accepting the disclaimer during onboarding"
            )
        }

        static var deny: String {
            String(
                localized: "onboarding.disclaimer.deny",
                defaultValue: "Deny",
                comment: "Secondary action button title for denying the disclaimer during onboarding"
            )
        }
    }
}
