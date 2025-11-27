//
//  ChartCard.swift
//  GluVibProbe
//

import SwiftUI

struct ChartCard<Content: View>: View {

    // MARK: - Inputs

    let borderColor: Color
    let content: () -> Content

    // MARK: - Init

    init(
        borderColor: Color = Color.Glu.activityOrange,   // 🔸 Default für BodyActivity
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.borderColor = borderColor
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        VStack {
            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.Glu.backgroundSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(borderColor.opacity(0.7), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.10),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
    }
}
#Preview("ChartCard Demo") {
    ChartCard(borderColor: Color.Glu.activityOrange) {
        VStack(spacing: 8) {
            Text("Demo Chart")
                .font(.headline)
                .foregroundStyle(Color.Glu.primaryBlue)

            Rectangle()
                .fill(Color.Glu.activityOrange.opacity(0.4))
                .frame(height: 80)
                .cornerRadius(8)
        }
        .frame(height: 120)
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
