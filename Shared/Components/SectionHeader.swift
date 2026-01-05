//
//  SectionHeader.swift
//  GluVibProbe
//

import SwiftUI

struct SectionHeader: View {

    // MARK: - Inputs

    let title: String
    let subtitle: String?        // aktuell nicht gerendert, für Kompatibilität behalten
    let tintColor: Color
    let onBack: (() -> Void)?

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
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(tintColor)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(tintColor)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)    // CHANGED: mehr Abstand zum Content beim Scrollen
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
