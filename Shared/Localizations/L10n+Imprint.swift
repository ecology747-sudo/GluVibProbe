//
//  L10n+Imprint.swift
//  GluVibProbe
//
//  Domain: Imprint / Legal
//  Screen Type: Localization Helper
//
//  Purpose
//  - Provides the localized strings for ImprintView.
//  - Keeps the imprint localized with a minimal structured setup.
//  - Preserves clickable provider fields separately where needed.
//
//  Data Flow (SSoT)
//  - ImprintView -> L10n.Imprint -> String Catalog
//
//  Key Connections
//  - ImprintView
//

import Foundation

extension L10n {

    enum Imprint {

        // MARK: - Title

        static var title: String {
            String(
                localized: "imprint.title",
                defaultValue: "Imprint",
                comment: "Navigation title of the imprint screen"
            )
        }

        // MARK: - Service Provider

        static var providerTitle: String {
            String(
                localized: "imprint.provider.title",
                defaultValue: "Service Provider",
                comment: "Section title for service provider information in the imprint"
            )
        }

        static var providerProjectName: String {
            String(
                localized: "imprint.provider.project_name",
                defaultValue: "ProjectVib",
                comment: "Project name shown in the imprint service provider section"
            )
        }

        static var providerOwner: String {
            String(
                localized: "imprint.provider.owner",
                defaultValue: "Owner: Mario Lorenz",
                comment: "Owner line shown in the imprint service provider section"
            )
        }

        static var providerAddressLabel: String {
            String(
                localized: "imprint.provider.address_label",
                defaultValue: "Address",
                comment: "Address label in the imprint service provider section"
            )
        }

        static var providerAddressValue: String {
            String(
                localized: "imprint.provider.address_value",
                defaultValue: "Zum Seeblick 11\n7083 Purbach am Neusiedler See\nAustria",
                comment: "Postal address shown in the imprint service provider section"
            )
        }

        static var providerEmailLabel: String {
            String(
                localized: "imprint.provider.email_label",
                defaultValue: "Email",
                comment: "Email label in the imprint service provider section"
            )
        }

        static var providerEmailValue: String {
            String(
                localized: "imprint.provider.email_value",
                defaultValue: "office@projectvib.com",
                comment: "Email address shown in the imprint service provider section"
            )
        }

        static var providerHomepageLabel: String {
            String(
                localized: "imprint.provider.homepage_label",
                defaultValue: "Homepage",
                comment: "Homepage label in the imprint service provider section"
            )
        }

        static var providerHomepageValue: String {
            String(
                localized: "imprint.provider.homepage_value",
                defaultValue: "www.projectvib.com",
                comment: "Homepage value shown in the imprint service provider section"
            )
        }

        static var providerSupportLabel: String {
            String(
                localized: "imprint.provider.support_label",
                defaultValue: "Support",
                comment: "Support label in the imprint service provider section"
            )
        }

        static var providerSupportValue: String {
            String(
                localized: "imprint.provider.support_value",
                defaultValue: "support@gluvib.com",
                comment: "Support email shown in the imprint service provider section"
            )
        }

        // MARK: - Body

        static var body: String { // 🟨 UPDATED
            String(
                localized: "imprint.body",
                defaultValue: """
                Nature of the Website / App

                GluVib is a digital consumer application for the visualization and analysis of personal health data.

                The content of this website and the app is provided for informational purposes only.

                EU Online Dispute Resolution

                The European Commission provides a platform for online dispute resolution (ODR):
                https://ec.europa.eu/consumers/odr

                We are not obligated and generally not willing to participate in dispute resolution proceedings before a consumer arbitration board.

                Liability for Content

                We make every effort to ensure that the information on this website is accurate and up to date. However, we do not guarantee the completeness, accuracy, or timeliness of the content.

                As a service provider, we are responsible for our own content in accordance with applicable laws. We are not obligated to monitor transmitted or stored third-party information or to investigate circumstances indicating illegal activity.

                Liability for Links

                This website may contain links to external third-party websites.

                We have no influence over the content of those websites and therefore cannot assume any liability for such external content. The respective provider or operator of linked sites is always responsible for their content.

                Intellectual Property

                All content, designs, logos, graphics, and software components of GluVib are protected by intellectual property laws. Any reproduction, distribution, or use beyond the limits of copyright law requires prior written consent.

                Trademark Notice

                Apple, Apple Health, HealthKit, iOS, and the Apple App Store are trademarks of Apple Inc. All other product names, trademarks, and registered trademarks are property of their respective owners. Use of these names does not imply affiliation, endorsement, or sponsorship.

                Professional Status

                GluVib is operated as an independent software project and is not affiliated with Apple Inc. or any medical device manufacturer.

                Contact

                For legal inquiries, please contact:
                support@gluvib.com
                """,
                comment: "Main imprint body text covering all sections below the service provider block"
            )
        }
    }
}
