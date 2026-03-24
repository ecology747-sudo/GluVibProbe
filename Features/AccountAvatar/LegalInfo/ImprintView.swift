//
//  ImprintView.swift
//  GluVibProbe
//
//  Domain: Imprint / Legal
//  Screen Type: Static Legal Detail View
//
//  Purpose
//  - Displays the in-app imprint.
//  - Uses a minimal localization structure via L10n.Imprint.
//  - Keeps the service provider block separate for clickable fields.
//  - Renders escaped line breaks from the String Catalog for the long imprint body.
//
//  Data Flow (SSoT)
//  - ImprintView -> L10n.Imprint -> String Catalog
//
//  Key Connections
//  - LegalInformationView
//  - L10n+Imprint.swift
//

import SwiftUI

struct ImprintView: View {

    // MARK: - Styling

    // 🟨 UPDATED: switched to minimal imprint localization with one shared body block
    private let titleColor: Color = Color.Glu.systemForeground

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // MARK: Service Provider

                Group {
                    sectionTitle(L10n.Imprint.providerTitle)

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Imprint.providerProjectName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(L10n.Imprint.providerOwner)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Imprint.providerAddressLabel)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(titleColor)

                            Text(L10n.Imprint.providerAddressValue)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Imprint.providerEmailLabel)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(titleColor)

                            Link(
                                L10n.Imprint.providerEmailValue,
                                destination: URL(string: "mailto:\(L10n.Imprint.providerEmailValue)")!
                            )
                            .font(.body)
                            .foregroundStyle(titleColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Imprint.providerHomepageLabel)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(titleColor)

                            Link(
                                L10n.Imprint.providerHomepageValue,
                                destination: URL(string: "https://\(L10n.Imprint.providerHomepageValue)")!
                            )
                            .font(.body)
                            .foregroundStyle(titleColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Imprint.providerSupportLabel)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(titleColor)

                            Link(
                                L10n.Imprint.providerSupportValue,
                                destination: URL(string: "mailto:\(L10n.Imprint.providerSupportValue)")!
                            )
                            .font(.body)
                            .foregroundStyle(titleColor)
                        }
                    }
                }

                Divider().padding(.vertical, 8)

                // MARK: Main Body

                Text(
                    L10n.Imprint.body
                        .replacingOccurrences(of: "\\n", with: "\n")
                )
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L10n.Imprint.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }

    // MARK: - Local Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(titleColor)
            .padding(.bottom, 2)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ImprintView") {
    NavigationStack {
        ImprintView()
    }
}
#endif
