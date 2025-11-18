import SwiftUI
import HealthKit

struct TestGlucoseView: View {
    
    private let healthStore = HealthStore()
    
    @State private var latestGlucose: Double?
    @State private var latestDate: Date?
    @State private var statusText: String = "Noch kein Glukosewert geladen."
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text("Test: Blood Glucose aus HealthKit")
                .font(.headline)
            
            if let value = latestGlucose, let date = latestDate {
                VStack(spacing: 4) {
                    Text(String(format: "Letzter Wert: %.0f mg/dL", value))
                        .font(.title2)
                    Text("Zeitpunkt: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(statusText)
                    .foregroundColor(.secondary)
            }
            
            Button("Glukose laden") {
                loadLatestGlucose()
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
    
    private func loadLatestGlucose() {
        guard healthStore.isHealthDataAvailable else {
            statusText = "Health-Daten sind auf diesem Gerät nicht verfügbar."
            return
        }
        
        healthStore.fetchLatestBloodGlucose { value, date in
            DispatchQueue.main.async {
                if let value, let date {
                    latestGlucose = value
                    latestDate = date
                    statusText = "Glukosewert erfolgreich geladen."
                } else {
                    statusText = "Kein Glukosewert in Health gefunden."
                }
            }
        }
    }
}

#Preview {
    TestGlucoseView()
}
