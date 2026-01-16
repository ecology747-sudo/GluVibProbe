//
//  MetabolicRingRowCard.swift
//  GluVibProbe
//

import SwiftUI

// MARK: - Metabolic Ring Row Card (Reusable UI Component)

struct MetabolicRingRowCard: View {

    struct RingInput: Identifiable {
        let id = UUID()
        let label: String
        let avgValue: Double
    }

    // MARK: - Inputs (UI only)

    let title: String
    let todayLabel: String
    let todayValue: Double

    let rings: [RingInput]       // 4 items expected
    let accentColor: Color
    let onTap: () -> Void

    // MARK: - Layout Tokens

    private let ringLineWidth: CGFloat = 7
    private let ringValueSpacing: CGFloat = 4

    private let todayValueFontSize: CGFloat = 30
    private let todayValueYOffset: CGFloat = -1
    private let todayLabelYOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            // Compact tuning for iPhone SE / narrow widths
            let isNarrow = width < 360

            let ringDiameter: CGFloat = isNarrow ? 42 : 50
            let ringSlotInnerPadding: CGFloat = isNarrow ? 4 : 8
            let rowSpacing: CGFloat = isNarrow ? 6 : 10
            let todayBlockWidth: CGFloat = isNarrow ? 58 : 70

            let ringLabelFontSize: CGFloat = isNarrow ? 13 : 15

            // make avg number below ring clearly bigger + bolder
            let ringAvgFontSize: CGFloat = isNarrow ? 16 : 18

            VStack(alignment: .leading, spacing: 8) {

                // Header
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.Glu.primaryBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Row: Today + 4 rings (always one row)
                HStack(alignment: .top, spacing: rowSpacing) {

                    // LEFT: Today block
                    VStack(alignment: .center, spacing: 2) {

                        Text(todayLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.Glu.primaryBlue.opacity(0.90))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .offset(x: 0, y: todayLabelYOffset)

                        Text(format1(todayValue))
                            .font(.system(size: todayValueFontSize, weight: .bold))
                            .foregroundColor(Color.Glu.primaryBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .offset(x: 2, y: todayValueYOffset)
                    }
                    .frame(width: todayBlockWidth, height: ringDiameter, alignment: .center)

                    // RIGHT: 4 rings
                    HStack(spacing: 0) {
                        ForEach(rings) { item in
                            MetabolicAvgRing(
                                diameter: ringDiameter,
                                lineWidth: ringLineWidth,
                                valueSpacing: ringValueSpacing,
                                label: item.label,
                                labelFontSize: ringLabelFontSize,
                                avgFontSize: ringAvgFontSize,
                                todayValue: todayValue,
                                avgValue: item.avgValue,
                                ringColor: accentColor
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, ringSlotInnerPadding)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)

            // !!! IMPORTANT:
            // Do NOT force maxWidth here. The parent (Overview) owns horizontal insets.
            .gluVibCardFrame(domainColor: accentColor)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        // Stable height for GeometryReader container (prevents visual overlap into next cards)
        .frame(height: 110)
    }

    private func format1(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.0001 { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Internal Ring (UI only)

private struct MetabolicAvgRing: View {

    let diameter: CGFloat
    let lineWidth: CGFloat
    let valueSpacing: CGFloat

    let label: String
    let labelFontSize: CGFloat
    let avgFontSize: CGFloat

    let todayValue: Double
    let avgValue: Double
    let ringColor: Color

    var body: some View {

        let avg = max(avgValue, 0.0001)
        let ratio = min(max(todayValue / avg, 0.0), 1.0)

        VStack(alignment: .center, spacing: valueSpacing) {

            ZStack {
                Circle()
                    .stroke(Color.Glu.primaryBlue.opacity(0.10), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("Ø")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(label)
                        .font(.system(size: labelFontSize, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .multilineTextAlignment(.center)
            }
            .frame(width: diameter, height: diameter)

            Text(formatAvg(avgValue))
                .font(.system(size: avgFontSize, weight: .bold))
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func formatAvg(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.0001 { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview("MetabolicRingRowCard") {
    VStack(spacing: 16) {
        MetabolicRingRowCard(
            title: "Bolus (U)",
            todayLabel: "Today",
            todayValue: 10,
            rings: [
                .init(label: "7d", avgValue: 17),
                .init(label: "14d", avgValue: 15),
                .init(label: "30d", avgValue: 14),
                .init(label: "90d", avgValue: 16)
            ],
            accentColor: Color.Glu.metabolicDomain,
            onTap: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
