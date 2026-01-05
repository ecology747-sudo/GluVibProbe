//
//  MovementSplitViewModelV1.swift
//  GluVibProbe
//
//  ✅ V1: SSoT = movementSplitDaily365
//  ✅ UPDATED: Active-Time-Source (Today) direkt aus HealthStore (kein Doppel-Enum)
//  ✅ UX-Hinweis nur bei Fallback (Exercise/Workout), kein neues UI-Pattern
//

import Foundation
import Combine

@MainActor
final class MovementSplitViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (SSoT → View)
    // ============================================================

    @Published var movementSplitDaily365: [DailyMovementSplitEntry] = []   // ✅ SSoT (365)

    // ✅ TODAY KPIs
    @Published var todayMoveMinutes: Int = 0
    @Published var todaySedentaryMinutes: Int = 0
    @Published var todaySleepSplitMinutes: Int = 0

    // ✅ UPDATED: Source kommt 1:1 aus HealthStore (keine doppelte Wahrheit)
    @Published var todayActiveTimeSource: HealthStore.MovementSplitActiveSourceTodayV1 = .none  // !!! UPDATED

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        bindHealthStore()
        syncFromStores()
    }

    private func bindHealthStore() {

        // ✅ SSoT bind
        healthStore.$movementSplitDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.movementSplitDaily365 = $0 }
            .store(in: &cancellables)

        healthStore.$todayMoveMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayMoveMinutes = $0 }
            .store(in: &cancellables)

        healthStore.$todaySedentaryMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todaySedentaryMinutes = $0 }
            .store(in: &cancellables)

        healthStore.$todaySleepSplitMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todaySleepSplitMinutes = $0 }
            .store(in: &cancellables)

        // ✅ UPDATED: Source Today direkt binden
        healthStore.$movementSplitActiveSourceTodayV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayActiveTimeSource = $0 }          // !!! UPDATED
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        movementSplitDaily365 = healthStore.movementSplitDaily365
        todayMoveMinutes = healthStore.todayMoveMinutes
        todaySedentaryMinutes = healthStore.todaySedentaryMinutes
        todaySleepSplitMinutes = healthStore.todaySleepSplitMinutes
        todayActiveTimeSource = healthStore.movementSplitActiveSourceTodayV1   // !!! UPDATED
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var kpiSleepText: String { formatMinutes(todaySleepSplitMinutes) }
    var kpiActiveText: String { formatMinutes(todayMoveMinutes) }
    var kpiSedentaryText: String { formatMinutes(todaySedentaryMinutes) }

    // ============================================================
    // MARK: - UX Hinweis (Pflicht bei Fallback)
    // ============================================================

    /// Hinweis nur, wenn NICHT StandTime (Primärquelle) verwendet wurde.
    var shouldShowActiveSourceHint: Bool {
        switch todayActiveTimeSource {
        case .exerciseMinutes, .workoutMinutes:
            return true
        case .standTime, .none:
            return false
        }
    }

    /// Text (sinngemäß, wie gefordert). Kein neues UI-Pattern – nur Text.
    var activeSourceHintText: String? {
        guard shouldShowActiveSourceHint else { return nil }

        switch todayActiveTimeSource {
        case .exerciseMinutes:
            return "Active time based on Exercise Minutes"
        case .workoutMinutes:
            return "Active time estimated from Workout Minutes"
        case .standTime, .none:
            return nil
        }
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes <= 0 { return "0 min" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours) h \(mins) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(mins) min"
    }
}
