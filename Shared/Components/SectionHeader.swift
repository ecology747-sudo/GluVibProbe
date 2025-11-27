//
//  SectionHeader.swift
//  GluVibProbe
//

import SwiftUI

struct SectionHeader: View {
    let title: String          // z. B. "Körper & Aktivität"
    let subtitle: String?      // z. B. "Schritte – Tagesziel & Verlauf" (optional)

    var body: some View {
        VStack(alignment: .center, spacing: 2) {       // 🔥 leading → center

            // Haupttitel der Sektion
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)
                .frame(maxWidth: .infinity)            // 🔥 sorgt für echte Zentrierung

            // Optionaler Untertitel (kleiner, grauer Text)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)        // 🔥 Subtitle ebenfalls zentriert
            }
        }
        .padding(.horizontal, 0)
        .padding(.leading, 0)                           // 🔥 leading padding entfernt
        .padding(.top, 8)                               // Abstand nach oben zur vorherigen Sektion
    }
}

#Preview {
    SectionHeader(
        title: "Körper & Aktivität",
        subtitle: "Schritte – Tagesziel & Verlauf"
    )
    .padding(.vertical)
    .background(Color.Glu.backgroundSurface)
}
