//
//  RangeSlider.swift
//  GluVibProbe
//

import SwiftUI

// Doppel-Slider-Komponente (z.B. TIR)
struct RangeSlider: View {

    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>

    // Mindestabstand in "Werte-Einheiten" (mg/dL oder mmol/L)
    var minGap: Double = 10

    // ✅ NEW: Step-Snapping (z.B. 5 mg/dL). nil => frei
    var step: Double? = nil

    // ✅ NEW: Colors (Domain-Style)
    var trackColor: Color = Color.Glu.primaryBlue.opacity(0.22)
    var activeColor: Color = Color.Glu.metabolicDomain
    var knobStrokeColor: Color = Color.Glu.metabolicDomain

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            // Effektive Breite der Spur = Bereich zwischen Knopf-Zentren
            let trackX = knobSize / 2
            let trackWidth = width - knobSize

            // Normierte Werte 0–1
            let lowerNorm = (lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            let upperNorm = (upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)

            // X-Positionen der Knopf-ZENTREN entlang der Spur
            let lowerCenterX = trackX + lowerNorm * trackWidth
            let upperCenterX = trackX + upperNorm * trackWidth

            ZStack(alignment: .leading) {

                // Hintergrundspur
                Capsule()
                    .fill(trackColor)
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: trackX)

                // Aktiver Bereich (zwischen Lower und Upper)
                Capsule()
                    .fill(activeColor)
                    .frame(width: max(upperCenterX - lowerCenterX, 0), height: trackHeight)
                    .offset(x: lowerCenterX)

                // LINKER KNOB
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(knobStrokeColor.opacity(0.95), lineWidth: 2)
                    )
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
                            let clampedVal = min(max(snapped, range.lowerBound), maxAllowed)

                            lowerValue = clampedVal
                        }
                    )

                // RECHTER KNOB
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(knobStrokeColor.opacity(0.95), lineWidth: 2)
                    )
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
                            let clampedVal = max(min(snapped, range.upperBound), minAllowed)

                            upperValue = clampedVal
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
