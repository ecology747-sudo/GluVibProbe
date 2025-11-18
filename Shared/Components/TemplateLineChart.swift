//
//  TemplateLineChart.swift
//  GluVibProbe
//

import SwiftUI

struct TemplateLineChart: View {
    let data: [Double]
    var lineColor: Color = .accentColor
    var lineWidth: CGFloat = 2
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1️⃣ Kein Datenfall
                if data.isEmpty {
                    Text("No data")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 2️⃣ Hintergrund (optional leicht)
                    Color.clear
                    
                    // 3️⃣ Linie
                    linePath(in: geo.size)
                        .stroke(lineColor, lineWidth: lineWidth)
                }
            }
        }
    }
    
    // MARK: - Line Path
    private func linePath(in size: CGSize) -> Path {
        let width = size.width
        let height = size.height
        
        // Sicherstellen, dass wir mindestens 2 Punkte haben
        guard data.count > 1 else {
            return Path()
        }
        
        // Min/Max für Skalierung
        guard let minValue = data.min(),
              let maxValue = data.max(),
              maxValue != minValue else {
            // Alle Werte gleich → horizontale Linie in der Mitte
            let midY = height / 2
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: width, y: midY))
            return path
        }
        
        let valueRange = maxValue - minValue
        let stepX = width / CGFloat(data.count - 1)
        
        func yPosition(for value: Double) -> CGFloat {
            // höherer Wert → höher im Chart (also kleineres y)
            let normalized = (value - minValue) / valueRange   // 0...1
            let y = height * (1 - CGFloat(normalized))         // invertieren
            return y
        }
        
        var path = Path()
        
        for index in data.indices {
            let x = CGFloat(index) * stepX
            let y = yPosition(for: data[index])
            
            if index == data.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

#Preview {
    // Demo mit Mock-Daten
    TemplateLineChart(
        data: (0..<30).map { _ in Double(6000 + Int.random(in: -1500...2000)) },
        lineColor: .blue
    )
    .frame(height: 180)
    .padding()
}
