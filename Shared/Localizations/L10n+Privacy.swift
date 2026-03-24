//
//  L10n+Privacy.swift
//  GluVibProbe
//
//  Domain: Privacy / Legal
//  Screen Type: Localization Helper
//
//  Purpose
//  - Provides the localized strings for PrivacyPolicyView.
//  - Keeps the privacy policy localized with a minimal block-based structure.
//  - Avoids fine-grained legal-text fragmentation.
//
//  Data Flow (SSoT)
//  - PrivacyPolicyView -> L10n.Privacy -> String Catalog
//
//  Key Connections
//  - PrivacyPolicyView
//

import Foundation

extension L10n {

    enum Privacy {

        // MARK: - Header

        static var title: String {
            String(
                localized: "privacy.title",
                defaultValue: "Privacy Policy",
                comment: "Navigation title of the privacy policy screen"
            )
        }

        static var lastUpdated: String {
            String(
                localized: "privacy.last_updated",
                defaultValue: "GluVib — Last updated: [02/26]",
                comment: "Last updated line at the top of the privacy policy"
            )
        }

        static var hero: String {
            String(
                localized: "privacy.hero",
                defaultValue: "GluVib is a read-only app for visualizing and summarizing health data stored in Apple Health. GluVib does not provide medical advice, diagnosis, or treatment. All processing happens locally on your device, and no health data is uploaded to external servers. Exception: if you manually add lab values (for example HbA1c), those entries are stored locally inside the app and are not synced to other devices via iCloud.",
                comment: "Hero intro text at the top of the privacy policy"
            )
        }

        // MARK: - Contact

        static var contactTitle: String {
            String(
                localized: "privacy.contact.title",
                defaultValue: "1. Data Controller",
                comment: "Title of the legal contact section in the privacy policy"
            )
        }

        static var contactProjectName: String {
            String(
                localized: "privacy.contact.project_name",
                defaultValue: "ProjectVib",
                comment: "Project name shown in the privacy contact section"
            )
        }

        static var contactOwner: String {
            String(
                localized: "privacy.contact.owner",
                defaultValue: "Owner: Mario Lorenz",
                comment: "Owner line shown in the privacy contact section"
            )
        }

        static var contactAddressLabel: String {
            String(
                localized: "privacy.contact.address_label",
                defaultValue: "Address",
                comment: "Address label in the privacy contact section"
            )
        }

        static var contactAddressValue: String {
            String(
                localized: "privacy.contact.address_value",
                defaultValue: "Zum Seeblick 11\n7083 Purbach am Neusiedler See\nAustria",
                comment: "Postal address shown in the privacy contact section"
            )
        }

        static var contactEmailLabel: String {
            String(
                localized: "privacy.contact.email_label",
                defaultValue: "Email",
                comment: "Email label in the privacy contact section"
            )
        }

        static var contactEmailValue: String {
            String(
                localized: "privacy.contact.email_value",
                defaultValue: "office@projectvib.com",
                comment: "Email address shown in the privacy contact section"
            )
        }

        static var contactHomepageLabel: String {
            String(
                localized: "privacy.contact.homepage_label",
                defaultValue: "Homepage",
                comment: "Homepage label in the privacy contact section"
            )
        }

        static var contactHomepageValue: String {
            String(
                localized: "privacy.contact.homepage_value",
                defaultValue: "www.projectvib.com",
                comment: "Homepage value shown in the privacy contact section"
            )
        }

        static var contactSupportLabel: String {
            String(
                localized: "privacy.contact.support_label",
                defaultValue: "Support",
                comment: "Support label in the privacy contact section"
            )
        }

        static var contactSupportValue: String {
            String(
                localized: "privacy.contact.support_value",
                defaultValue: "support@gluvib.com",
                comment: "Support email shown in the privacy contact section"
            )
        }

        // MARK: - Body

        static var body: String { // 🟨 UPDATED
            String(
                localized: "privacy.body",
                defaultValue: """
                2. About GluVib

                GluVib visualizes and summarizes health information stored in Apple Health. The app is designed for clarity and personal review — it is read-only by design.

                GluVib is not a medical device and does not replace professional advice. Any interpretation of charts and metrics remains your responsibility.

                Apple Health is the primary source of truth for GluVib. If data is missing or delayed in Apple Health, it may also be missing or delayed in GluVib. Exception: manually entered lab values (for example HbA1c) are stored locally inside the app and do not originate from Apple Health.

                3. Categories of Data Processed

                With your explicit permission through Apple Health, GluVib may access and process the following data types (depending on what exists in Apple Health and what you allow):

                • Activity data (e.g., steps, workout minutes, energy expenditure)
                • Nutrition data (e.g., carbohydrates, protein, fat, calories)
                • Body data (e.g., weight, sleep, body fat, BMI, resting heart rate)
                • Glucose data from continuous glucose monitoring systems (if available in Apple Health)
                • Insulin entries stored in Apple Health (if available)

                In addition, you may optionally enter lab values (for example HbA1c) manually inside the app. These entries are stored locally on your device and are not written to Apple Health.

                This information qualifies as health data and is considered a special category of personal data under Article 9 GDPR (where applicable).

                4. Legal Basis for Processing (EU/EEA)

                For users in the European Union (EU) and European Economic Area (EEA), processing is based on:

                • Article 6(1)(a) GDPR — Consent
                • Article 9(2)(a) GDPR — Explicit consent for processing health data

                Consent is granted through Apple Health permission dialogs. You can withdraw consent at any time by revoking permissions in:

                Settings → Privacy & Security → Health → GluVib

                5. Purpose of Processing

                Your data is processed solely for:

                • Visualizing health information
                • Displaying charts and dashboards
                • Calculating aggregated summaries
                • Providing structured summaries and insights for your personal review

                No automated decision-making or profiling under Article 22 GDPR takes place.

                GluVib does not use health data for marketing, advertising, or secondary purposes.

                6. Local Processing & No Data Transfer

                All processing occurs locally on your device.

                • GluVib does not upload health data to servers
                • GluVib does not use cloud storage for health data
                • GluVib does not transmit health data to third parties
                • GluVib does not sell personal data
                • GluVib does not use advertising SDKs
                • No cross-border or third-country transfer of health data

                If you manually add lab values (for example HbA1c), those entries are stored locally inside the app and are not synced to other devices via iCloud.

                7. Premium Features

                Some features may be available as Premium functionality.

                • Upgrading to Premium does not change data processing practices
                • Premium does not introduce cloud storage
                • Premium does not involve additional data sharing

                Premium only unlocks additional in-app visualizations and summaries.

                8. Data Retention

                GluVib does not maintain external databases.

                Health data remains in Apple Health or may be temporarily cached locally within the app to improve performance and usability.

                Deleting the app removes locally stored app data, including any manually entered lab values.

                9. Your Rights (EU/EEA Users)

                Under GDPR, you have the right to:

                • Access (Art. 15)
                • Rectification (Art. 16)
                • Erasure (Art. 17)
                • Restriction of processing (Art. 18)
                • Data portability (Art. 20)
                • Withdraw consent at any time

                You also have the right to lodge a complaint with a supervisory authority in your country of residence.

                10. No Tracking & No Marketing

                • GluVib does not track users across apps or websites
                • GluVib does not build marketing profiles
                • GluVib does not use health data for advertising
                • GluVib does not combine health data with third-party systems

                11. Security

                Data processing occurs entirely within Apple’s secure iOS and HealthKit frameworks. GluVib does not operate external infrastructure for health data.

                12. Changes to This Policy

                We may update this Privacy Policy to reflect legal, technical, or operational changes. The latest version will always be available on this page.
                """,
                comment: "Main privacy policy body text covering sections 2 through 12"
            )
        }

        static var policyURL: String {
            String(
                localized: "privacy.policy_url",
                defaultValue: "Policy URL (for reference): https://gluvib.com/privacy",
                comment: "Reference policy URL shown at the bottom of the privacy policy"
            )
        }
    }
}
