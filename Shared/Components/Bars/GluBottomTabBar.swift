//
//  GluBottomTabBar.swift
//  GluVibProbe – zentrierte, flache Bottom Tab Bar
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
        case .home:      return "Home"
        case .activity:  return "Activity"
        case .body:      return "Body"
        case .nutrition: return "Nutrition"
        case .history:   return "History"
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

    /// Home kann dynamisch ein-/ausgeblendet werden (CGM abhängig)
    let showsHomeTab: Bool

    /// FIXED ORDER (left → right):
    /// Home → Activity → Body → Nutrition → History
    private var tabs: [GluTab] {
        var result: [GluTab] = []

        if showsHomeTab {
            result.append(.home)
        }

        result.append(contentsOf: [
            .activity,
            .body,
            .nutrition,
            .history
        ])

        return result
    }

    // MARK: - Style Tokens (SSoT)

    private let activeColor: Color = Color.Glu.primaryBlue
    private let inactiveColor: Color = .secondary

    private let iconFont: Font = .system(size: 24, weight: .medium)   // ⬅️ smaller
    private let titleFont: Font = .caption2                             // ⬅️ slightly smaller

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isActive = selectedTab == tab

                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(iconFont)

                        Text(tab.title)
                            .font(titleFont)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .foregroundColor(isActive ? activeColor : inactiveColor)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 56)                    // ⬅️ slightly flatter
        .padding(.horizontal, 14)
        .background(.thinMaterial)
    }
}
