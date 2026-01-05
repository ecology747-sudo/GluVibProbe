//
//  GluVibCardStyle.swift
//  GluVibProbe
//
//  Single Point of Truth for ALL card borders (Overview + KPI + Charts + Metric Cards)
//  - Only controls: cornerRadius, strokeWidth, stroke colors, shadow
//  - Does NOT touch: layout, size, fonts, spacing inside the card content
//

import SwiftUI

// MARK: - Central Style Tokens

enum GluVibCardStyle {

    static let cornerRadius: CGFloat = 12

    static let strokeWidth: CGFloat = 1.8          // !!! HERE: LINE THICKNESS (zentral)

    static var backgroundFill: some ShapeStyle { Color.Glu.backgroundSurface }
    static var highlightStroke: Color { Color.white.opacity(0.45) }
    static func domainStroke(_ borderColor: Color) -> Color { borderColor.opacity(0.68) }

    static let shadowOpacity: Double = 0.16
    static let shadowRadius: CGFloat = 14
    static let shadowYOffset: CGFloat = 8
}

// MARK: - Card Frame Modifier (borders + shadow only)

private struct GluVibCardFrameModifier: ViewModifier {

    let borderColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous)
                    .fill(GluVibCardStyle.backgroundFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous)
                            .stroke(
                                GluVibCardStyle.highlightStroke,
                                lineWidth: GluVibCardStyle.strokeWidth     // uses central thickness
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous)
                            .stroke(
                                GluVibCardStyle.domainStroke(borderColor),
                                lineWidth: GluVibCardStyle.strokeWidth     // uses central thickness
                            )
                    )
                    .shadow(
                        color: .black.opacity(GluVibCardStyle.shadowOpacity),
                        radius: GluVibCardStyle.shadowRadius,
                        x: 0,
                        y: GluVibCardStyle.shadowYOffset
                    )
            )
    }
}

// MARK: - Public API

extension View {

    /// Applies the unified GluVib card frame (border + shadow) without changing content layout.
    func gluVibCardFrame(domainColor: Color) -> some View {
        self.modifier(GluVibCardFrameModifier(borderColor: domainColor))
    }
}

// MARK: - Preview

#Preview("GluVibCardStyle – Card Frame Only") {
    VStack(spacing: 16) {

        VStack(alignment: .leading, spacing: 10) {
            Text("Demo Card")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.Glu.activityDomain.opacity(0.20))
                .frame(height: 120)

            Text("Only border/radius/shadow are controlled.")
                .font(.caption)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .gluVibCardFrame(domainColor: Color.Glu.activityDomain)

        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.Glu.nutritionDomain.opacity(0.18))
            .frame(height: 180)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .gluVibCardFrame(domainColor: Color.Glu.nutritionDomain)
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
