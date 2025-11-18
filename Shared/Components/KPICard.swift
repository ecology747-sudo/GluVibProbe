// Datei: KPICard.swift
// GluVibProbe – universelle KPI-Anzeige

import SwiftUI

struct KPICard: View {
    let title: String        // z.B. "Steps Today"
    let value: String        // z.B. "4,582"
    let unit: String?        // z.B. "steps" oder nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold))

                if let unit = unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .cornerRadius(12)
    }
}

#Preview {
    KPICard(title: "Steps Today", value: "8,452", unit: "steps")
}
