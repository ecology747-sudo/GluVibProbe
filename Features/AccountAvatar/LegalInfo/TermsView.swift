//
//  TermsOfServiceView.swift
//  GluVibProbe
//
//  Domain: Terms / Legal
//  Screen Type: Static Legal Detail View
//
//  Purpose
//  - Displays the in-app terms of service.
//  - Uses a minimal block-based localization structure via L10n.Terms.
//  - Renders escaped line breaks from the String Catalog for long legal text blocks.
//
//  Data Flow (SSoT)
//  - TermsOfServiceView -> L10n.Terms -> String Catalog
//
//  Key Connections
//  - LegalInformationView
//  - L10n+Terms.swift
//

import SwiftUI

struct TermsOfServiceView: View {

    // MARK: - Styling

    // 🟨 UPDATED: switched to minimal block-based terms localization
    private let titleColor: Color = Color.Glu.systemForeground

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text(L10n.Terms.lastUpdated)
                    .font(.subheadline)
                    .foregroundStyle(titleColor.opacity(0.72))
                    .padding(.bottom, 6)

                Text(
                    L10n.Terms.body
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
                Text(L10n.Terms.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("TermsOfServiceView") {
    NavigationStack {
        TermsOfServiceView()
    }
}
#endif
