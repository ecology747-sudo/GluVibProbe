import SwiftUI
import HealthKit

struct TestStepsView: View {
    
    private let healthStore = HealthStore()
    
    @State private var todaySteps: Int?
    @State private var statusText: String = "Noch keine Schritte geladen."
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text("Test: Steps aus HealthKit")
                .font(.headline)
            
            if let steps = todaySteps {
                Text("\(steps) Schritte heute")
                    .font(.title2)
            } else {
                Text(statusText)
                    .foregroundColor(.secondary)
            }
            
            Button("Schritte laden") {
                loadTodaySteps()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .onAppear {
            if !healthStore.isHealthDataAvailable {
                statusText = "Health-Daten sind auf diesem Gerät nicht verfügbar."
            }
        }
    }
    
    private func loadTodaySteps() {
        guard healthStore.isHealthDataAvailable else {
            statusText = "Health-Daten sind auf diesem Gerät nicht verfügbar."
            return
        }
        
        healthStore.fetchTodayStepCount { value in
            DispatchQueue.main.async {
                if let value {
                    todaySteps = Int(value.rounded())
                    statusText = "Schritte erfolgreich geladen."
                } else {
                    statusText = "Keine Schritte für heute gefunden."
                }
            }
        }
    }
}

#Preview {
    TestStepsView()
}
