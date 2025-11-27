
import SwiftUI

extension Color {
    struct Glu {
        static let primaryBlue       = Color("GluPrimaryBlue")
        static let accentLime        = Color("GluAccentLime")
        static let accentAqua        = Color("GluAccentAqua")
        static let backgroundNavy    = Color("GluBackgroundNavy")
        static let backgroundSurface = Color("GluBackgroundSurface")
        static let activityOrange    = Color("GluActivityOrange")

        // 🔹 Section-Aliasse (BodyActivity, Metabolic, Nutrition)
        static let bodyActivityAccent = activityOrange   // Steps, Activity, Weight, Sleep
        static let metabolicAccent    = accentLime       // Glucose, Insulin, TIR
        static let nutritionAccent    = accentAqua       // Carbs, Protein, Calories
    }
}
