//
//  DailyMovementSplitEntry.swift
//  GluVibProbe
//
//  Datenmodell für den Movement-Split-Chart.
//  Enthält pro Tag eine 24h-Aufteilung in:
//
//  - sleepMorningMinutes   → Schlaf von 00:00 bis zum Aufwachen
//  - sleepEveningMinutes   → Schlaf von Einschlafzeit bis 24:00
//  - sedentaryMinutes      → sitzende / ruhende Zeit
//  - activeMinutes         → MoveTime / aktive Minuten
//
//  WICHTIG:
//  Für die erste Version wird der Sleep-Split (Morning/Evening) im
//  HealthStore+MovementSplit approximiert:
//  - max. 8 h werden als "Morning Sleep" gewertet
//  - Rest als "Evening Sleep"
//
//  Später kann diese Logik durch exakte Sleep-Sample-Auswertung
//  ersetzt werden, OHNE diese Struktur zu ändern.
//

import Foundation

struct DailyMovementSplitEntry: Identifiable {

    let id = UUID()
    let date: Date

    /// Schlaf von 00:00 bis zum Aufwachen des Tages (Minuten)
    let sleepMorningMinutes: Int        // !!! UPDATED

    /// Schlaf von abends bis Mitternacht (Minuten)
    let sleepEveningMinutes: Int        // !!! NEW

    /// Sedentary-Zeit (Sitzen / wenig Bewegung, Minuten)
    let sedentaryMinutes: Int

    /// Aktive Minuten (MoveTime / Exercise etc.)
    let activeMinutes: Int
}
