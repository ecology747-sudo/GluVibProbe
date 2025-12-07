import Foundation                                   // !!! NEW
import SwiftUI                                      // !!! NEW

// MARK: - Body Fat Entry                           // !!! NEW

struct BodyFatEntry: Identifiable {                 // !!! NEW
    let id = UUID()                                 // !!! NEW
    let date: Date                                  // !!! NEW
    let bodyFatPercent: Double                      // !!! NEW   // z.B. 18.5 (%)
}                                                   // !!! NEW

// MARK: - Preview                                  // !!! NEW

#Preview("BodyFatEntry – Preview") {                // !!! NEW
    Text("BodyFatEntry Preview")                    // !!! NEW
        .padding()                                  // !!! NEW
}                                                   // !!! NEW
