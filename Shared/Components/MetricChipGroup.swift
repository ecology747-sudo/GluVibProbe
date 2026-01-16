//
//  MetricChipGroup.swift
//  GluVibProbe
//

import SwiftUI

struct MetricChipGroup: View {

    // MARK: - Inputs (Rows)

    private let row1: [String]
    private let row2: [String]

    let selected: String
    let accent: Color
    let onSelect: (String) -> Void

    // MARK: - Init (Default / Backwards compatible)

    init(
        metrics: [String],
        selected: String,
        accent: Color,
        onSelect: @escaping (String) -> Void
    ) {
        self.row1 = Array(metrics.prefix(3))
        self.row2 = Array(metrics.dropFirst(3))
        self.selected = selected
        self.accent = accent
        self.onSelect = onSelect
    }

    // MARK: - Init (Explicit rows)

    init(
        row1: [String],
        row2: [String],
        selected: String,
        accent: Color,
        onSelect: @escaping (String) -> Void
    ) {
        self.row1 = row1
        self.row2 = row2
        self.selected = selected
        self.accent = accent
        self.onSelect = onSelect
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                ForEach(row1, id: \.self) { metric in
                    chip(metric)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                ForEach(row2, id: \.self) { metric in
                    chip(metric)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Chip

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
                .padding(.horizontal, 11) // ✅ UPDATED: was 14, reduces chip width -> less text scaling
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

// MARK: - Preview

#Preview("MetricChipGroup") {
    VStack(spacing: 16) {

        MetricChipGroup(
            metrics: [
                "Steps",
                "Move Time",
                "Active Time",
                "Activity Energy",
                "Movement Split"
            ],
            selected: "Activity Energy",
            accent: Color.Glu.activityAccent,
            onSelect: { _ in }
        )

        MetricChipGroup(
            row1: ["Bolus", "Basal", "Bolus/Basal Ratio", "Carb/Bolus Ratio"],
            row2: ["TIR", "SD", "CV", "GMI", "Mean"],
            selected: "SD",
            accent: Color.Glu.metabolicDomain,
            onSelect: { _ in }
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
