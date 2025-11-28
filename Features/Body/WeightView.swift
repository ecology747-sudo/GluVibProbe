//
//  WeightView.swift
//  GluVibProbe
//
//  Created by MacBookAir on 23.11.25.
//

import SwiftUI

/// Platzhalter-View für das Body-Domain-Thema "Weight".
/// Aktuell nur eine einfache Section mit Text,
/// wird später wie Steps/Sleep mit KPIs & Charts ausgebaut.
struct WeightView: View {

    // Callback, damit die Metric-Chips später auch hier funktionieren können
    let onMetricSelected: (String) -> Void

    // Default-Init, damit du WeightView() auch ohne Parameter im Preview nutzen kannst
    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var body: some View {
        ZStack {
            Color.Glu.backgroundSurface
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Einfacher Header für die Body-Domain
                    SectionHeader(
                        title: "Body",
                        subtitle: "Weight (coming soon)"
                    )
                    .padding(.horizontal)

                    // Placeholder-Inhalt
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight Dashboard")
                            .font(.headline)
                            .foregroundStyle(Color.Glu.primaryBlue)

                        Text("Die Gewichtsauswertung wird hier später mit KPIs und Charts eingebaut – analog zu Steps und Sleep.")
                            .font(.subheadline)
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.Glu.backgroundNavy.opacity(0.05))
                    )
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top, 16)
            }
        }
    }
}

#Preview {
    WeightView()
        .environmentObject(HealthStore.preview())
        .environmentObject(AppState())
}
