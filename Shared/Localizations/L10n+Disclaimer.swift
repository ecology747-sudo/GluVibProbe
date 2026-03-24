//
//  L10n+Disclaimer.swift
//  GluVibProbe
//
//  Domain: Disclaimer / Legal
//  Screen Type: Localization Helper
//
//  Purpose
//  - Provides the localized strings for DisclaimerView.
//  - Keeps the disclaimer localized with a minimal block-based structure.
//  - Avoids unnecessary legal-text fragmentation.
//
//  Data Flow (SSoT)
//  - DisclaimerView -> L10n.Disclaimer -> String Catalog
//
//  Key Connections
//  - DisclaimerView
//

import Foundation

extension L10n {

    enum Disclaimer {

        // MARK: - Header

        static var title: String {
            String(
                localized: "disclaimer.title",
                defaultValue: "Disclaimer",
                comment: "Navigation title of the disclaimer screen"
            )
        }

        // MARK: - Body

        static var body: String { // 🟨 UPDATED
            String(
                localized: "disclaimer.body",
                defaultValue: """
                GluVib — Last updated: [02/26]

                GluVib is a read-only health data visualization application. It is intended for informational purposes only and does not provide medical advice, diagnosis, or treatment. Most information shown in the app is based on data available in Apple Health. Exception: if you manually add lab values (for example HbA1c), those entries are stored locally inside the app, are not synced to other devices via iCloud, and are removed if the app is uninstalled.

                1. Informational Purpose Only
                The app is designed solely to:
                • Display health information stored in Apple Health and, if provided, locally stored lab values you enter in the app
                • Provide structured dashboards and summaries
                • Visualize trends and aggregated metrics
                • Support personal data awareness
                GluVib is intended for informational purposes only. It does not provide medical advice.

                2. No Medical Advice
                The information presented in GluVib:
                • Is not medical advice
                • Is not a diagnosis
                • Is not a treatment recommendation
                • Is not a substitute for professional medical consultation
                All charts, summaries, ratios, and calculated values are mathematical representations of data already stored in Apple Health or manually entered in the app (where applicable). They are not clinical interpretations.
                Always consult a qualified healthcare professional regarding medical decisions.

                3. No Clinical Decision Support
                GluVib is not a clinical decision support system. It is not designed to:
                • Determine insulin dosage
                • Adjust therapy plans
                • Predict medical outcomes
                • Replace CGM manufacturer software
                • Replace physician-supervised review
                Any health-related decisions must be made in consultation with a licensed medical professional.

                4. No Real-Time Medical Monitoring
                If you use a Continuous Glucose Monitor (CGM), please note:
                • GluVib displays glucose values as available in Apple Health
                • Data availability may be delayed depending on the CGM provider
                • GluVib does not guarantee real-time accuracy
                The app is not an emergency monitoring system.
                GluVib must not be used for urgent medical situations.
                In case of a medical emergency, contact local emergency services immediately.

                5. Data Accuracy & Responsibility
                GluVib relies primarily on data provided through Apple Health. Exception: manually entered lab values (for example HbA1c) are stored locally inside the app, are not synced to other devices via iCloud, and are removed if the app is uninstalled. The app:
                • Does not verify data correctness
                • Does not validate medical accuracy
                • Does not detect incorrect entries
                • Does not monitor device calibration
                Data quality depends on:
                • Third-party devices
                • Manual entries
                • Apple Health synchronization
                Incorrect or incomplete data may result in misleading visualizations.
                Users are responsible for reviewing data accuracy.

                6. No Doctor–Patient Relationship
                Use of GluVib does not establish:
                • A doctor–patient relationship
                • A therapeutic relationship
                • A clinical monitoring agreement
                The app developer is not acting as a healthcare provider.

                7. Not a Medical Device
                GluVib is not certified as a medical device.
                It is not approved under:
                • EU Medical Device Regulation (MDR)
                • FDA medical device regulations
                • Any comparable regulatory framework
                It is a consumer information tool.

                8. Use at Your Own Risk
                By using GluVib, you acknowledge that:
                • You understand its informational nature
                • You will not rely solely on the app for medical decisions
                • You accept responsibility for any actions taken based on displayed information

                9. Professional Consultation Recommended
                If you:
                • Have diabetes
                • Use insulin
                • Monitor glucose levels
                • Experience abnormal readings
                • Have concerns about health metrics
                You should seek professional medical advice from a licensed healthcare provider.

                10. Changes to This Disclaimer
                This disclaimer may be updated to reflect regulatory or functional changes. The latest version will always be available on this page.

                Disclaimer URL (for reference): https://gluvib.com/disclaimer
                """,
                comment: "Main disclaimer body text shown in the disclaimer screen"
            )
        }
    }
}
