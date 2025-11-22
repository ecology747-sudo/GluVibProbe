//
//  StepsView 3.swift
//  GluVibProbe
//
//  Created by MacBookAir on 19.11.25.
//


//
//  StepsView.swift
//  GluVibProbe
//

import SwiftUI

struct StepsView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ActivityStepsSectionCard(
                    title: "Steps",
                    kpiTitle: "Steps Today",
                    kpiValue: "8 532",
                    onPrevious: {
                        // TODO: Tag zurückblättern
                    },
                    onNext: {
                        // TODO: Tag vorblättern
                    }
                ) {
                    // Inhalt im Rahmen: oben „Diagramm“, unten „Diagramm“
                    VStack(spacing: 12) {

                        // Oberes „Diagramm“
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.Glu.limeGlow.opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                Text("Steps – Wochenverlauf (Dummy)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )

                        // Unteres „Diagramm“
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.Glu.primaryBlue.opacity(0.25))
                            .frame(height: 120)
                            .overlay(
                                Text("Steps – 90 Tage Trend (Dummy)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24) // etwas Luft über der Bottom Tab Bar
        }
        .background(
            Color.Glu.softGray.opacity(0.1)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    StepsView()
}