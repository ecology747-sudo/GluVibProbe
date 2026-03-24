//
//  MetricDetailScaffold.swift
//  GluVibProbe
//
//  Generisches Detail-Screen-Gerüst für alle Domains
//

import SwiftUI

struct MetricDetailScaffold<Background: View, Content: View>: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel

    let headerTitle: String
    let headerTint: Color
    let onBack: (() -> Void)?
    let onRefresh: (() async -> Void)?

    let showsPermissionBadge: Bool

    @ViewBuilder let background: () -> Background
    @ViewBuilder let content: () -> Content

    private let horizontalInset: CGFloat = 16
    private let topInset: CGFloat = 8
    private let bottomInset: CGFloat = 16

    init(
        headerTitle: String,
        headerTint: Color,
        onBack: (() -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil,
        showsPermissionBadge: Bool = false,
        @ViewBuilder background: @escaping () -> Background,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headerTitle = headerTitle
        self.headerTint = headerTint
        self.onBack = onBack
        self.onRefresh = onRefresh
        self.showsPermissionBadge = showsPermissionBadge
        self.background = background
        self.content = content
    }

    var body: some View {

        let showsPermissionBadgeEffective = settings.showPermissionWarnings && showsPermissionBadge

        return ZStack {
            background()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                SectionHeader(
                    title: headerTitle,
                    subtitle: nil,
                    tintColor: headerTint,
                    onBack: onBack,
                    showsAvatar: true,
                    onAvatarTapped: {
                        appState.presentAccountSheet()
                    },
                    showsPermissionBadge: showsPermissionBadgeEffective
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // 🟨 UPDATED
                    .padding(.top, topInset)
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, bottomInset)
                }
                .modifier(RefreshableIfAvailable(onRefresh: onRefresh))
            }
        }
    }
}

// MARK: - Refresh Helper

private struct RefreshableIfAvailable: ViewModifier {

    let onRefresh: (() async -> Void)?

    func body(content: Content) -> some View {
        if let onRefresh {
            content.refreshable {
                await onRefresh()
            }
        } else {
            content
        }
    }
}
