//
//  ActivityOverviewViewModel.swift
//  GluVibProbe
//
//  Verantwortlich für die Activity-Overview (Steps Today + Active Energy Today)
//

import Foundation
import Combine  

@MainActor
final class ActivityOverviewViewModel: ObservableObject {

    // MARK: - Published Output

    /// Schritte heute (aus HealthStore)
    @Published var todaySteps: Int = 0

    /// Aktivitätsenergie heute in kcal (aus HealthStore)
    @Published var todayActiveEnergyKcal: Int = 0

    // MARK: - Dependencies

    private let healthStore: HealthStore

    // MARK: - Init

    init(healthStore: HealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Refresh

    /// Lädt die aktuellen Werte aus dem HealthStore.
    /// Nutzt die bestehenden fetch-Funktionen und spiegelt danach die Werte.
    func refresh() async {

        // 1) HealthKit-Fetch anstoßen (bestehende, synchrone Funktionen)
        healthStore.fetchStepsToday()
        healthStore.fetchActiveEnergyToday()

        // 2) Kurz warten, bis HealthStore seine @Published-Werte gesetzt hat
        //    (in der echten App kannst du das später eleganter machen)
        try? await Task.sleep(nanoseconds: 400_000_000)   // 0,4 Sekunden

        // 3) Werte in das ViewModel spiegeln
        todaySteps = healthStore.todaySteps
        todayActiveEnergyKcal = healthStore.todayActiveEnergy
    }
}
