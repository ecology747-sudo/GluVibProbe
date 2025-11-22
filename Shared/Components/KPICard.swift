// Datei: KPICard.swift
// GluVibProbe – universelle KPI-Anzeige

import SwiftUI

struct KPICard: View {
    let title: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // ⬅️ Titel ganz links, nah am Rahmen, definierte Keyline
            Text(title)
                .font(.caption)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                .padding(.leading, 6)      // ← Abstand zum Rahmen (optisch perfekt)

            // KPI-Wert: unverändert, bleibt typografisch schön
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                if let unit = unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
            }
            .padding(.leading, 6)          // ← optional: gleiche linke Keyline wie Titel
                                          //     sieht harmonischer aus → empfehlenswert
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Glu.backgroundSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.activityOrange.opacity(0.9),
                                lineWidth: 1.0)
                )
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
                
        
    }
}

#Preview {
    KPICard(title: "Steps Today", value: "8,452", unit: nil)
}
