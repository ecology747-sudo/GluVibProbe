//
//  SectionHeader.swift
//  GluVibProbe
//

import SwiftUI

struct SectionHeader: View {

    // MARK: - Inputs

    let title: String
    let subtitle: String?
    let tintColor: Color
    let onBack: (() -> Void)?

    // Optional Avatar Button (Settings Domain Editors can hide this)
    let showsAvatar: Bool
    let onAvatarTapped: (() -> Void)?

    // MARK: - Init

    init(
        title: String,
        subtitle: String? = nil,
        tintColor: Color = Color.Glu.primaryBlue,
        onBack: (() -> Void)? = nil,
        showsAvatar: Bool = true,
        onAvatarTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.onBack = onBack
        self.showsAvatar = showsAvatar
        self.onAvatarTapped = onAvatarTapped
    }

    // MARK: - Body

    var body: some View {

        ZStack {

            // UPDATED: match OverviewHeader background + top safe-area behavior
            Rectangle()
                .fill(Color.white.opacity(0.90))
                .blur(radius: 10)
                .ignoresSafeArea(edges: .top)

            // UPDATED: match OverviewHeader center stack spacing + vertical padding
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(tintColor)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(tintColor.opacity(0.75))
                }
            }
            .padding(.top, 4)     // UPDATED: match OverviewHeader
            .padding(.bottom, 4)  // UPDATED: match OverviewHeader
            .frame(maxWidth: .infinity)

            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(tintColor)
                    }
                    .accessibilityLabel("Back")
                    .buttonStyle(.plain)
                    .padding(.leading, 12) // UPDATED: mirrors trailing padding on avatar side
                } else {
                    // keeps center alignment stable when back button is absent
                    Spacer().frame(width: 44)
                }

                Spacer()

                if showsAvatar {
                    Button {
                        onAvatarTapped?()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .shadow(
                                color: Color.black.opacity(0.22),
                                radius: 4.5,
                                x: 0,
                                y: 2
                            )
                            .accessibilityLabel("Account menu")
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12) // UPDATED: match OverviewHeader
                } else {
                    // keeps center alignment stable when avatar is hidden
                    Spacer().frame(width: 44)
                }
            }
        }
        .frame(height: 44) // UPDATED: match OverviewHeader
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {

        SectionHeader(
            title: "Units",
            tintColor: Color.Glu.primaryBlue,
            onBack: { },
            showsAvatar: false
        )

        SectionHeader(
            title: "Premium Overview",
            subtitle: "06.12.2025",
            tintColor: Color.Glu.metabolicDomain,
            onBack: nil,
            showsAvatar: true,
            onAvatarTapped: { }
        )
    }
    .background(Color.white)
}
