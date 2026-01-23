//
//  AccountSheetRootView.swift
//  GluVibProbe
//
//  ACCOUNT SHEET — TECHNICAL ROOT (Coordinator)
//
//  Zweck:
//  - Besitz der NavigationStack + Routing innerhalb des Account-Sheets
//  - UI Level 1 liegt in AccountMenuSheetView
//  - Help & Feedback öffnet DIREKT HelpAndFeedbackView (kein Hub, keine Zwischenebene)
//  - FAQ öffnet DIREKT FrequentlyAskedQuestionsView
//  - App Info öffnet DIREKT AppInfoView
//  - Legal Information öffnet DIREKT LegalInformationView
//  - Settings wird NICHT hier präsentiert (verhindert double-sheet conflict)
//

import SwiftUI

struct AccountSheetRootView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel

    @State private var path: [AppState.AccountRoute] = []

    var body: some View {
        NavigationStack(path: $path) {

            AccountMenuSheetView(
                onOpenSettings: { startDomain in
                    appState.requestOpenSettings(startDomain: startDomain)
                },
                onOpenHelp: {
                    path.append(.help)
                },
                onOpenManage: {
                    path.append(.manage)
                },
                onOpenFAQ: {
                    path.append(.faq)
                },
                onOpenAppInfo: {
                    path.append(.appInfo)
                },
                onOpenLegal: {
                    path.append(.legal)
                }
            )
            .environmentObject(appState)
            .environmentObject(settings)
            .navigationDestination(for: AppState.AccountRoute.self) { route in
                switch route {

                case .help:
                    HelpAndFeedbackView()

                case .faq:
                    FrequentlyAskedQuestionsView()
                        .environmentObject(appState)
                        .environmentObject(settings)

                case .appInfo:
                    AppInfoView()

                case .legal:
                    LegalInformationView()

                case .manage:
                    ManageAccountHomeView()
                        .environmentObject(appState)
                        .environmentObject(settings)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // UPDATED: handle global deep-link requests into the sheet
            .onChange(of: appState.pendingAccountRoute) { _, newValue in
                guard let route = newValue else { return }
                path.append(route)
                appState.pendingAccountRoute = nil
            }
            // UPDATED: in case route is set before sheet appears
            .onAppear {
                if let route = appState.pendingAccountRoute {
                    path.append(route)
                    appState.pendingAccountRoute = nil
                }
            }
        }
        .tint(Color("GluPrimaryBlue"))
    }
}

#if DEBUG
#Preview("AccountSheetRootView (DEV Routing Preview)") {
    AccountSheetRootView()
        .environmentObject(AppState())
        .environmentObject(SettingsModel.shared)
}
#endif
