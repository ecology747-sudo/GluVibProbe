//
//  ChartCard.swift
//  GluVibProbe
//

import SwiftUI

struct ChartCard<Content: View>: View {

    let borderColor: Color
    let content: () -> Content

    init(
        borderColor: Color = Color.Glu.activityAccent,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.borderColor = borderColor
        self.content = content
    }

    var body: some View {
        VStack {
            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
        }
        .gluVibCardFrame(domainColor: borderColor) // ✅ zentraler Card-Style (Stroke/Radius/Shadow)
    }
}

#Preview("ChartCard – Neutral Surface") {
    VStack(spacing: 16) {

        ChartCard(borderColor: Color.Glu.activityAccent) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Demo Chart")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.Glu.activityAccent.opacity(0.20))
                    .frame(height: 120)

                Text("Bars / Lines would render here")
                    .font(.caption)
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
            }
            .frame(height: 220)
        }

        ChartCard(borderColor: Color.Glu.nutritionAccent) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.Glu.nutritionAccent.opacity(0.18))
                .frame(height: 180)
        }
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
