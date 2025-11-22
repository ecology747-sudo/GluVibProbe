//
//  SectionHeader.swift
//  GluVibProbe
//

import SwiftUI

struct SectionHeader: View {
    let title: String          // z. B. "Körper & Aktivität"
    let subtitle: String?      // z. B. "Schritte – Tagesziel & Verlauf" (optional)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Haupttitel der Sektion
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            // Optionaler Untertitel (kleiner, grauer Text)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 0)
        .padding(.leading, 4)// einheitlicher horizontaler Abstand
        .padding(.top, 8)       // Abstand nach oben zur vorherigen Sektion
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
