//
//  ManageAccountHomeView.swift
//  GluVibProbe
//

import SwiftUI

struct ManageAccountHomeView: View {

    @EnvironmentObject private var settings: SettingsModel

    // MARK: - Style

    private let titleColor: Color = Color.Glu.primaryBlue
    private let captionColor: Color = Color.Glu.primaryBlue.opacity(0.7)

    // MARK: - Copy (avoid type-check blowups)

    private let explanationText: String = """
    Analyzing continuous glucose monitoring (CGM) data requires additional app functionality.
    These features will be offered as an optional in-app purchase at a later stage.

    Until then, you can freely explore the app, review its structure, and become familiar with the available insights.
    There are currently no charges and no obligations.
    """

    // MARK: - Status logic

    private var isPremiumUser: Bool { settings.hasCGM }

    private var statusTitle: String { isPremiumUser ? "Premium" : "Free" }

    private var statusIcon: String { isPremiumUser ? "crown.fill" : "sparkles" }

    private var statusIconColor: Color {
        isPremiumUser ? .yellow : Color.Glu.acidCGMRed   // UPDATED
    }

    private var insulinStatus: String {
        "Insulin Status: \(settings.isInsulinTreated ? "On" : "Off")"
    }

    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ====================================================
                // MARK: - CURRENT APP STATUS (centered)
                // ====================================================

                VStack(spacing: 10) {

                    HStack(spacing: 10) {
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundStyle(statusIconColor)

                        Text(statusTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(titleColor)
                    }

                    if isPremiumUser {
                        Text(insulinStatus)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(titleColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                // --- EXTRA SPACE before Metabolic Access  // UPDATED
                Spacer(minLength: 12)

                // ====================================================
                // MARK: - METABOLIC ACCESS (title + PREMIUM BADGE)
                // ====================================================

                HStack {
                    Text("Metabolic Access")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(titleColor)

                    Spacer()

                    premiumOnlyBadge
                }

                // ====================================================
                // MARK: - METABOLIC ACCESS CARD
                // ====================================================

                VStack(spacing: 16) {

                    Toggle(isOn: $settings.hasCGM) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CGM sensor available")
                                .font(.headline)
                                .foregroundStyle(titleColor)

                            Text("Enable if your glucose is tracked continuously via a sensor.")
                                .font(.caption)
                                .foregroundStyle(captionColor)
                        }
                    }
                    .tint(Color.Glu.metabolicDomain)

                    Divider()

                    Toggle(isOn: $settings.isInsulinTreated) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insulin therapy")
                                .font(.headline)
                                .foregroundStyle(titleColor)

                            Text("Enable if you regularly use insulin (Bolus and/or Basal).")
                                .font(.caption)
                                .foregroundStyle(captionColor)

                            if !settings.hasCGM {
                                Text("Insulin metrics require CGM mode enabled.")
                                    .font(.caption)
                                    .foregroundStyle(captionColor)
                            }
                        }
                    }
                    .tint(Color.Glu.metabolicDomain)
                    .disabled(!settings.hasCGM)

                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )

                // ====================================================
                // MARK: - EXPLANATION
                // ====================================================

                Text(explanationText)
                    .font(.footnote)
                    .foregroundStyle(captionColor)
                    .lineSpacing(2)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
        }
        .background(Color("GluSoftGray"))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Manage App Status")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
        .onChange(of: settings.hasCGM) { newValue in
            if newValue == false {
                settings.isInsulinTreated = false
            }
        }
    }

    // ============================================================
    // MARK: - Premium Badge
    // ============================================================

    private var premiumOnlyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.yellow)

            Text("Premium Only")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(titleColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white)
        )
        .overlay(
            Capsule()
                .stroke(Color.Glu.primaryBlue.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Premium only feature")
    }
}

#if DEBUG
#Preview("ManageAccountHomeView") {
    NavigationStack {
        ManageAccountHomeView()
            .environmentObject(SettingsModel.shared)
    }
}
#endif
