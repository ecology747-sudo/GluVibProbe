//
//  LegalInformationView.swift
//  GluVibProbe
//
//  Legal Information (static)
//  - Static, informational only (no HealthStore, no Settings writes)
//  - Apple-default List + Sections + DisclosureGroups
//  - Uses GluPrimaryBlue for navigation title + section headers
//

import SwiftUI
import UIKit

struct LegalInformationView: View {

    // MARK: - Theme

    private let titleColor: Color = Color("GluPrimaryBlue")

    @Environment(\.openURL) private var openURL

    // MARK: - Static Content (placeholder – we will refine wording later)

    private let sections: [LegalSection] = [

        LegalSection(
            title: "Medical Disclaimer",
            items: [
                LegalItem(
                    title: "Not a medical device or medical service",
                    body: "GluVib is an analysis and visualization tool for personal health data. It is not a medical device and not a medical service."
                ),
                LegalItem(
                    title: "No medical advice",
                    body: "GluVib does not provide medical advice, diagnosis, or therapy recommendations."
                ),
                LegalItem(
                    title: "Does not replace professional care",
                    body: "GluVib does not replace professional medical care. If you have health concerns, consult a qualified healthcare professional."
                )
            ]
        ),

        LegalSection(
            title: "Privacy Summary",
            items: [
                LegalItem(
                    title: "Data source",
                    body: "GluVib works exclusively with Apple Health. Apple Health is the single source of truth for the data displayed in the app."
                ),
                LegalItem(
                    title: "Control & permissions",
                    body: """
                    You can stop data access anytime by revoking GluVib’s Apple Health permissions in Apple Health / iOS Settings.

                    To change permissions:
                    Health app → Profile → Apps → GluVib.
                    """
                )
            ]
        ),

        LegalSection(
            title: "Terms",
            items: [
                LegalItem(
                    title: "Terms of Use",
                    body: "Terms of Use will be provided later. We will add a link and versioning once the legal text is finalized."
                )
            ]
        ),

        LegalSection(
            title: "Open Source & Acknowledgements",
            items: [
                LegalItem(
                    title: "Acknowledgements",
                    body: "Open source acknowledgements will be added later if applicable."
                )
            ]
        )
    ]

    // MARK: - View

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        LegalDisclosureRow(item: item)
                    }

                    if section.title == "Privacy Summary" {
                        permissionHintRow
                        openAppSettingsRow
                    }

                } header: {
                    Text(section.title)
                        .foregroundStyle(titleColor)
                }
            }
        }
        .navigationTitle("Legal Information")
        .navigationBarTitleDisplayMode(.inline)
        .tint(titleColor)
    }

    // ============================================================
    // MARK: - Privacy Summary Extras (small, Apple-default)
    // ============================================================

    private var permissionHintRow: some View {
        Text("Permissions are managed by Apple Health / iOS Settings.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .accessibilityLabel("Permissions are managed by Apple Health and iOS Settings")
    }

    private var openAppSettingsRow: some View {
        Button {
            openURL(AppSettingsLink.url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                Text("Open iOS Settings (GluVib)")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(titleColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open iOS Settings for GluVib")
    }
}

// MARK: - Row

private struct LegalDisclosureRow: View {

    let item: LegalItem
    @State private var isExpanded: Bool = false

    private let titleColor: Color = Color("GluPrimaryBlue")

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {

            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 2)

        } label: {

            Text(item.title)
                .font(.body)
                .foregroundStyle(titleColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Settings Deep Link Helper

private enum AppSettingsLink {
    static var url: URL {
        URL(string: UIApplication.openSettingsURLString)!
    }
}

// MARK: - Models

private struct LegalSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [LegalItem]
}

private struct LegalItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

// MARK: - Preview

#if DEBUG
#Preview("LegalInformationView") {
    NavigationStack {
        LegalInformationView()
    }
}
#endif
