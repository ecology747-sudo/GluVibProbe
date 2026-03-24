//
//  GluBottomTabBar.swift
//  GluVibProbe – rounded pill tab bar (design-only)
//

import SwiftUI

// ============================================================
// MARK: - Tab Definition
// ============================================================

enum GluTab: CaseIterable {
    case home
    case activity
    case body
    case nutrition
    case history

    var title: String {
        switch self {
        case .home:      return L10n.Common.tabMetabolic // UPDATED
        case .activity:  return L10n.Common.tabActivity
        case .body:      return L10n.Common.tabBody
        case .nutrition: return L10n.Common.tabNutrition
        case .history:   return L10n.Common.tabHistory
        }
    }

    var systemImage: String {
        switch self {
        case .home:      return "house.fill"
        case .activity:  return "figure.walk"
        case .body:      return "figure.arms.open"
        case .nutrition: return "fork.knife"
        case .history:   return "folder.fill.badge.plus"
        }
    }
}

// ============================================================
// MARK: - Bottom Tab Bar
// ============================================================

struct GluBottomTabBar: View {

    @Binding var selectedTab: GluTab
    let showsHomeTab: Bool

    @State private var visualSelectedTab: GluTab // UPDATED

    init(selectedTab: Binding<GluTab>, showsHomeTab: Bool) {
        self._selectedTab = selectedTab
        self.showsHomeTab = showsHomeTab
        self._visualSelectedTab = State(initialValue: selectedTab.wrappedValue) // UPDATED
    }

    private var tabs: [GluTab] {
        var result: [GluTab] = []
        if showsHomeTab { result.append(.home) }
        result.append(contentsOf: [.activity, .body, .nutrition, .history])
        return result
    }

    private let primaryBlue: Color = Color.Glu.systemForeground
    private let inactiveBlue: Color = Color.Glu.systemForeground.opacity(0.70)

    private let iconFont: Font = .system(size: 24, weight: .medium)
    private let titleFont: Font = .caption2

    private let outerHorizontalInset: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isActive = visualSelectedTab == tab
                let domain = highlightDomainColor(for: tab)
                let contentColor = isActive ? primaryBlue : inactiveBlue

                GluTabButton(
                    tab: tab,
                    isActive: isActive,
                    domain: domain,
                    contentColor: contentColor,
                    iconFont: iconFont,
                    titleFont: titleFont,
                    onSelect: {
                        visualSelectedTab = tab
                        selectedTab = tab
                    }
                )
            }
        }
        .frame(height: 72)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.Glu.primaryBlue.opacity(0.18),
                                    Color.Glu.nutritionDomain.opacity(0.16),
                                    Color.Glu.bodyDomain.opacity(0.16),
                                    Color.Glu.activityDomain.opacity(0.16),
                                    Color.Glu.metabolicDomain.opacity(0.18)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blendMode(.softLight)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .blur(radius: 0.2)
                        .offset(y: -0.5)
                        .mask(RoundedRectangle(cornerRadius: 40, style: .continuous))
                )
        }
        .padding(.horizontal, outerHorizontalInset)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .onChange(of: selectedTab) { newValue in
            if visualSelectedTab != newValue {
                visualSelectedTab = newValue
            }
        }
    }

    private func highlightDomainColor(for tab: GluTab) -> Color {
        switch tab {
        case .home:
            return Color.Glu.metabolicDomain
        case .activity:
            return Color.Glu.activityDomain
        case .body:
            return Color.Glu.bodyDomain
        case .nutrition:
            return Color.Glu.nutritionDomain
        case .history:
            return Color.Glu.primaryBlue
        }
    }
}

// ============================================================
// MARK: - Single Tab Button
// ============================================================

private struct GluTabButton: View {

    let tab: GluTab
    let isActive: Bool
    let domain: Color
    let contentColor: Color
    let iconFont: Font
    let titleFont: Font
    let onSelect: () -> Void

    @State private var didTriggerSelection = false // UPDATED

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: tab.systemImage)
                .font(iconFont)
                .foregroundColor(contentColor)
                .frame(width: 28, height: 28, alignment: .center)
                .scaleEffect(isActive ? 1.12 : 1.0)
                .offset(y: isActive ? -2 : 0)

            Text(tab.title)
                .font(titleFont)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(contentColor)
                .lineLimit(1)

            Capsule()
                .fill(isActive ? domain : Color.clear)
                .frame(width: 42, height: 3.5)
                .padding(.top, 2)
        }
        .transaction { transaction in
            transaction.animation = nil // UPDATED
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !didTriggerSelection else { return }
                    didTriggerSelection = true
                    onSelect()
                }
                .onEnded { _ in
                    didTriggerSelection = false
                }
        )
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    VStack {
        Spacer()
        GluBottomTabBar(selectedTab: .constant(.activity), showsHomeTab: true)
    }
}
