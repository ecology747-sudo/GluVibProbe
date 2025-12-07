import Foundation                                   // !!! NEW
import SwiftUI                                      // !!! NEW

// MARK: - Resting Heart Rate Entry                 // !!! NEW

struct RestingHeartRateEntry: Identifiable {        // !!! NEW
    let id = UUID()                                 // !!! NEW
    let date: Date                                  // !!! NEW
    let restingHeartRate: Int                       // !!! NEW   // bpm
}                                                   // !!! NEW

// MARK: - Preview                                  // !!! NEW

#Preview("RestingHeartRateEntry – Preview") {       // !!! NEW
    Text("RestingHeartRateEntry Preview")           // !!! NEW
        .padding()                                  // !!! NEW
}                                                   // !!! NEW
