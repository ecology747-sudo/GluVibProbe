//
//  SectionHeader.swift
//  GluVibProbe
//

import SwiftUI

struct SectionHeader: View {

    let title: String            // z. B. "Nutrition" oder "Body"
    let subtitle: String?        // aktuell nicht gerendert, aber für Kompatibilität behalten
    let tintColor: Color         // Domain-Farbe für Titel + Pfeil
    let onBack: (() -> Void)?    // optionaler Back-Handler

    // MARK: - Init

    init(
        title: String,
        subtitle: String? = nil,
        tintColor: Color = Color.Glu.primaryBlue,
        onBack: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.onBack = onBack
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            // ZENTRIERTER TITEL
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(tintColor)
                .frame(maxWidth: .infinity, alignment: .center)

            // BACK-PFEIL LINKS, AUSGERICHTET MIT INHALT (16 pt)
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(tintColor)
                    }
                    // kein extra leading-Padding mehr, weil wir unten .padding(.horizontal, 16) setzen
                }
                Spacer()
            }
        }
        // 🔥 WICHTIG: dieser Padding-Wert sorgt dafür,
        // dass Pfeil und Titel mit deinen Karten/Charts (meist .padding(.horizontal)) fluchten.
        .padding(.horizontal, 30)

        // Top-Abstand kannst du bei Bedarf leicht justieren (z. B. 4 statt 8)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    SectionHeader(
        title: "Nutrition",
        subtitle: nil,
        tintColor: Color.Glu.nutritionAccent,
        onBack: {}
    )
    .padding(.vertical)
    .background(Color.Glu.backgroundSurface)
}
