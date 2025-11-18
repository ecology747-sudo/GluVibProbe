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

    // 🔹 Mindestabstand in "Werte-Einheiten" (mg/dL oder mmol/L)
    var minGap: Double = 10

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            // 👉 Effektive Breite der Spur = Bereich zwischen Knopf-Zentren
            let trackX = knobSize / 2
            let trackWidth = width - knobSize

            // Normierte Werte 0–1
            let lowerNorm = (lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            let upperNorm = (upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)

            // X-Positionen der Knopf-ZENTREN entlang der Spur
            let lowerCenterX = trackX + lowerNorm * trackWidth
            let upperCenterX = trackX + upperNorm * trackWidth

            ZStack(alignment: .leading) {

                // Hintergrundspur (grau)
                Capsule()
                    .fill(Color.gray.opacity(1))
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: trackX)

                // Aktiver Bereich (grün)
                Capsule()
                    .fill(Color.green)
                    .frame(
                        width: max(upperCenterX - lowerCenterX, 0),
                        height: trackHeight
                    )
                    .offset(x: lowerCenterX)

                // MARK: - LINKER KNOB
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(Color.green.opacity(0.9), lineWidth: 2)
                    )
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: lowerCenterX - knobSize / 2)
                    .gesture(
                        DragGesture().onChanged { value in
                            // Zentrum auf Spur begrenzen
                            let clampedCenterX = min(
                                max(value.location.x, trackX),
                                trackX + trackWidth
                            )

                            let norm = (clampedCenterX - trackX) / trackWidth
                            let newVal = range.lowerBound + norm * (range.upperBound - range.lowerBound)

                            // 🔹 Mindestabstand nach rechts einhalten
                            let maxAllowed = upperValue - minGap
                            let clampedVal = min(
                                max(newVal, range.lowerBound),
                                maxAllowed
                            )

                            lowerValue = clampedVal
                        }
                    )

                // MARK: - RECHTER KNOB
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(Color.green.opacity(0.9), lineWidth: 2)
                    )
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: upperCenterX - knobSize / 2)
                    .gesture(
                        DragGesture().onChanged { value in
                            // Zentrum auf Spur begrenzen
                            let clampedCenterX = min(
                                max(value.location.x, trackX),
                                trackX + trackWidth
                            )

                            let norm = (clampedCenterX - trackX) / trackWidth
                            let newVal = range.lowerBound + norm * (range.upperBound - range.lowerBound)

                            // 🔹 Mindestabstand nach links einhalten
                            let minAllowed = lowerValue + minGap
                            let clampedVal = max(
                                min(newVal, range.upperBound),
                                minAllowed
                            )

                            upperValue = clampedVal
                        }
                    )
            }
        }
    }
}
