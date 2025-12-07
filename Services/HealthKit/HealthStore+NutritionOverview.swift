//
//  HealthStore+NutritionOverview.swift
//  GluVibProbe
//
//  Spezielle Helper für die NutritionOverview:
//  - Tagesbasierte Carbs / Protein / Fat / Nutrition-Energy
//  - Tagesbasierte Active Energy
//  - 14-Tage-Trend für Nutrition Energy
//
//  WICHTIG:
//  - Nutzt deine bestehenden Daily-Funktionen (fetchCarbsDaily, fetchProteinDaily, ...)
//  - Verändert die globale Datenlogik NICHT, sondern baut nur Convenience-Wrapper.
//

import Foundation

extension HealthStore {
    
    // ============================================================
    // MARK: - NEU: Tagesbasierte Macros & Nutrition-Energy
    // ============================================================
    
    /// Carbs (g) für einen bestimmten Tag.
    /// Nutzt intern `fetchCarbsDaily(last:)` → Single Source of Truth.
    func fetchDailyCarbs(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            // MARK: - Änderung: statt "nur heute" jetzt bis zu 30 Tage und Filter per Datum
            self.fetchCarbsDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)
                
                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.grams ?? 0
                
                continuation.resume(returning: value)
            }
        }
    }
    
    /// Protein (g) für einen bestimmten Tag.
    /// Nutzt intern `fetchProteinDaily(last:)`.
    func fetchDailyProtein(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchProteinDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)
                
                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.grams ?? 0
                
                continuation.resume(returning: value)
            }
        }
    }
    
    /// Fat (g) für einen bestimmten Tag.
    /// Nutzt intern `fetchFatDaily(last:)`.
    func fetchDailyFat(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchFatDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)
                
                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.grams ?? 0
                
                continuation.resume(returning: value)
            }
        }
    }
    
    /// Nutrition Energy (kcal) für einen bestimmten Tag.
    /// Nutzt intern `fetchNutritionEnergyDaily(last:)`.
    func fetchDailyNutritionEnergy(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            self.fetchNutritionEnergyDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)
                
                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.energyKcal ?? 0
                
                continuation.resume(returning: value)
            }
        }
    }
    
    // ============================================================
    // MARK: - NEU: Tagesbasierte Active Energy
    // ============================================================
    
    /// Active Energy (kcal) für einen bestimmten Tag.
    ///
    /// Nutzt deine bestehende Daily-Logik für Activity Energy:
    /// - `fetchActiveEnergyDaily(last:)` (HealthStore-Plus-Datei für Energy)
    func fetchDailyActiveEnergy(for date: Date) async throws -> Int {
        await withCheckedContinuation { continuation in
            // MARK: - Änderung: 30 Tage holen, dann nach Datum filtern
            self.fetchActiveEnergyDaily(last: 30) { entries in
                let calendar = Calendar.current
                let targetDay = calendar.startOfDay(for: date)
                
                let value = entries.first(where: {
                    calendar.isDate($0.date, inSameDayAs: targetDay)
                })?.activeEnergy ?? 0
                
                continuation.resume(returning: value)
            }
        }
    }
    
}
