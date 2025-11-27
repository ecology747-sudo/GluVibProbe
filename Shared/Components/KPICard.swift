//
//  KPICard.swift
//  GluVibProbe
//
//  Universelle KPI-Kachel (Target / Current / Delta etc.)
//

import SwiftUI

struct KPICard: View {

    let title: String          // z. B. "Target", "Current", "Delta"
    let valueText: String      // formatierter Wert, z. B. "10 000"
    let unit: String?          // z. B. "kcal", "g" – meist nil bei Steps
    let valueColor: Color?     // optional: spezielle Farbe (nur Delta nutzt das)

    // MARK: - Initializer

    init(
        title: String,
        valueText: String,
        unit: String? = nil,
        valueColor: Color? = nil
    ) {
        self.title = title
        self.valueText = valueText
        self.unit = unit
        self.valueColor = valueColor
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: 4) {

            // Titel zentriert
            Text(title)
                .font(.caption)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

            // KPI-Wert + optional Unit, zentriert
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(valueText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(valueColor ?? Color.Glu.primaryBlue)

                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Glu.backgroundSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.Glu.activityOrange.opacity(0.9),
                            lineWidth: 1.0
                        )
                )
                .shadow(color: .black.opacity(0.03),
                        radius: 2,
                        x: 0,
                        y: 1)
        )
    }
}

// MARK: - Preview

#Preview("KPICard – Demo") {
    VStack(spacing: 12) {
        KPICard(
            title: "Target",
            valueText: "10 000"
        )

        KPICard(
            title: "Current",
            valueText: "8 532"
        )

        KPICard(
            title: "Delta",
            valueText: "+1 468",
            valueColor: .green    // nur hier Farbe → nur Delta farbig
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
