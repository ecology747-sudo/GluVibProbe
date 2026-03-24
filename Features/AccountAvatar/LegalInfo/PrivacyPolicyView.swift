//
//  PrivacyPolicyView.swift
//  GluVibProbe
//
//  Domain: Privacy / Legal
//  Screen Type: Static Legal Detail View
//
//  Purpose
//  - Displays the in-app privacy policy.
//  - Uses a minimal block-based localization structure via L10n.Privacy.
//  - Keeps legal text maintainable without fine-grained fragmentation.
//
//  Data Flow (SSoT)
//  - PrivacyPolicyView -> L10n.Privacy -> String Catalog
//
//  Key Connections
//  - LegalInformationView
//  - L10n+Privacy.swift
//

import SwiftUI

struct PrivacyPolicyView: View {

    // MARK: - Styling

    // 🟨 UPDATED: switched to minimal block-based privacy localization
    private let titleColor: Color = Color.Glu.systemForeground

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // MARK: Header

                Text(L10n.Privacy.lastUpdated)
                    .font(.subheadline)
                    .foregroundStyle(titleColor.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.Privacy.hero)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                // MARK: Legal Contact

                sectionTitle(L10n.Privacy.contactTitle)

                VStack(alignment: .leading, spacing: 10) {

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Privacy.contactProjectName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(L10n.Privacy.contactOwner)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Privacy.contactAddressLabel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(titleColor)

                        Text(L10n.Privacy.contactAddressValue)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Privacy.contactEmailLabel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(titleColor)

                        Link(
                            L10n.Privacy.contactEmailValue,
                            destination: URL(string: "mailto:\(L10n.Privacy.contactEmailValue)")!
                        )
                        .font(.body)
                        .foregroundStyle(titleColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Privacy.contactHomepageLabel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(titleColor)

                        Link(
                            L10n.Privacy.contactHomepageValue,
                            destination: URL(string: "https://\(L10n.Privacy.contactHomepageValue)")!
                        )
                        .font(.body)
                        .foregroundStyle(titleColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Privacy.contactSupportLabel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(titleColor)

                        Link(
                            L10n.Privacy.contactSupportValue,
                            destination: URL(string: "mailto:\(L10n.Privacy.contactSupportValue)")!
                        )
                        .font(.body)
                        .foregroundStyle(titleColor)
                    }
                }

                // MARK: Main Policy Body

                Text(L10n.Privacy.body.replacingOccurrences(of: "\\n", with: "\n"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // MARK: Footer Reference

                Text(L10n.Privacy.policyURL)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Privacy.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }

    // MARK: - Local Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(titleColor)
            .padding(.top, 10)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PrivacyPolicyView") {
    NavigationStack {
        PrivacyPolicyView()
    }
}
#endif
