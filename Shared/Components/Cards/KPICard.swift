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

    var body: some View {
        VStack(alignment: .center, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .center)          // !!! UPDATED
                .multilineTextAlignment(.center)                          // !!! UPDATED

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
            .frame(maxWidth: .infinity, alignment: .center)              // !!! UPDATED
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: domain.accentColor)
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
