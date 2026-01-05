//
//  GlucoseSummaryCardDesign.swift
//  GluVibProbe
//
//  DESIGN CONCEPT (Premium Metabolic Overview)
//
//  GOAL (this step):
//  - SD | Average GMI (90) | CV = SAME tile component
//  - Same height, same spacing, same typography
//  - No stacked/inline differences per tile
//

import SwiftUI

// ============================================================
// MARK: - Glucose Summary Card
// ============================================================

struct GlucoseSummaryCardDesign: View {

    let avgGlucoseMgdl: Int
    let avgTirPercent: Int
    let avgSdMgdl: Int
    let avgCvPercent: Int
    let gmi90dPercent: Double

    private let barHeight: CGFloat = 12
    private let tirThreshold: Double = 0.70
    private let maxGlucoseMgdl: Double = 250

    // ============================================================
    // MARK: - Vertical Layout Controls (tweakable)
    // ============================================================

    private let cardPadding: CGFloat = 16

    private let gapHeaderToGlucose: CGFloat = 6
    private let gapGlucoseValueToBar: CGFloat = 3

    private let gapGlucoseToBadges: CGFloat = 20
    private let gapBadgesToTir: CGFloat = 4

    private let gapTirValueToBar: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            header
            Gap(gapHeaderToGlucose)

            glucoseSection
            Gap(gapGlucoseToBadges)

            sdGmiCvSection
            Gap(gapBadgesToTir)

            tirSection
        }
        .padding(cardPadding)
        .gluVibCardFrame(domainColor: Color.Glu.metabolicDomain)
    }
}

// ============================================================
// MARK: - Sections (Top → Bottom)
// ============================================================

private extension GlucoseSummaryCardDesign {

    var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(Color.Glu.primaryBlue)

            Text("Glucose Summary")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)

            Spacer()
        }
    }

    // ====================================================
    // Ø Glucose
    // ====================================================

    var glucoseSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("Ø")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("\(avgGlucoseMgdl)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("mg/dL")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()
            }

            Gap(gapGlucoseValueToBar)

            GlucoseFiveZoneBar(
                valueMgdl: Double(avgGlucoseMgdl),
                maxMgdl: maxGlucoseMgdl,
                height: barHeight
            )
            .frame(height: barHeight)
        }
    }

    // ====================================================
    // SD + Average GMI (90) + CV (uniform tiles)
    // ====================================================

    var sdGmiCvSection: some View {
        HStack(spacing: 12) {

            UniformMiniMetricTile(
                title: "SD",
                value: "\(avgSdMgdl) mg/dL"
            )

            UniformMiniMetricTile(
                title: " GMI (90)",
                value: String(format: "%.1f%%", gmi90dPercent)
            )

            // ✅ CHANGE: CV target styled like "Target ≥ 70%" (separate text)
            UniformMiniMetricTile(
                title: "CV",
                value: "\(avgCvPercent)%",
                secondaryValue: "(< 36%)"
            )
        }
    }

    // ====================================================
    // Ø TIR
    // ====================================================

    var tirSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("TIR ")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("\(avgTirPercent)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text("(≥ 70%)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))
            }

            Gap(gapTirValueToBar)

            TIRBar(
                percent: Double(avgTirPercent) / 100.0,
                threshold: tirThreshold,
                height: barHeight
            )
            .frame(height: barHeight)
        }
    }
}

// ============================================================
// MARK: - Adjustable Gap Helper
// ============================================================

private struct Gap: View {
    let height: CGFloat
    init(_ height: CGFloat) { self.height = height }
    var body: some View { Color.clear.frame(height: height) }
}

// ============================================================
// MARK: - Uniform Mini Metric Tile (SINGLE source of typography)
// ============================================================

private struct UniformMiniMetricTile: View {

    let title: String
    let value: String
    let secondaryValue: String?

    init(
        title: String,
        value: String,
        secondaryValue: String? = nil
    ) {
        self.title = title
        self.value = value
        self.secondaryValue = secondaryValue
    }

    private let titleFont: Font = .system(size: 13, weight: .bold)
    private let valueFont: Font = .system(size: 19, weight: .bold)
    private let secondaryFont: Font = .caption2.weight(.semibold)

    private let fixedHeight: CGFloat = 54

    var body: some View {
        VStack(alignment: .center, spacing: 6) {

            Text(title)
                .font(titleFont)
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.85))

            HStack(alignment: .lastTextBaseline, spacing: 4) {

                Spacer(minLength: 0)

                Text(value)
                    .font(valueFont)
                    .foregroundColor(Color.Glu.primaryBlue)

                if let secondaryValue {
                    Text(secondaryValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: fixedHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Glu.backgroundSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.Glu.metabolicDomain.opacity(0.65), lineWidth: 1.2)
        )
    }
}
// ============================================================
// MARK: - Shared Bar Background
// ============================================================

private struct BarBackground: View {

    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.Glu.primaryBlue.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: height / 2)
                    .stroke(Color.Glu.primaryBlue.opacity(0.95), lineWidth: 1.2)
            )
    }
}

// ============================================================
// MARK: - Glucose Five-Zone Bar
// ============================================================

private struct GlucoseFiveZoneBar: View {

    let valueMgdl: Double
    let maxMgdl: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = min(max(valueMgdl / max(maxMgdl, 1), 0), 1)
            let markerX = width * fraction

            ZStack(alignment: .leading) {

                BarBackground(height: height)

                HStack(spacing: 0) {
                    Rectangle().fill(Color.Glu.acidCGMRed).frame(width: width * 0.05)
                    Rectangle().fill(Color.yellow.opacity(0.80)).frame(width: width * 0.08)
                    Rectangle().fill(Color.Glu.metabolicDomain).frame(width: width * 0.74)
                    Rectangle().fill(Color.yellow.opacity(0.80)).frame(width: width * 0.09)
                    Rectangle().fill(Color.Glu.acidCGMRed).frame(width: width * 0.04)
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: height / 2))

                TriangleMarker()
                    .fill(Color.Glu.metabolicDomain)
                    .overlay(
                        TriangleMarker()
                            .stroke(Color.Glu.primaryBlue, lineWidth: 0.5)
                    )
                    .frame(width: 20, height: 20)
                    .offset(x: markerX - 10, y: -20)
            }
        }
    }
}

// ============================================================
// MARK: - TIR Bar (Target Marker on Top)
// ============================================================

private struct TIRBar: View {

    let percent: Double
    let threshold: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = width * min(max(percent, 0), 1)
            let targetX = width * min(max(threshold, 0), 1)

            ZStack(alignment: .leading) {

                // Background (inkl. helles Fill)
                BarBackground(height: height)

                // Green fill (links rund, rechts eckig)
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: height / 2,
                        bottomLeading: height / 2,
                        bottomTrailing: 0,
                        topTrailing: 0
                    )
                )
                .fill(Color.Glu.metabolicDomain)
                .frame(width: fillWidth, height: height)
            }
            // ✅ NEW: Stroke always on top (so it stays visible over the green fill)
            .overlay {
                RoundedRectangle(cornerRadius: height / 2)
                    .stroke(Color.Glu.primaryBlue.opacity(0.85), lineWidth: 1)
            }
            // Target marker stays on top as before
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.Glu.acidCGMRed)
                    .frame(width: 3, height: height + 6)
                    .offset(x: targetX - 1.5, y: -3)
                    .zIndex(999)
            }
            .clipped(antialiased: false)
        }
    }
}

// ============================================================
// MARK: - Triangle Marker Shape
// ============================================================

private struct TriangleMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Glucose Summary Card (Design)") {
    GlucoseSummaryCardDesign(
        avgGlucoseMgdl: 132,
        avgTirPercent: 74,
        avgSdMgdl: 42,
        avgCvPercent: 31,
        gmi90dPercent: 6.8
    )
    .padding(16)
}
