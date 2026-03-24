//
//  LegalInformationView.swift
//  GluVibProbe
//
//  Settings / Account — Legal Hub
//  Purpose:
//  - Provides navigation to static legal subviews.
//  - Read-only legal entry screen without HealthStore or Settings writes.
//
//  Data Flow (SSoT):
//  - Static navigation only -> LegalInformationView -> legal detail screens
//
//  Key Connections:
//  - PrivacyPolicyView
//  - DisclaimerView
//  - TermsOfServiceView
//  - ImprintView
//

import SwiftUI

struct LegalInformationView: View {

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let iconColumnWidth: CGFloat = 34 // 🟨 UPDATED

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    rowLabel(
                        title: String(
                            localized: "Privacy Policy",
                            defaultValue: "Privacy Policy",
                            comment: "Row title for privacy policy in legal information view"
                        ),
                        systemImage: "hand.raised"
                    )
                }

                NavigationLink {
                    DisclaimerView()
                } label: {
                    rowLabel(
                        title: String(
                            localized: "Disclaimer",
                            defaultValue: "Disclaimer",
                            comment: "Row title for disclaimer in legal information view"
                        ),
                        systemImage: "graduationcap"
                    )
                }

                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    rowLabel(
                        title: String(
                            localized: "Terms",
                            defaultValue: "Terms",
                            comment: "Row title for terms of service in legal information view"
                        ),
                        systemImage: "doc.text"
                    )
                }

                NavigationLink {
                    ImprintView()
                } label: {
                    rowLabel(
                        title: String(
                            localized: "Imprint",
                            defaultValue: "Imprint",
                            comment: "Row title for imprint in legal information view"
                        ),
                        systemImage: "building.columns"
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(
                    String(
                        localized: "Legal",
                        defaultValue: "Legal",
                        comment: "Navigation title for legal information view"
                    )
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    private func rowLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: iconColumnWidth, alignment: .leading) // 🟨 UPDATED

            Text(title)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .foregroundStyle(titleColor)
        .accessibilityLabel(title)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#if DEBUG
#Preview("LegalInformationView") {
    NavigationStack {
        LegalInformationView()
    }
}
#endif
