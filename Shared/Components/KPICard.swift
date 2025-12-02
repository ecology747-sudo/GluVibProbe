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

    /// Fach-Domain der Metrik (Body, Activity, Nutrition, Metabolic)
    private let domain: MetricDomain

    // MARK: - Initializer

    init(
        title: String,
        valueText: String,
        unit: String? = nil,
        valueColor: Color? = nil,
        domain: MetricDomain = .body      // Default: Body → kompatibel mit altem Code
    ) {
        self.title = title
        self.valueText = valueText
        self.unit = unit
        self.valueColor = valueColor
        self.domain = domain
    }

    // MARK: - Berechnete Farben

    /// Rahmenfarbe der KPI-Kachel – kommt zentral aus MetricDomain
    private var borderColor: Color {
        domain.accentColor
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

                // Zahl – bleibt immer einzeilig, skaliert bei Bedarf
                Text(valueText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(valueColor ?? Color.Glu.primaryBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Einheit – kurz, optional, leicht skalierbar
                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                            borderColor.opacity(0.9),   // ⬅️ Domain-gesteuerte Rahmenfarbe
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
            valueText: "10 000",
            domain: .activity
        )

        KPICard(
            title: "Current",
            valueText: "8 532",
            domain: .body
        )

        KPICard(
            title: "Delta",
            valueText: "+1 468",
            valueColor: .green,
            domain: .nutrition
        )

        KPICard(
            title: "Target",
            valueText: "2.700",
            unit: "kcal",
            domain: .nutrition
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
