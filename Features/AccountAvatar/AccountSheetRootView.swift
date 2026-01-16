//
//  AccountSheetRootView.swift
//  GluVibProbe
//
//  SINGLE root for the Account sheet
//  - Owns NavigationStack for in-sheet pages (Help / Manage)
//  - Settings is NOT presented here (avoids double-sheet conflict)
//

import SwiftUI

struct AccountSheetRootView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel

    private enum Route: Hashable {
        case help
        case manage
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {

            AccountMenuSheetView(
                onOpenSettings: { startDomain in
                    // UPDATED: only request + dismiss Account. Root presents Settings AFTER dismiss.
                    appState.requestOpenSettings(startDomain: startDomain)
                },
                onOpenHelp: {
                    path.append(.help)
                },
                onOpenManage: {
                    path.append(.manage)
                }
            )
            .environmentObject(appState)
            .environmentObject(settings)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .help:
                    SimpleInfoScreen(
                        title: "Help & Support",
                        text: "This section will later contain help resources and contact options."
                    )

                case .manage:
                    SimpleInfoScreen(
                        title: "Manage Account",
                        text: "This section will later contain account-related options such as privacy, data export, and premium status."
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// ============================================================
// MARK: - Simple Placeholder Screen
// ============================================================

private struct SimpleInfoScreen: View {

    let title: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(text)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("AccountSheetRootView") {
    AccountSheetRootView()
        .environmentObject(AppState())
        .environmentObject(SettingsModel.shared)
}
