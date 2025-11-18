//
//  LowerUpperRangeGlucoseSlider.swift
//  GluVibProbe
//

import SwiftUI

struct LowerUpperRangeGlucoseSlider: View {
    @Binding var lowerValue: Double          // linker Wert (z.B. sehr niedrig)
    @Binding var upperValue: Double          // rechter Wert (z.B. sehr hoch)
    let range: ClosedRange<Double>          // z.B. 40...400 oder 2...22
    let minGap: Double                      // Mindestabstand zwischen beiden Werten

    var safeColor: Color = .gray.opacity(1)     // Innenbereich (Safe Zone)
    var riskColor: Color = .red.opacity(0.9)      // Außenbereiche (Risk)

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            // 👉 Effektive Spur: zwischen den Knopf-Zentren
            let trackX = knobSize / 2
            let trackWidth = width - knobSize

            // normierte Werte 0–1
            let lowerNorm = (lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            let upperNorm = (upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)

            // reale X-Positionen der Knopfzentren
            let lowerCenterX = trackX + lowerNorm * trackWidth
            let upperCenterX = trackX + upperNorm * trackWidth

            ZStack(alignment: .leading) {

                // 1️⃣ Risiko-Gesamtspur (ROT) → ganz unten
                Capsule()
                    .fill(riskColor)
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: trackX)

                // 2️⃣ Safe Zone (GRAU) → liegt korrekt über dem Rot
                Capsule()
                    .fill(safeColor)
                    .frame(
                        width: max(upperCenterX - lowerCenterX, 0),
                        height: trackHeight
                    )
                    .offset(x: lowerCenterX)

                // 3️⃣ linker Knopf
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(riskColor, lineWidth: 2))
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: lowerCenterX - knobSize / 2)
                    .gesture(
                        DragGesture().onChanged { value in
                            let clampedCenterX = min(
                                max(value.location.x, trackX),
                                trackX + trackWidth
                            )

                            let norm = (clampedCenterX - trackX) / trackWidth
                            let candidate = range.lowerBound + norm * (range.upperBound - range.lowerBound)

                            // Mindestabstand nach rechts
                            let maxAllowed = upperValue - minGap
                            let clampedValue = min(candidate, maxAllowed)

                            lowerValue = max(clampedValue, range.lowerBound)
                        }
                    )

                // 4️⃣ rechter Knopf
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(riskColor, lineWidth: 2))
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: upperCenterX - knobSize / 2)
                    .gesture(
                        DragGesture().onChanged { value in
                            let clampedCenterX = min(
                                max(value.location.x, trackX),
                                trackX + trackWidth
                            )

                            let norm = (clampedCenterX - trackX) / trackWidth
                            let candidate = range.lowerBound + norm * (range.upperBound - range.lowerBound)

                            // Mindestabstand nach links
                            let minAllowed = lowerValue + minGap
                            let clampedValue = max(candidate, minAllowed)

                            upperValue = min(clampedValue, range.upperBound)
                        }
                    )
            }
        }
    }
}
