//
//  SingleChartSectionCard.swift
//  GluVibProbe
//
//  Generische Section Card für genau EINEN Chart oder eine einzelne Visualisierung.
//  - Abgerundete Ecken (wie andere SectionCards)
//  - Dünner Rahmen (Domain-Farbe einstellbar)
//  - Optionaler Titel im Header
//

import SwiftUI

// MARK: - SingleChartSectionCard

// !!! NEW: Generische SectionCard für einen einzelnen Chart-Bereich
struct SingleChartSectionCard<Content: View>: View {          // !!! NEW

    // MARK: - Properties

    let title: String?                                        // !!! NEW
    let borderColor: Color                                    // !!! NEW
    let backgroundColor: Color                                // !!! NEW
    @ViewBuilder let content: () -> Content                   // !!! NEW

    // MARK: - Init

    init(
        title: String? = nil,                                 // !!! NEW
        borderColor: Color = Color.gray.opacity(0.25),        // !!! NEW
        backgroundColor: Color = Color(.systemBackground),    // !!! NEW
        @ViewBuilder content: @escaping () -> Content         // !!! NEW
    ) {
        self.title = title
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {             // !!! NEW

            // Optionaler Titel im Header
            if let title = title, !title.isEmpty {            // !!! NEW
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary.opacity(0.8))
            }

            // Inhalt (z. B. Chart)
            content()                                         // !!! NEW
        }
        .padding(12)                                          // !!! NEW
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

struct SingleChartSectionCard_Previews: PreviewProvider {      // !!! NEW
    static var previews: some View {
        VStack(spacing: 16) {
            SingleChartSectionCard(
                title: "Movement Split (Demo)",
                borderColor: Color.blue.opacity(0.35)
            ) {
                // Platzhalter für einen Chart
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.15))
                    .frame(height: 200)
                    .overlay(
                        Text("Chart Content")
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
            }

            SingleChartSectionCard {
                Text("Ohne Titel – nur Inhalt")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .previewDisplayName("SingleChartSectionCard Demo")
    }
}
