import SwiftUI

extension Color {
    struct Glu {
        // MARK: - Brand / Basis-Farben (direkt aus dem Asset-Katalog)

        /// Primäre Markenfarbe (z.B. Texte, Buttons, Units-Domain)
        static let primaryBlue       = Color("GluPrimaryBlue")

        /// Dunkler Hintergrund (z.B. für spätere Dark-/Card-Designs)
        static let backgroundNavy    = Color("GluBackgroundNavy")

        /// Heller Surface-Hintergrund (Dashboard, Karten-Background)
        static let backgroundSurface = Color("GluBackgroundSurface")

        // MARK: - Domain-Farben (jede Domain genau eine Farbe)

        /// BODY-Domain (Weight, Sleep, HR, Body-Settings)
        /// – Orange, wie in deiner BodySettingsSection-Kachel
        static let bodyDomain        = Color("GluActivityOrange")

        /// ACTIVITY-Domain (Steps, Activity Energy, Workouts)
        /// – Rot (GlubodyRed), wie in der ActivitySettingsSection
        static let activityDomain    = Color("GlubodyRed")

        /// METABOLIC-Domain (Glucose, Insulin, TIR)
        /// – LIME-Green / Glow
        static let metabolicDomain   = Color("GluLimeGlow")

        /// NUTRITION-Domain (Carbs, Protein, Fat, Calories)
        /// – Aqua / Türkis
        static let nutritionDomain   = Color("GluAccentAqua")

        /// UNITS / globale Controls
        /// – läuft über die Primärfarbe
        static let unitsDomain       = primaryBlue

        // MARK: - Legacy-Namen (nur damit dein bestehender Code nicht bricht)
        // Diese kannst du später Schritt für Schritt entfernen,
        // wenn du überall auf die neuen Domain-Namen umgestellt hast.

        // Früher: "Accent"-Farben
        static let accentLime        = metabolicDomain
        static let accentAqua        = nutritionDomain

        // Früher: "ActivityOrange" / "ActivityRed"
        static let activityOrange    = bodyDomain
        static let activityRed       = activityDomain

        // Früher: Domain-Aliasse
        static let activityAccent    = activityDomain
        static let bodyAccent        = bodyDomain
        static let metabolicAccent   = metabolicDomain
        static let nutritionAccent   = nutritionDomain

        // Ganz alt: bodyActivityAccent
        static let bodyActivityAccent = bodyDomain
    }
}
