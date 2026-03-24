//
//  L10n+Terms.swift
//  GluVibProbe
//
//  Domain: Terms / Legal
//  Screen Type: Localization Helper
//
//  Purpose
//  - Provides the localized strings for TermsOfServiceView.
//  - Keeps the terms localized with a minimal block-based structure.
//  - Avoids unnecessary legal-text fragmentation.
//
//  Data Flow (SSoT)
//  - TermsOfServiceView -> L10n.Terms -> String Catalog
//
//  Key Connections
//  - TermsOfServiceView
//

import Foundation

extension L10n {

    enum Terms {

        // MARK: - Header

        static var title: String {
            String(
                localized: "terms.title",
                defaultValue: "Terms",
                comment: "Navigation title of the terms of service screen"
            )
        }

        static var lastUpdated: String {
            String(
                localized: "terms.last_updated",
                defaultValue: "GluVib — Last updated: [02/2026]",
                comment: "Last updated line at the top of the terms screen"
            )
        }

        // MARK: - Body

        static var body: String { // 🟨 UPDATED
            String(
                localized: "terms.body",
                defaultValue: """
                1. Acceptance of Terms

                By downloading, installing, or using GluVib (the “App”), you agree to be bound by these Terms of Service (“Terms”). If you do not agree to these Terms, do not use the App.

                These Terms constitute a legally binding agreement between you and:

                GluVib (“we”, “us”, or “Developer”)



                2. Description of the App

                GluVib is a read-only health data visualization application.

                The App:
                • Displays health information stored in Apple Health
                • Provides dashboards, charts, and calculated summaries
                • Processes data locally on the device
                • Does not modify Apple Health data
                • Does not provide medical advice

                Most information shown in the App is based on data available in Apple Health. Exception: if you manually add lab values (for example HbA1c), those entries are stored locally inside the App, are not synced to other devices via iCloud, and are removed if the App is uninstalled.

                GluVib is not a medical device and is not certified under any medical regulatory framework.



                3. Eligibility

                You must be at least 16 years old (or the legal age in your jurisdiction) to use the App.

                If you are under the age of majority, you must have parental or guardian consent.



                4. License Grant

                We grant you a limited, non-exclusive, non-transferable, revocable license to use GluVib for personal, non-commercial purposes, subject to these Terms.

                You may not:
                • Reverse engineer the App
                • Modify or create derivative works
                • Resell or redistribute the App
                • Use the App for unlawful purposes

                All rights not expressly granted remain reserved.



                5. Free Trial & Subscription Model

                5.1 30-Day Trial
                After installation, users may access the full feature set of GluVib for a 30-day trial period.

                At the end of the trial:
                • Certain advanced features (including metabolic views) may become restricted
                • Core free functionality remains available

                5.2 Premium Subscription
                Premium access is available via subscription through the Apple App Store.

                All purchases, billing, renewals, and cancellations are handled exclusively by Apple. We do not process payments directly.

                5.3 Auto-Renewal
                Subscriptions may automatically renew unless canceled through your Apple account settings. You are responsible for managing your subscription via Apple.

                5.4 Refunds
                Refunds are governed solely by Apple’s policies. We do not issue direct refunds.



                6. No Medical Advice

                The App is provided for informational purposes only. It does not:
                • Provide diagnosis
                • Provide treatment recommendations
                • Determine insulin dosage
                • Replace medical consultation

                You acknowledge that medical decisions must be made in consultation with a licensed healthcare professional. See also our separate Medical Disclaimer.



                7. No Warranty

                The App is provided “as is” and “as available”.

                To the maximum extent permitted by law, we disclaim all warranties, whether express or implied, including:
                • Accuracy of displayed data
                • Fitness for a particular purpose
                • Uninterrupted availability
                • Error-free performance

                We do not guarantee that the App will meet your expectations.



                8. Limitation of Liability

                To the maximum extent permitted by law:

                We shall not be liable for:
                • Direct or indirect damages
                • Incidental or consequential damages
                • Loss of data
                • Health-related decisions made based on App content
                • Inaccurate or delayed Apple Health data

                Use of the App is at your own risk.

                Nothing in these Terms excludes liability that cannot legally be excluded.



                9. Data Accuracy

                GluVib relies primarily on data provided via Apple Health. Exception: manually entered lab values (for example HbA1c) are stored locally inside the App, are not synced to other devices via iCloud, and are removed if the App is uninstalled.

                We do not:
                • Verify medical correctness
                • Validate device calibration
                • Guarantee completeness of imported data

                You are responsible for reviewing and validating your data.



                10. Intellectual Property

                All content within the App, including design, visual structure, logos, branding, charts, and software code, is the intellectual property of the Developer unless otherwise stated.

                You may not copy, distribute, or exploit any part of the App without prior written consent.



                11. Trademarks

                Apple, Apple Health, HealthKit, iOS, and the Apple App Store are trademarks of Apple Inc.

                Any other referenced brand names or trademarks belong to their respective owners. Use of such names does not imply affiliation, endorsement, or sponsorship.



                12. Third-Party Services

                The App integrates with Apple Health and relies on Apple’s infrastructure.

                We are not responsible for:
                • Apple service interruptions
                • HealthKit inaccuracies
                • Third-party device synchronization delays



                13. Termination

                We reserve the right to suspend or terminate access to the App if you violate these Terms.

                You may stop using the App at any time by uninstalling it.

                If you uninstall the App, any manually entered lab values stored locally inside the App will be removed.

                Subscription cancellation must be handled via Apple.



                14. Governing Law

                These Terms shall be governed by the laws of the Developer’s country of residence, without regard to conflict of law principles.

                If you are a consumer residing in the EU, mandatory consumer protection laws of your country remain unaffected.



                15. Severability

                If any provision of these Terms is found invalid or unenforceable, the remaining provisions remain in effect.



                16. Changes to These Terms

                We may update these Terms to reflect legal or functional changes. The latest version will always be available on this page.

                Continued use of the App constitutes acceptance of the updated Terms.

                Terms URL (for reference): https://gluvib.com/terms
                """,
                comment: "Main terms of service body text shown in the terms screen"
            )
        }
    }
}
