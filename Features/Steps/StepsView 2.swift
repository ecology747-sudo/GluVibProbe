//
//  StepsView 2.swift
//  GluVibProbe
//
//  Created by MacBookAir on 18.11.25.
//


//
//  StepsView.swift
//  GluVibProbe
//

import SwiftUI

struct StepsView: View {
    
    // 🔥 HealthStore aus der App holen (für echten Betrieb auf iPhone)
    @EnvironmentObject var healthStore: HealthStore
    
    // Soll diese View mit Mock-Daten laufen?
    let useMockData: Bool
    
    // HealthKit-/Mock-Daten
    @State private var todaySteps: Int? = nil          // Schritte heute
    @State private var last30Days: [Int] = []          // 30-Tage-Verlauf
    
    // MARK: - Init (Standard: echte Daten)
    init(useMockData: Bool = false) {
        self.useMockData = useMockData
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - KPI-Bereich "Heute"
                    SectionHeader("Heute")
                    
                    VStack(spacing: 12) {
                        KPICard(
                            title: "Steps Today",
                            value: stepsTodayLabel,
                            unit: "steps"
                        )
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Oberes Diagramm (Line)
                    SectionHeader("Schrittverlauf (30 Tage)")
                    
                    TemplateLineChart(data: last30Days)
                        .frame(height: 180)
                        .padding(.horizontal)
                    
                    // MARK: - Unteres Diagramm (Bar)
                    SectionHeader("Tageswerte (30 Tage)")
                    
                    TemplateBarChart(data: last30Days)
                        .frame(height: 200)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Steps")
        }
        .onAppear {
            if useMockData {
                loadMockData()           // 👈 für Canvas / Previews
            } else {
                loadStepsFromHealthKit() // 👈 für echte App auf iPhone
            }
        }
    }
    
    // MARK: - Anzeige-Label für KPI
    private var stepsTodayLabel: String {
        if let steps = todaySteps {
            return "\(steps)"
        } else {
            return "–"
        }
    }
    
    // MARK: - HealthKit laden (echter Betrieb)
    private func loadStepsFromHealthKit() {
        // 1️⃣ Schritte heute
        healthStore.fetchTodayStepCount { value in
            if let value {
                self.todaySteps = Int(value.rounded())
            } else {
                self.todaySteps = nil
            }
        }
        
        // 2️⃣ Schritte der letzten 30 Tage
        healthStore.fetchStepsLastNDays(days: 30) { values in
            self.last30Days = values
        }
    }
    
    // MARK: - Mock-Daten (nur für Preview / Design)
    private func loadMockData() {
        // Beispiel: 8.452 Schritte heute
        todaySteps = 8452
        
        // Demo-Daten: 30 Tage mit leicht variierenden Werten
        last30Days = (0..<30).map { _ in
            6000 + Int.random(in: -1500...2000)
        }
    }
}

#Preview {
    // 👇 Preview mit Mock-Daten, NICHT HealthKit
    StepsView(useMockData: true)
        .environmentObject(HealthStore())
}