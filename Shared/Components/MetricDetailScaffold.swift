//
//  MetricDetailScaffold.swift
//  GluVibProbe
//
//  Generisches Detail-Screen-Gerüst für alle Domains
//

import SwiftUI

struct MetricDetailScaffold<Background: View, Content: View>: View {

    // MARK: - Inputs

    let headerTitle: String
    let headerTint: Color
    let onBack: (() -> Void)?
    let onRefresh: (() async -> Void)?

    @ViewBuilder let background: () -> Background
    @ViewBuilder let content: () -> Content

    // MARK: - Layout Constants (Overview-aligned)

    private let horizontalInset: CGFloat = 16        // ✅ HIER: entspricht Overview .padding(.horizontal, 16)
    private let topInset: CGFloat = 8
    private let bottomInset: CGFloat = 16

    // MARK: - Init

    init(
        headerTitle: String,
        headerTint: Color,
        onBack: (() -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder background: @escaping () -> Background,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headerTitle = headerTitle
        self.headerTint = headerTint
        self.onBack = onBack
        self.onRefresh = onRefresh
        self.background = background
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                SectionHeader(
                    title: headerTitle,
                    subtitle: nil,
                    tintColor: headerTint,
                    onBack: onBack
                )

                ScrollView {
                    content()
                        .padding(.top, topInset)
                        .padding(.horizontal, horizontalInset)   // ✅ exakt wie Overview
                        .padding(.bottom, bottomInset)
                }
                .modifier(RefreshableIfAvailable(onRefresh: onRefresh))
            }
        }
    }
}

// MARK: - Refresh Helper (lokal, damit keine Abhängigkeit fehlt)

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
