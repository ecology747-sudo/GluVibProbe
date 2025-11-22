//
//  ActivityStepsSectionCard.swift
//  GluVibProbe
//

import SwiftUI

struct ActivityStepsSectionCard1<Content: View>: View {

    @EnvironmentObject private var appState: AppState

    let screen: AppState.StatsScreen        // z.B. .steps, .activityEnergy, ...
    let title: String                       // z.B. "Steps"
    let kpiTitle: String                    // z.B. "Steps Today"
    let kpiValue: String                    // z.B. "8 532"
    let content: () -> Content              // Charts & Inhalte

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: - Titel + KPI in einer Zeile
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(kpiValue)
                        .font(.title3.weight(.semibold))         // gleich groß wie Title
                        .foregroundStyle(Color.Glu.primaryBlue)

                    Text("Today")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            // MARK: - Pfeilnavigation (links / rechts)
            HStack {
                Button {
                    moveToPreviousStatsScreen()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                Button {
                    moveToNextStatsScreen()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                }
            }
            .foregroundStyle(Color.Glu.primaryBlue)

            // MARK: - Inhalt (Charts)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.Glu.softGray.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.Glu.limeGlow.opacity(0.7),
                                lineWidth: 3)
                )
                .shadow(color: Color.Glu.limeGlow.opacity(0.45),
                        radius: 10,
                        x: 0,
                        y: 4)
        )
    }

    // MARK: - Navigation: vorheriger Screen
    private func moveToPreviousStatsScreen() {
        switch appState.currentStatsScreen {
        case .steps:
            appState.currentStatsScreen = .sleep
        case .activityEnergy:
            appState.currentStatsScreen = .steps
        case .weight:
            appState.currentStatsScreen = .activityEnergy
        case .sleep:
            appState.currentStatsScreen = .weight
        }
    }

    // MARK: - Navigation: nächster Screen
    private func moveToNextStatsScreen() {
        switch appState.currentStatsScreen {
        case .steps:
            appState.currentStatsScreen = .activityEnergy
        case .activityEnergy:
            appState.currentStatsScreen = .weight
        case .weight:
            appState.currentStatsScreen = .sleep
        case .sleep:
            appState.currentStatsScreen = .steps
        }
    }
}
