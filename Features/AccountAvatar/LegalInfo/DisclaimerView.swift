//
//  DisclaimerView.swift
//  GluVibProbe
//
//  Domain: Disclaimer / Legal
//  Screen Type: Static Legal Detail View
//
//  Purpose
//  - Displays the in-app disclaimer.
//  - Uses a minimal block-based localization structure via L10n.Disclaimer.
//  - Renders escaped line breaks from the String Catalog for long legal text blocks.
//
//  Data Flow (SSoT)
//  - DisclaimerView -> L10n.Disclaimer -> String Catalog
//
//  Key Connections
//  - LegalInformationView
//  - L10n+Disclaimer.swift
//

import SwiftUI

struct DisclaimerView: View {

    // MARK: - Styling

    // 🟨 UPDATED: switched to minimal block-based disclaimer localization
    private let titleColor: Color = Color.Glu.systemForeground

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text(
                    L10n.Disclaimer.body
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
                Text(L10n.Disclaimer.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DisclaimerView") {
    NavigationStack {
        DisclaimerView()
    }
}
#endif
