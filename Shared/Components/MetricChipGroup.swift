//
//  MetricChipGroup.swift
//  GluVibProbe
//
//  Zentrale Metric-Chip-Leiste (2 Reihen, linksbündig)
//  - Active: gefüllt + weißer Rand + weiße Schrift + leicht größer
//  - Inactive: transparente Füllung + Domain-Outline (sichtbare Form) + Schatten bleibt
//

import SwiftUI

struct MetricChipGroup: View {

    let metrics: [String]
    let selected: String
    let accent: Color
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                ForEach(metrics.prefix(3), id: \.self) { metric in
                    chip(metric)
                }
            }

            HStack(spacing: 6) {
                ForEach(metrics.suffix(from: 3), id: \.self) { metric in
                    chip(metric)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func chip(_ metric: String) -> some View {
        let isActive = (metric == selected)

        let strokeColor: Color = isActive
            ? Color.white.opacity(0.90)
            : accent.opacity(0.90)

        let lineWidth: CGFloat = isActive ? 1.6 : 1.2

        let backgroundFill: some ShapeStyle = isActive
            ? LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            : LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )

        let shadowOpacity: Double = isActive ? 0.25 : 0.15
        let shadowRadius: CGFloat = isActive ? 4 : 2.5
        let shadowYOffset: CGFloat = isActive ? 2 : 1.5

        return Button {
            onSelect(metric)
        } label: {
            Text(metric)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(
                    Capsule().fill(backgroundFill)
                )
                .overlay(
                    Capsule().stroke(strokeColor, lineWidth: lineWidth)
                )
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
                .foregroundStyle(
                    isActive ? Color.white : Color.Glu.primaryBlue.opacity(0.95)
                )
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

#Preview("MetricChipGroup") {
    VStack(spacing: 16) {
        MetricChipGroup(
            metrics: [
                "Steps",
                "Move Time",          // ✅ NEW
                "Active Time",
                "Activity Energy",
                "Movement Split"
            ],
            selected: "Activity Energy",
            accent: Color.Glu.activityAccent,
            onSelect: { _ in }
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
