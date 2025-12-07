import Foundation                                   // !!! NEW
import SwiftUI                                      // !!! NEW

// MARK: - BMI Entry                                // !!! NEW

struct BMIEntry: Identifiable {                     // !!! NEW
    let id = UUID()                                 // !!! NEW
    let date: Date                                  // !!! NEW
    let bmi: Double                                 // !!! NEW   // z.B. 24.3
}                                                   // !!! NEW

// MARK: - Preview                                  // !!! NEW

#Preview("BMIEntry – Preview") {                    // !!! NEW
    Text("BMIEntry Preview")                        // !!! NEW
        .padding()                                  // !!! NEW
}                                                   // !!! NEW
