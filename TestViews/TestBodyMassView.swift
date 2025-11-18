//
//  TestBodyMassView.swift
//  GluVibProbe
//

import SwiftUI
import HealthKit

struct TestBodyMassView: View {
    
    // Zugriff auf deinen HealthStore (kann nil sein, z.B. im Simulator ohne Health)
    private let healthStore = HealthStore()
    
    @State private var latestWeightKg: Double?      // letzter Wert aus HealthKit
    @State private var statusText: String = "Noch kein Gewicht geladen."
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text("Test: Body Weight aus HealthKit")
                .font(.headline)
            
            // Status / Ergebnisanzeige
            if let kg = latestWeightKg {
                Text(String(format: "Letztes Gewicht: %.1f kg", kg))
                    .font(.title2)
            } else {
                Text(statusText)
                    .foregroundColor(.secondary)
            }
            
            // Button zum manuellen Laden
            Button("Gewicht laden") {
                loadLatestWeight()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .onAppear {
            // einfache Verfügbarkeitsprüfung
            if !HKHealthStore.isHealthDataAvailable() {
                statusText = "Health-Daten sind auf diesem Gerät nicht verfügbar."
            }
        }
    }
    
    // MARK: - Logik: Gewicht laden
    private func loadLatestWeight() {
        guard healthStore.isHealthDataAvailable else {
            statusText = "Health-Daten sind auf diesem Gerät nicht verfügbar."
            return
        }
        
        healthStore.fetchLatestBodyMass { kg in
            DispatchQueue.main.async {
                if let kg {
                    latestWeightKg = kg
                    statusText = "Gewicht erfolgreich geladen."
                } else {
                    statusText = "Kein Körpergewicht in Health gefunden."
                }
            }
        }
    }}
#Preview {
    TestBodyMassView()
}
