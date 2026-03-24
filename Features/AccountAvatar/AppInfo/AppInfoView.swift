//
//  AppInfoView.swift
//  GluVibProbe
//
//  Settings / Account — App Info Screen
//  Purpose:
//  - Displays static app, device, and link information.
//  - Read-only informational screen without HealthStore or Settings writes.
//
//  Data Flow (SSoT):
//  - Bundle / UIDevice -> derived display values -> AppInfoView -> UI
//
//  Key Connections:
//  - Bundle.main.infoDictionary
//  - UIDevice
//  - external links (website / support mail)
//

import SwiftUI
import UIKit

struct AppInfoView: View {

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground

    // ============================================================
    // MARK: - Constants
    // ============================================================

    private let websiteURL: URL = URL(string: "https://gluvib.com")!
    private let supportEmail: String = "support@gluvib.com"

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var systemString: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    private var deviceString: String {
        UIDevice.current.model
    }

    private var mailtoURL: URL? {
        URL(string: "mailto:\(supportEmail)")
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        List {

            Section {
                infoRow(
                    title: String(
                        localized: "Version",
                        defaultValue: "Version",
                        comment: "Label for app version in app info view"
                    ),
                    value: versionString
                ) // 🟨 UPDATED

                infoRow(
                    title: L10n.Avatar.AppInfo.device,
                    value: deviceString
                ) // 🟨 UPDATED

                infoRow(
                    title: L10n.Avatar.AppInfo.system,
                    value: systemString
                ) // 🟨 UPDATED

            } header: {
                Text(
                    String(
                        localized: "Version",
                        defaultValue: "Version",
                        comment: "Section header for version information in app info view"
                    )
                ) // 🟨 UPDATED
                .foregroundStyle(titleColor)
            }

            Section {

                Link(destination: websiteURL) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text(
                            String(
                                localized: "gluvib.com",
                                defaultValue: "gluvib.com",
                                comment: "Website link text in app info view"
                            )
                        ) // 🟨 UPDATED
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(titleColor)
                }

                if let mailtoURL {
                    Link(destination: mailtoURL) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope")
                            Text(
                                String(
                                    localized: "support@gluvib.com",
                                    defaultValue: "support@gluvib.com",
                                    comment: "Support email text in app info view"
                                )
                            ) // 🟨 UPDATED
                            Spacer()
                        }
                        .foregroundStyle(titleColor)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                        Text(
                            String(
                                localized: "support@gluvib.com",
                                defaultValue: "support@gluvib.com",
                                comment: "Support email text in app info view"
                            )
                        ) // 🟨 UPDATED
                        Spacer()
                    }
                    .foregroundStyle(titleColor)
                }

            } header: {
                Text(
                    String(
                        localized: "Links",
                        defaultValue: "Links",
                        comment: "Section header for external links in app info view"
                    )
                ) // 🟨 UPDATED
                .foregroundStyle(titleColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(
                    String(
                        localized: "App Info",
                        defaultValue: "App Info",
                        comment: "Navigation title for app info view"
                    )
                ) // 🟨 UPDATED
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }

    // ============================================================
    // MARK: - Local Helper Views
    // ============================================================

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(titleColor)

            Spacer()

            Text(value)
                .foregroundStyle(titleColor)
        }
        .padding(.vertical, 2)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#if DEBUG
#Preview("AppInfoView") {
    NavigationStack {
        AppInfoView()
    }
}
#endif
