//
//  OverviewHeader.swift
//  GluVibProbe
//
//  Finaler Header für Overview-Screens
//

import SwiftUI

struct OverviewHeader: View {

    // MARK: - Öffentliche Parameter (API wie gehabt)

    /// Seitentitel („Nutrition Overview“ etc.)
    let title: String

    /// Untertitel (z. B. Datum)
    let subtitle: String?

    /// Domainfarbe (aktuell nicht genutzt, bleibt für später erhalten)
    let tintColor: Color

    /// Scrollzustand (aktuell nicht verwendet, API-kompatibel zur View)
    let hasScrolled: Bool

    // MARK: - Body
    var body: some View {

        ZStack {

            // MARK: - Änderung: Hintergrund etwas dezenter
            //
            // - Weiß mit 90 % Deckkraft bleibt
            // - Blur-Radius reduziert, damit der Übergang zum Score weicher ist
            //
            Rectangle()
                .fill(Color.white.opacity(0.90))
                .blur(radius: 10)                     // MARK: - Änderung: Blur von 15 → 10 reduziert
                .ignoresSafeArea(edges: .top)

            // MARK: - Titel + Untertitel
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
            .padding(.top, 4)                        // MARK: - Änderung: etwas weniger Top-Padding
            .padding(.bottom, 4)                     // MARK: - Änderung: etwas weniger Bottom-Padding
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)                           // MARK: - Änderung: Höhe von 60 → 44 verkleinert
    }
}

// MARK: - Preview
#Preview {
    OverviewHeader(
        title: "Nutrition Overview",
        subtitle: "06.12.2025",
        tintColor: .green,
        hasScrolled: false
    )
    .previewLayout(.sizeThatFits)
    .padding()
}
