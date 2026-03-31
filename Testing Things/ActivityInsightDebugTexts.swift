//
//  ActivityInsightDebugTexts.swift
//  GluVibProbe
//
//  Domain: Activity / Insight Debug Text Layer
//
//  Purpose
//  - Temporary non-localized text source for the new Activity insight engine.
//  - Used only to decouple engine logic from old L10n text constraints during V1 testing.
//

import Foundation

enum ActivityInsightTextKey {
    case earlyDayStillOpen
    case clearlyAboveOverall
    case goalReachedButMixed
    case activeButNotClearlyAbove
    case typicalDay
    case mixedDay
    case belowOverall
    case belowOverallLate
    case sedentaryHeavyLate
    case workoutRecency
}

enum ActivityInsightDebugTexts {

    static func resolve(_ key: ActivityInsightTextKey) -> String {
        switch key {

        case .earlyDayStillOpen:
            return "Der Tag ist noch offen. Für eine belastbare Aktivitätsbewertung ist es aktuell noch zu früh."

        case .clearlyAboveOverall:
            return "Heute liegst du bei Schritten und aktiver Energie klar über deinem üblichen Bereich. Das spricht für einen insgesamt starken Aktivitätstag."

        case .goalReachedButMixed:
            return "Dein Schrittziel ist erreicht. Insgesamt liegt der Tag aber nicht in allen Aktivitätsdimensionen klar über deinem üblichen Bereich."

        case .activeButNotClearlyAbove:
            return "Heute ist bereits solide Aktivität vorhanden. Der Tag wirkt aktiv, aber noch nicht klar über deinem üblichen Niveau."

        case .typicalDay:
            return "Heute liegt deine Aktivität insgesamt ungefähr im Bereich deiner üblichen Tage."

        case .mixedDay:
            return "Heute zeigt sich ein gemischtes Bild: einzelne Aktivitätssignale sind solide, das Gesamtbild ist aber nicht klar über oder unter deinem üblichen Bereich."

        case .belowOverall:
            return "Heute liegt deine Aktivität klar unter deinem üblichen Bereich. Sowohl Bewegung als auch aktive Energie blieben unter deinem typischen Niveau."

        case .belowOverallLate:
            return "Der Tag ist weitgehend abgeschlossen. Heute lag deine Aktivität klar unter deinem üblichen Bereich."

        case .sedentaryHeavyLate:
            return "Der Tag wirkt heute über weite Strecken sedentär geprägt. Bis jetzt gibt es keine klare Kompensation durch Bewegung oder aktive Energie."

        case .workoutRecency:
            return "Seit deinem letzten Workout ist etwas Zeit vergangen. Für heute ist das aber nur ein Kontextsignal und kein dominanter Tagesfaktor."
        }
    }
}
