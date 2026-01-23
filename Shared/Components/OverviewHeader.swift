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

    @State private var showReportPreview: Bool = false
    @State private var showReportPeriodDialog: Bool = false
    @State private var selectedReportDays: Int = 30

    // Report icon availability (Premium app + CGM gate)
    private var canShowReportIcon: Bool {
        settings.hasCGM
    }

    var body: some View {

        ZStack {

            Rectangle()
                .fill(Color.white.opacity(0.90))
                .blur(radius: 10)
                .ignoresSafeArea(edges: .top)

            // =========================
            // CENTER: Title + Subtitle
            // =========================
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
            .zIndex(1) // UPDATED: keep below icons

            // =========================
            // LEFT: Report (Preview / Print) — CGM gated
            // =========================
            HStack {

                if canShowReportIcon {

                    Button {
                        showReportPeriodDialog = true
                    } label: {

                        Image(systemName: "tray.circle.fill")
                            .font(.system(size: 27, weight: .semibold)) // = Avatar size
                            .foregroundColor(Color.Glu.primaryBlue)
                            .shadow(
                                color: Color.black.opacity(0.22),
                                radius: 4.5,
                                x: 0,
                                y: 2
                            )
                            .padding(6) // identisch zum Avatar
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open report preview")
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading) // UPDATED: pin to left edge
            .padding(.leading, 12)
            .zIndex(2) // UPDATED

            // =========================
            // RIGHT: Account Avatar
            // =========================
            HStack {
                Spacer()

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
            .frame(maxWidth: .infinity, alignment: .trailing) // UPDATED: pin to right edge
            .padding(.trailing, 12)
            .zIndex(2) // UPDATED
        }
        .frame(height: 44)
        .confirmationDialog(
            "Select report period",
            isPresented: $showReportPeriodDialog,
            titleVisibility: .visible
        ) {
            Button("7 Days")  { selectedReportDays = 7;  showReportPreview = true }
            Button("14 Days") { selectedReportDays = 14; showReportPreview = true }
            Button("30 Days") { selectedReportDays = 30; showReportPreview = true }
            Button("90 Days") { selectedReportDays = 90; showReportPreview = true }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("")
        }

        // UPDATED: Fullscreen + no extra toolbar wrapper (prevents double "Done")
        .fullScreenCover(isPresented: $showReportPreview) {
            NavigationStack {
                MetabolicReportPreviewV1(windowDays: selectedReportDays)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // Ensure CGM gate is ON so the left report icon is visible in preview.
    let settings = SettingsModel.shared
    settings.hasCGM = true

    return OverviewHeader(
        title: "Nutrition Overview",
        subtitle: "06.12.2025",
        tintColor: .green,
        hasScrolled: false
    )
    .environmentObject(AppState())
    .environmentObject(settings)
    .previewLayout(.sizeThatFits)
    .padding()
}
