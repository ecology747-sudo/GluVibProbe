// Datei: GluBottomTabBar.swift
// GluVibProbe – zentrierte, flache Bottom Tab Bar

import SwiftUI

enum GluTab: CaseIterable {
    case activity
    case nutrition
    case home
    case history
    case settings

    var title: String {
        switch self {
        case .activity:  return "Activity"
        case .nutrition: return "Nutrition"
        case .home:      return "Home"
        case .history:   return "History"
        case .settings:  return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .activity:  return "figure.walk"
        case .nutrition: return "fork.knife"
        case .home:      return "house.fill"
        case .history:   return "folder.fill.badge.plus"
        case .settings:  return "gearshape"
        }
    }
}

struct GluBottomTabBar: View {
    @Binding var selectedTab: GluTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GluTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 30, weight: .medium))

                        Text(tab.title)
                            .font(.caption2)
                    }
                    .padding(.top, 0)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity)   // füllt die TabBar → vertikal zentriert
                    .contentShape(Rectangle())
                    .foregroundColor(
                        selectedTab == tab ? .accentColor : .secondary
                    )
                }
            }
        }
        .frame(height: 60)              // sichtbare TabBar-Höhe
        .padding(.horizontal, 15)
        .background(.thinMaterial)
        
    }
}
