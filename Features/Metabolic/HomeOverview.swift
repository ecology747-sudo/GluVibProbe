//
//  HomeView.swift
//  GluVibProbe
//
//  Home (Scaffolding only)
//  - Minimal, stable placeholder
//  - Shows a quick read-only status of key settings
//  - No routing, no gating, no HealthStore calls
//

import SwiftUI

struct HomeView: View {

    // ------------------------------------------------------------
    // MARK: - Environment
    // ------------------------------------------------------------
    @EnvironmentObject private var settings: SettingsModel    // !!! NEW: read-only status display

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Header

                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text("Dashboard scaffold — more content will be added later.")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // MARK: Quick Status Card (read-only)

                VStack(alignment: .leading, spacing: 12) {

                    Text("Metabolic setup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    VStack(alignment: .leading, spacing: 10) {

                        statusRow(
                            title: "Insulin therapy",
                            subtitle: "Enabled if you regularly use insulin (bolus and/or basal).",
                            isOn: settings.isInsulinTreated
                        )

                        Divider()
                            .opacity(0.4)

                        statusRow(
                            title: "CGM sensor available",
                            subtitle: "Enabled if your glucose is tracked continuously via a sensor.",
                            isOn: settings.hasCGM
                        )
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.Glu.backgroundSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.Glu.primaryBlue.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)

                // MARK: Placeholder Sections

                VStack(alignment: .leading, spacing: 10) {
                    Text("Coming next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text("• Home content modules\n• Metabolic domain screens\n• Later: gating based on the toggles")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.clear)
    }

    // MARK: - Helpers

    private func statusRow(title: String, subtitle: String, isOn: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }

            Spacer()

            Text(isOn ? "On" : "Off")
                .font(.caption.weight(.semibold))
                .foregroundColor(isOn ? Color.Glu.metabolicDomain : Color.Glu.primaryBlue.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.Glu.metabolicDomain.opacity(isOn ? 0.14 : 0.06))
                )
        }
    }
}

// MARK: - Preview

#Preview("HomeView") {
    HomeView()
        .environmentObject(SettingsModel.shared)          // !!! NEW: required for preview
}
