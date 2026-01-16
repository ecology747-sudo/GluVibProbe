//
//  OverviewHeader.swift
//  GluVibProbe
//
//  Finaler Header für Overview-Screens
//

import SwiftUI

struct OverviewHeader: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsModel

    let title: String
    let subtitle: String?
    let tintColor: Color
    let hasScrolled: Bool

    var body: some View {

        ZStack {

            Rectangle()
                .fill(Color.white.opacity(0.90))
                .blur(radius: 10)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 2) {

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                // UPDATED: Right-aligned action group – tighter & visually secondary
                HStack(spacing: 4) {   // UPDATED: noch dichter

                    Button {
                        // TODO: Present Reports / Print (AGP-like summaries)
                    } label: {
                        Image(systemName: "printer")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .opacity(0.9)                      // UPDATED
                            .accessibilityLabel("Reports")
                            .padding(.leading, 6)
                            .padding(.trailing, 2)              // UPDATED: zieht optisch näher ran
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.presentAccountSheet()
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
                }
                .padding(.trailing, 12)
            }     }
        .frame(height: 44)
    }
}

// MARK: - Preview
#Preview {
    OverviewHeader(
        title: "Nutrition Overview",
        subtitle: "06.12.2025",
        tintColor: .green,
        hasScrolled: false
    )
    .environmentObject(AppState())
    .environmentObject(SettingsModel.shared)
    .previewLayout(.sizeThatFits)
    .padding()
}
