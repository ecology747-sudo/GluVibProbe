//
//  StepsView.swift
//  GluVibProbe
//
// mit gpt checken ob view konform alles was nicht 100% view ist kommt in stepsmodelview!!


import SwiftUI

struct StepsView: View {

    @EnvironmentObject var healthStore: HealthStore

    private let dailyStepsGoal = 10_000

    // Callback aus dem Dashboard (für Metric-Chips)
    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var stepsToGo: Int {
        max(dailyStepsGoal - healthStore.todaySteps, 0)
    }

    var body: some View {
        ZStack {
            // Hintergrund für den Bereich „Körper & Aktivität“
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16)
                {

                    // ✅ Nur noch DIESE Card enthält den SectionHeader
                    ActivityStepsSectionCard(
                        sectionTitle: "Activity & Body",   // Screen-Header
                        title: "Steps",                       // aktiver Metric-Chip
                        kpiTitle: "Steps Today",
                        kpiValue: "\(healthStore.todaySteps)",
                        stepsToGoValue: "\(stepsToGo)",
                        last90DaysData: healthStore.last90Days,
                        monthlyData: healthStore.monthlySteps,
                        onMetricSelected: onMetricSelected
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)   // etwas Luft nach oben
            }
        }
        .onAppear {
            healthStore.requestAuthorization()
        }
    }
}

#Preview("StepsView – Body & Activity") {
    let previewStore = HealthStore.preview()

    return StepsView()
        .environmentObject(previewStore)
}
