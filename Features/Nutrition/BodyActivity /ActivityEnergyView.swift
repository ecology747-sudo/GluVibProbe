//
//  ActivityEnergyView.swift
//  GluVibProbe
//

import SwiftUI

struct ActivityEnergyView: View {

    @EnvironmentObject var healthStore: HealthStore

    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    private let dailyGoal = 600

    private var energyToGo: Int {
        max(dailyGoal - healthStore.todayEnergy, 0)
    }

    var body: some View {
        ZStack {
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ✅ Kein eigener SectionHeader mehr hier oben

                    ActivityStepsSectionCard(
                        sectionTitle: "Körper & Aktivität",        // Screen-Header
                        title: "Activity Energy",                  // aktiver Metric-Chip
                        kpiTitle: "Energy Today",
                        kpiValue: "\(healthStore.todayEnergy)",
                        stepsToGoValue: "\(energyToGo)",
                        last90DaysData: healthStore.last90DaysEnergy,
                        monthlyData: healthStore.monthlyEnergy,
                        onMetricSelected: onMetricSelected
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)
            }
        }
        .onAppear {
            healthStore.requestAuthorization()
        }
    }
}

#Preview("ActivityEnergyView – Body & Activity") {
    let previewStore = HealthStore.preview()

    return ActivityEnergyView()
        .environmentObject(previewStore)
}
