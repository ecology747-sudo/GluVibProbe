//
//  StepsView.swift
//  GluVibProbe
//

import SwiftUI

struct StepsView: View {
    
    // HealthStore aus der App holen
    @EnvironmentObject var healthStore: HealthStore
    
    // HealthKit-Daten
    @State private var todaySteps: Int? = nil                 // Schritte heute
    @State private var last90DaysData: [DailyStepsEntry] = [] // 90-Tage-Verlauf
    
    /// Für Preview / Test: wenn true, werden Mockdaten verwendet
    let useMockData: Bool
    
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
                    
                    // MARK: - Oberes Diagramm: 90 Tage BarChart
                    SectionHeader("Schrittverlauf (90 Tage)")
                    
                    Last90DaysBarChart(data: last90DaysData)
                        .frame(height: 220)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Steps")
        }
        .onAppear {
            if useMockData {
                loadMockData()
            } else {
                loadStepsFromHealthKit()
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
    
    // MARK: - HealthKit laden
    private func loadStepsFromHealthKit() {
        // 1️⃣ Schritte heute
        healthStore.fetchTodayStepCount { value in
            if let value {
                self.todaySteps = Int(value.rounded())
            } else {
                self.todaySteps = nil
            }
        }
        
        // 2️⃣ Schritte der letzten 90 Tage
        healthStore.fetchStepsLastNDays(days: 90) { values in
            self.last90DaysData = buildLast90Days(from: values)
        }
    }
    
    // Werte-Array -> [DailyStepsEntry] mit Datum
    private func buildLast90Days(from values: [Int]) -> [DailyStepsEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [DailyStepsEntry] = []
        
        for offset in 0..<values.count {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            let entry = DailyStepsEntry(date: date, steps: values[offset])
            result.append(entry)
        }
        
        // chronologisch aufsteigend (ältester Tag zuerst)
        return result.sorted { $0.date < $1.date }
    }
    
    // MARK: - Mock-Daten nur für Preview / Tests
    private func loadMockData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let demoData: [DailyStepsEntry] = (0..<90).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return DailyStepsEntry(
                date: date,
                steps: Int.random(in: 2_000...12_000)
            )
        }
        .sorted { $0.date < $1.date }
        
        self.last90DaysData = demoData
        self.todaySteps = demoData.last?.steps
    }
}

#Preview {
    StepsView(useMockData: true)
        .environmentObject(HealthStore())
}
