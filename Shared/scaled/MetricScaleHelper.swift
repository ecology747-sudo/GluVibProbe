//
//  MetricScaleHelper.swift
//  GluVibProbe
//
//  Zentrale Hilfsklasse für Y-Achsen-Skalierung.
//  - Nimmt Rohwerte ([Double]) + MetricScaleType entgegen
//  - Liefert MetricScaleResult zurück:
//      • yAxisTicks  – Werte für die Achsenmarken
//      • yMax        – oberer Wert der Skala
//      • valueLabel  – Formatter für Achsenlabels
//

import Foundation

/// Ergebnis der Skalenberechnung für einen Chart.
struct MetricScaleResult {
    let yAxisTicks: [Double]
    let yMax: Double
    let valueLabel: (Double) -> String
}

/// Zentraler Helper für alle Domains (Nutrition, Body, Metabolic).
enum MetricScaleHelper {

    // MARK: - Öffentliche API (generischer Einstieg)

    /// Generische Skalenberechnung für beliebige Metriken.
    ///
    /// - Parameter values: Rohwerte in **Anzeigeeinheit**
    ///   (z. B. kcal, kJ, g, Schritte, Stunden).
    /// - Parameter type:   Skalentyp (z. B. .nutritionEnergyDaily, .steps, .percent, ...)
    static func scale(for values: [Double], type: MetricScaleType) -> MetricScaleResult {

        let cleaned = values
            .filter { $0.isFinite && $0 >= 0 }

        let maxValue = cleaned.max() ?? 0

        switch type {

        // MARK: Nutrition – Energy (kcal / kJ)

        case .nutritionEnergyDaily:
            // Tageswerte: z. B. 0–6.000 kcal/kJ – eher feinere Schritte
            return makeScale(
                maxValue: maxValue,
                minimumSuggestedMax: 2_000,
                approxTickCount: 6,
                preferKiloSuffix: false
            )

        case .nutritionEnergyMonthly:
            // Monatswerte: deutlich höhere Summen → "k"-Beschriftung sinnvoll
            return makeScale(
                maxValue: maxValue,
                minimumSuggestedMax: 20_000,
                approxTickCount: 6,
                preferKiloSuffix: true
            )

        // MARK: Steps – große Werte mit Tsd.-Bereichen

        case .steps:
            return makeScale(
                maxValue: maxValue,
                minimumSuggestedMax: 10_000,
                approxTickCount: 6,
                preferKiloSuffix: true
            )

        // MARK: Kleine Ganzzahlen (z. B. Gewicht, Einheiten, kleinere g/kcal)

        case .smallInteger:
            return makeScale(
                maxValue: maxValue,
                minimumSuggestedMax: 10,
                approxTickCount: 5,
                preferKiloSuffix: false
            )

        // MARK: Prozent (0–100 %)

        case .percent:
            let ticks: [Double] = [0, 20, 40, 60, 80, 100]
            let label: (Double) -> String = { value in
                "\(Int(value))%"
            }
            return MetricScaleResult(
                yAxisTicks: ticks,
                yMax: 100,
                valueLabel: label
            )

        // MARK: Stunden (z. B. Schlafdauer)

        case .hours:
            // Werte in Stunden oder ähnlicher Größenordnung
            return makeScale(
                maxValue: maxValue,
                minimumSuggestedMax: 8,
                approxTickCount: 6,
                preferKiloSuffix: false
            )
        }
    }

    /// Komfort-Funktion für bestehende Aufrufe:
    /// Nutrition Energy (Daily) – verwendet intern den generischen Einstieg.
    static func energyKcalScale(for values: [Double]) -> MetricScaleResult {
        scale(for: values, type: .nutritionEnergyDaily)
    }

    // MARK: - Interne Helfer

    /// Berechnet eine "schöne" Skala anhand eines Maximalwerts.
    ///
    /// - minimumSuggestedMax: untere Grenze, damit leere Daten trotzdem eine sinnvolle Skala bekommen.
    /// - approxTickCount:     grobe Anzahl gewünschter Ticks (z. B. 5–7).
    /// - preferKiloSuffix:    ab größeren Werten "k"-Darstellung (z. B. 20k) verwenden.
    private static func makeScale(
        maxValue rawMaxValue: Double,
        minimumSuggestedMax: Double,
        approxTickCount: Int,
        preferKiloSuffix: Bool
    ) -> MetricScaleResult {

        let effectiveMax = max(rawMaxValue, minimumSuggestedMax, 0)

        // "Schöne" Schrittweite finden (1, 2, 5, 10, 20, 50, 100, ...)
        let tickStep = niceStep(forMaxValue: effectiveMax, approxTickCount: approxTickCount)

        let upper = (tickStep > 0)
            ? (ceil(effectiveMax / tickStep) * tickStep)
            : effectiveMax

        let ticks: [Double]
        if tickStep > 0 {
            ticks = stride(from: 0.0, through: upper, by: tickStep).map { $0 }
        } else {
            ticks = [0, upper]
        }

        // NumberFormatter für Integer-Werte
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let label: (Double) -> String = { value in
            guard value > 0 else { return "0" }

            if preferKiloSuffix, upper >= 10_000 {
                let kilo = value / 1_000.0
                let text = formatter.string(from: NSNumber(value: kilo)) ?? "\(Int(kilo))"
                return "\(text)k"
            } else {
                return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            }
        }

        return MetricScaleResult(
            yAxisTicks: ticks,
            yMax: upper,
            valueLabel: label
        )
    }

    /// Ermittelt eine "runde" Schrittweite anhand des Maximalwerts und der gewünschten Tickanzahl.
    ///
    /// Beispiel:
    ///  - maxValue = 2.300, approxTickCount = 6 → ~400 → Schrittweite 500
    ///  - maxValue = 25.000, approxTickCount = 6 → ~4.166 → Schrittweite 5.000
    private static func niceStep(
        forMaxValue maxValue: Double,
        approxTickCount: Int
    ) -> Double {

        guard maxValue > 0, approxTickCount > 0 else {
            return 1
        }

        let roughStep = maxValue / Double(approxTickCount)

        let exponent = floor(log10(roughStep))
        let base = pow(10.0, exponent)

        let fraction = roughStep / base

        let niceFraction: Double
        switch fraction {
        case ..<1.5:
            niceFraction = 1
        case ..<3:
            niceFraction = 2
        case ..<7:
            niceFraction = 5
        default:
            niceFraction = 10
        }

        return niceFraction * base
    }
}
