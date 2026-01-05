//
//  LowerUpperRangeGlucoseSlider.swift
//  GluVibProbe
//

import SwiftUI

struct LowerUpperRangeGlucoseSlider: View {

    @Binding var lowerValue: Double          // linker Wert (z.B. sehr niedrig)
    @Binding var upperValue: Double          // rechter Wert (z.B. sehr hoch)
    let range: ClosedRange<Double>           // z.B. 40...400 oder 2.2...22.2
    let minGap: Double                       // Mindestabstand zwischen beiden Werten

    // ✅ NEW: Step-Snapping (z.B. 5 mg/dL). nil => frei
    var step: Double? = nil

    // ✅ UPDATED: Domain-Colors (wie Bar-Chart)
    var safeColor: Color = Color.Glu.metabolicDomain.opacity(0.85)     // innen (safe)
    var riskColor: Color = Color.Glu.acidCGMRed.opacity(0.92)          // außen (risk)
    var knobStrokeColor: Color = Color.Glu.acidCGMRed                  // Knob-Stroke

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            // Effektive Spur: zwischen den Knopf-Zentren
            let trackX = knobSize / 2
            let trackWidth = width - knobSize

            // normierte Werte 0–1
            let lowerNorm = (lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            let upperNorm = (upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)

            // reale X-Positionen der Knopfzentren
            let lowerCenterX = trackX + lowerNorm * trackWidth
            let upperCenterX = trackX + upperNorm * trackWidth

            ZStack(alignment: .leading) {

                // Risiko-Gesamtspur (rot)
                Capsule()
                    .fill(riskColor)
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: trackX)

                // Safe Zone (grün) – zwischen den Knöpfen
                Capsule()
                    .fill(safeColor)
                    .frame(width: max(upperCenterX - lowerCenterX, 0), height: trackHeight)
                    .offset(x: lowerCenterX)

                // linker Knopf
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(knobStrokeColor.opacity(0.95), lineWidth: 2))
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: lowerCenterX - knobSize / 2)
                    .gesture(
                        DragGesture().onChanged { value in
                            let clampedCenterX = min(max(value.location.x, trackX), trackX + trackWidth)
                            let norm = (clampedCenterX - trackX) / trackWidth
                            let raw = range.lowerBound + norm * (range.upperBound - range.lowerBound)

                            // ✅ Step-Snap
                            let snapped = snap(raw, step: step)

                            // Mindestabstand nach rechts
                            let maxAllowed = upperValue - minGap
                            let clampedValue = min(snapped, maxAllowed)

                            lowerValue = max(clampedValue, range.lowerBound)
                        }
                    )

                // rechter Knopf
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(knobStrokeColor.opacity(0.95), lineWidth: 2))
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: upperCenterX - knobSize / 2)
                    .gesture(
                        DragGesture().onChanged { value in
                            let clampedCenterX = min(max(value.location.x, trackX), trackX + trackWidth)
                            let norm = (clampedCenterX - trackX) / trackWidth
                            let raw = range.lowerBound + norm * (range.upperBound - range.lowerBound)

                            // ✅ Step-Snap
                            let snapped = snap(raw, step: step)

                            // Mindestabstand nach links
                            let minAllowed = lowerValue + minGap
                            let clampedValue = max(snapped, minAllowed)

                            upperValue = min(clampedValue, range.upperBound)
                        }
                    )
            }
        }
    }

    // MARK: - Helpers

    private func snap(_ value: Double, step: Double?) -> Double {
        guard let step, step > 0 else { return value }
        return (value / step).rounded() * step
    }
}
