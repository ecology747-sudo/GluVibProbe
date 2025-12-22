//
//  KPICard.swift
//  GluVibProbe
//

import SwiftUI

struct KPICard: View {

    let title: String
    let valueText: String
    let unit: String?
    let valueColor: Color?

    private let domain: MetricDomain

    init(
        title: String,
        valueText: String,
        unit: String? = nil,
        valueColor: Color? = nil,
        domain: MetricDomain = .body
    ) {
        self.title = title
        self.valueText = valueText
        self.unit = unit
        self.valueColor = valueColor
        self.domain = domain
    }

    private var borderColor: Color { domain.accentColor }

    private var backgroundFill: some ShapeStyle {        // CHANGED: neutral, wie vorher (Lesbarkeit)
        Color.Glu.backgroundSurface
    }

    private var highlightStroke: Color { Color.white.opacity(0.35) }
    private var domainStroke: Color { borderColor.opacity(0.55) }
    private let strokeWidth: CGFloat = 1.6
    private let shadowOpacity: Double = 0.12
    private let shadowRadius: CGFloat = 8
    private let shadowYOffset: CGFloat = 4

    var body: some View {
        VStack(alignment: .center, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

            HStack(alignment: .firstTextBaseline, spacing: 4) {

                Text(valueText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(valueColor ?? Color.Glu.primaryBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(highlightStroke, lineWidth: strokeWidth)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(domainStroke, lineWidth: strokeWidth)
                )
                .shadow(
                    color: .black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
        )
    }
}

#Preview("KPICard – Neutral Surface") {
    VStack(spacing: 12) {
        HStack(spacing: 10) {
            KPICard(title: "Target", valueText: "10 000", domain: .activity)
            KPICard(title: "Current", valueText: "8 532", domain: .activity)
            KPICard(title: "Delta", valueText: "− 1 468", valueColor: .red, domain: .activity)
        }

        HStack(spacing: 10) {
            KPICard(title: "Carbs", valueText: "210", unit: "g", domain: .nutrition)
            KPICard(title: "Energy", valueText: "2 350", unit: "kcal", domain: .nutrition)
            KPICard(title: "Sleep", valueText: "7.2", unit: "h", domain: .body)
        }
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
