import SwiftUI

extension Color {
    struct Glu {
        // MARK: - Basis-Palette aus deinem Asset-Katalog

        static let primaryBlue       = Color("GluPrimaryBlue")
        static let accentLime        = Color("GluAccentLime")
        static let accentAqua        = Color("GluAccentAqua")
        static let backgroundNavy    = Color("GluBackgroundNavy")
        static let backgroundSurface = Color("GluBackgroundSurface")

        // Bestehendes Orange (bisherige BodyActivity-Farbe)
        static let activityOrange    = Color("GluActivityOrange")

        // Neue Rot-Farbe aus deinem Asset-Katalog
        // (Asset-Name laut dir: "GlubodyRed")
        static let activityRed       = Color("GlubodyRed")

        // MARK: - Section-Aliasse pro Domain
        //
        // Activity-Domain (Steps, Activity Energy, Trainings, etc.)
        static let activityAccent    = activityRed

        // Body-Domain (Weight, Sleep, HR, etc.)
        static let bodyAccent        = activityOrange

        // Metabolic-Domain (Glucose, Insulin, TIR)
        static let metabolicAccent   = accentLime

        // Nutrition-Domain (Carbs, Protein, Fat, Calories)
        static let nutritionAccent   = accentAqua

        // OPTIONAL: alter Alias für Legacy-Code
        // (falls irgendwo noch bodyActivityAccent verwendet wird)
        static let bodyActivityAccent = activityOrange
    }
}
