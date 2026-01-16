//
//  AccountMenuSheetView.swift
//  GluVibProbe
//
//  Account Sheet — Menu Content (NO NavigationStack here)
//  - Emits navigation intents via injected callbacks
//  - Root sheet owns NavigationStack + destinations
//

import SwiftUI

struct AccountMenuSheetView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel

    // Navigation actions injected by the sheet root
    let onOpenSettings: (_ startDomain: SettingsDomain) -> Void
    let onOpenHelp: () -> Void
    let onOpenManage: () -> Void

    init(
        onOpenSettings: @escaping (_ startDomain: SettingsDomain) -> Void = { _ in },
        onOpenHelp: @escaping () -> Void = { },
        onOpenManage: @escaping () -> Void = { }
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenHelp = onOpenHelp
        self.onOpenManage = onOpenManage
    }

    // MARK: - Status logic (capability-aligned)

    private var isPremiumUser: Bool {
        // Premium definition: CGM ON
        settings.hasCGM
    }

    private var statusTitle: String {
        isPremiumUser ? "Premium User" : "Free App"
    }

    private var statusIcon: String {
        isPremiumUser ? "crown.fill" : "sparkles"
    }

    private var statusIconColor: Color {
        isPremiumUser ? .yellow : Color.Glu.primaryBlue
    }

    private var insulinMetricsLine: String {
        "Status: Insulin Metrics \(settings.isInsulinTreated ? "On" : "Off")"
    }

    var body: some View {
        VStack(spacing: 0) {

            // ====================================================
            // MARK: - Avatar + Status
            // ====================================================

            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)
                    .shadow(
                        color: Color.black.opacity(0.18),
                        radius: 3.5,
                        x: 1,
                        y: 2
                    )
                    .padding(.top, 14)

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusIconColor)

                        Text(statusTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.Glu.primaryBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text(insulinMetricsLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.Glu.primaryBlue)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 6)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .padding(.bottom, 10)

            Divider()

            // ====================================================
            // MARK: - Main Actions (Level 1)
            // ====================================================

            List {

                Section {
                    Button {
                        onOpenSettings(appState.settingsStartDomain)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Button {
                        onOpenManage()
                    } label: {
                        Label("Manage Account", systemImage: "person.crop.circle")
                    }
                }

                Section {
                    Button {
                        // placeholder (FAQ)
                    } label: {
                        Label("Frequently Asked Questions", systemImage: "questionmark.circle")
                    }

                    Button {
                        onOpenHelp()
                    } label: {
                        Label("Help & Feedback", systemImage: "bubble.left.and.bubble.right")
                    }

                    Button {
                        // placeholder (App Info)
                    } label: {
                        Label("App Info", systemImage: "info.circle")
                    }

                    Button {
                        // placeholder (Legal)
                    } label: {
                        Label("Legal Information", systemImage: "doc.text")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .tint(Color.Glu.primaryBlue)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("AccountMenuSheetView") {
    AccountMenuSheetView(
        onOpenSettings: { _ in },
        onOpenHelp: { },
        onOpenManage: { }
    )
    .environmentObject(AppState())
    .environmentObject(SettingsModel.shared)
}
