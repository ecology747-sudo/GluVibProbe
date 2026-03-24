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
    // MARK: - Info State
    // ============================================================

    enum MovementSplitInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs (SSoT → View)
    // ============================================================

    @Published var movementSplitDaily365: [DailyMovementSplitEntry] = []

    @Published var todayMoveMinutes: Int = 0
    @Published var todaySedentaryMinutes: Int = 0
    @Published var todaySleepSplitMinutes: Int = 0

    @Published var todayActiveTimeSource: HealthStore.MovementSplitActiveSourceTodayV1 = .none

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        bindHealthStore()
        syncFromStores()
    }

    private func bindHealthStore() {
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

        healthStore.$movementSplitActiveSourceTodayV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayActiveTimeSource = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        movementSplitDaily365 = healthStore.movementSplitDaily365
        todayMoveMinutes = healthStore.todayMoveMinutes
        todaySedentaryMinutes = healthStore.todaySedentaryMinutes
        todaySleepSplitMinutes = healthStore.todaySleepSplitMinutes
        todayActiveTimeSource = healthStore.movementSplitActiveSourceTodayV1
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var kpiSleepText: String { formatMinutes(todaySleepSplitMinutes) }
    var kpiActiveText: String { formatMinutes(todayMoveMinutes) }
    var kpiSedentaryText: String { formatMinutes(todaySedentaryMinutes) }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    private var hasAnyHistory: Bool { // 🟨 NEW
        movementSplitDaily365.contains {
            ($0.sleepMorningMinutes + $0.sleepEveningMinutes + $0.activeMinutes) > 0
        }
    }

    private var hasUsableTodayData: Bool { // 🟨 NEW
        todaySleepSplitMinutes > 0 || todayMoveMinutes > 0
    }

    private var hasAuthAttention: Bool { // 🟨 NEW
        healthStore.movementSplitAnyAttentionForBadgesV1
    }

    var todayInfoState: MovementSplitInfoState? { // 🟨 UPDATED
        if hasAuthAttention { return .noHistory }
        if hasUsableTodayData { return nil }
        if !hasAnyHistory { return .noHistory }
        return .noTodayData
    }

    // ============================================================
    // MARK: - UX Hinweis (Pflicht bei Fallback)
    // ============================================================

    var shouldShowActiveSourceHint: Bool {
        switch todayActiveTimeSource {
        case .exerciseMinutes, .workoutMinutes:
            return true
        case .standTime, .none:
            return false
        }
    }

    var activeSourceHintText: String? {
        guard shouldShowActiveSourceHint else { return nil }

        switch todayActiveTimeSource {
        case .exerciseMinutes:
            return L10n.MovementSplit.hintExerciseMinutes
        case .workoutMinutes:
            return L10n.MovementSplit.hintWorkoutMinutes
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
