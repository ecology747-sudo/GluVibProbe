//
//  AppInfoView.swift
//  GluVibProbe
//
//  App Info (static)
//  - Static, informational only (no HealthStore, no Settings writes)
//  - Apple-default List + Sections
//  - Uses GluPrimaryBlue consistently
//

import SwiftUI
import UIKit

struct AppInfoView: View {

    // MARK: - Theme

    private let titleColor: Color = Color("GluPrimaryBlue")

    // MARK: - Static Links

    private let websiteURL: URL = URL(string: "https://gluvib.com")!
    private let supportEmail: String = "support@gluvib.com"

    // MARK: - Derived (App / System)

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "GluVib"
    }

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

    // MARK: - View

    var body: some View {
        List {

            // ============================================================
            // MARK: - About
            // ============================================================

            Section {
                VStack(alignment: .leading, spacing: 10) {

                    Text("\(appName) is an analysis and visualization tool for personal health data.")
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)

                    // 🔶 Hervorgehobener medizinischer Hinweis
                    Text("It does not provide medical advice, diagnosis, or therapy recommendations.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)

            } header: {
                Text("About GluVib")
                    .foregroundStyle(titleColor)
            }

            // ============================================================
            // MARK: - Version
            // ============================================================

            Section {
                infoRow(title: "Version", value: versionString)
                infoRow(title: "Device", value: deviceString)
                infoRow(title: "System", value: systemString)

            } header: {
                Text("Version")
                    .foregroundStyle(titleColor)
            }

            // ============================================================
            // MARK: - Data Source
            // ============================================================

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GluVib works exclusively with Apple Health.")
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("The more consistent and complete your Apple Health data is, the more meaningful the analysis becomes.")
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)

            } header: {
                Text("Data Source")
                    .foregroundStyle(titleColor)
            }

            // ============================================================
            // MARK: - Links
            // ============================================================

            // ============================================================
            // MARK: - Links
            // ============================================================

            Section {

                // Website
                Link(destination: websiteURL) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text("gluvib.com")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(titleColor)
                }

                // Support Email
                if let mailtoURL {
                    Link(destination: mailtoURL) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope")
                            Text(supportEmail)
                            Spacer()
                        }
                        .foregroundStyle(titleColor)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                        Text(supportEmail)
                        Spacer()
                    }
                    .foregroundStyle(titleColor)
                }

            } header: {
                Text("Links")
                    .foregroundStyle(titleColor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("App Info")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }

    // MARK: - Row Helper

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

#if DEBUG
#Preview("AppInfoView") {
    NavigationStack {
        AppInfoView()
    }
}
#endif
