//
//  MovementSplitViewModel.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI
import Charts

final class MovementSplitViewModel: ObservableObject {

    // MARK: - Dependencies

    private let healthStore: HealthStore

    // MARK: - Published Properties

    @Published var dailyMovementSplits: [DailyMovementSplitEntry] = []

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        fetchMovementSplit()
    }

    // MARK: - Public API

    func refresh() {
        fetchMovementSplit()
    }

    func onAppear() {
        fetchMovementSplit()
    }

    // MARK: - KPI-Texte (heutiger Tag seit 0:00)                   // !!! UPDATED

    /// Sleep KPI → „Sleep (Last Night)“:
    /// alle Schlafminuten seit 0:00 (Morning + Evening)            // !!! UPDATED
    var kpiSleepText: String {
        guard let entry = todayEntry else {
            return "–"
        }
        let total = entry.sleepMorningMinutes                      // !!! UPDATED
                 + entry.sleepEveningMinutes                       // !!! UPDATED
        return formatMinutes(total)
    }

    /// Active KPI → „Move & Exercise Today“:
    /// aktive Minuten seit 0:00 (MoveTime + ExerciseTime)         // !!! UPDATED
    var kpiActiveText: String {
        guard let entry = todayEntry else {
            return "–"
        }
        return formatMinutes(entry.activeMinutes)                  // !!! UPDATED
    }

    /// Sedentary KPI → „Sedentary Today“:
    /// nur die Minuten, die bis jetzt wirklich vergangen sind,
    /// also: Minuten seit 0:00 − SleepSince0:00 − ActiveSince0:00  // !!! NEW
    var kpiSedentaryText: String {                                 // !!! UPDATED
        guard let entry = todayEntry else {
            return "–"
        }

        let now = Date()                                           // !!! NEW
        let calendar = Calendar.current                            // !!! NEW
        let startOfDay = calendar.startOfDay(for: now)             // !!! NEW
        let minutesSinceMidnight = Int(                            // !!! NEW
            now.timeIntervalSince(startOfDay) / 60.0
        )

        let sleepSinceMidnight =                                   // !!! NEW
            entry.sleepMorningMinutes + entry.sleepEveningMinutes
        let activeSinceMidnight = entry.activeMinutes              // !!! NEW

        let sedentarySoFar = max(                                  // !!! NEW
            0,
            minutesSinceMidnight - sleepSinceMidnight - activeSinceMidnight
        )

        return formatMinutes(sedentarySoFar)                       // !!! NEW
    }

    // MARK: - Private Helpers

    private var todayEntry: DailyMovementSplitEntry? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return dailyMovementSplits.first { entry in
            calendar.isDate(entry.date, inSameDayAs: today)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return "0 min"
        }

        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours) h \(mins) min"
        } else if hours > 0 {
            return "\(hours) h"
        } else {
            return "\(mins) min"
        }
    }

    private func fetchMovementSplit(last days: Int = 30) {
        healthStore.fetchMovementSplitDaily(last: days) { [weak self] entries in
            self?.dailyMovementSplits = entries
        }
    }
}

// MARK: - Preview

struct MovementSplitViewModel_Previews: PreviewProvider {
    static var previews: some View {
        let previewStore = HealthStore.preview()
        let viewModel = MovementSplitViewModel(healthStore: previewStore)

        return MovementSplit30DayChart(data: viewModel.dailyMovementSplits)
            .padding()
            .previewDisplayName("Movement Split VM + Chart")
    }
}
