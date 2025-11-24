import SwiftUI

struct StepsView1: View {

    @StateObject private var viewModel = StepsViewModel()

    let onMetricSelected: (String) -> Void

    init(onMetricSelected: @escaping (String) -> Void = { _ in }) {
        self.onMetricSelected = onMetricSelected
    }

    var body: some View {
        ZStack {
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    ActivityStepsSectionCard(
                        sectionTitle: "Activity & Body",
                        title: "Steps",
                        kpiTitle: "Steps Today",
                        kpiValue: viewModel.formattedTodaySteps,
                        stepsToGoValue: viewModel.formattedStepsToGo,
                        last90DaysData: viewModel.last90DaysData,
                        monthlyData: viewModel.monthlyStepsData,
                        onMetricSelected: onMetricSelected
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#Preview("StepsView1 – Body & Activity") {
    StepsView1()
}
