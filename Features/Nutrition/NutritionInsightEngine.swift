//
//  NutritionInsightEngine.swift
//  GluVibProbe
//

import Foundation

// MARK: - Day context for insights

enum DayContext {
    case today
    case yesterday
    case dayBefore
}

// MARK: - Input model for the insight engine

struct NutritionInsightInput {

    // Energy (Intake & Burned)
    let todayEnergyKcal: Int
    let todayActiveEnergyKcal: Int
    let restingEnergyKcal: Int
    let energyBalanceKcal: Int          // = budget - intake (wie im ViewModel)

    // Macros (heutige Aufnahme)
    let todayCarbsGrams: Int
    let todayProteinGrams: Int
    let todayFatGrams: Int

    // Verteilung (0.0–1.0)
    let carbsShare: Double
    let proteinShare: Double
    let fatShare: Double

    // Score (0–100)
    let nutritionScore: Int

    // Ziele / Targets
    let dailyEnergyGoal: Int
    let targetCarbsGrams: Int
    let targetProteinGrams: Int
    let targetFatGrams: Int

    // Kontext
    let now: Date
    let dayContext: DayContext
}

// MARK: - Interne Enums (nur für diese Datei)

private enum NutritionTimeOfDay {
    case earlyMorning    // 05–09
    case lateMorning     // 09–12
    case afternoon       // 12–17
    case evening         // 17–22
    case lateEvening     // 22–24 und Rest
}

private enum NutritionProgressState {
    case noData
    case veryLow
    case slightlyLow
    case onTrack
    case slightlyHigh
    case veryHigh
}

private enum NutritionInsightFocus {
    case noData
    case energyBalance
    case macrosBalanced
    case carbsAttention
    case proteinAttention
    case fatAttention
}

private enum NutritionInsightTone {
    case positive
    case neutral
    case warning
}

private enum MacroKind {
    case carbs
    case protein
    case fat
}

// MARK: - Insight Engine

struct NutritionInsightEngine {

    func makeInsight(for input: NutritionInsightInput) -> String {

        // 1) Grundcheck: überhaupt Daten vorhanden?
        if isNoData(input: input) {
            return "No nutrition data recorded yet for this day."
        }

        let isToday = (input.dayContext == .today)
        let isCompletedDay = !isToday

        // 2) Tageszeit & Tagesanteil bestimmen (nur heute wirklich relevant)
        let timeOfDay = timeOfDay(for: input.now)
        let dayFraction = dayFraction(for: input.now)
        let expectedProgress = max(dayFraction, 0.1)   // Untergrenze, damit es stabil bleibt

        // 3) Fortschritte gegen Ziele
        let energyProgress = progress(current: input.todayEnergyKcal,
                                      target: input.dailyEnergyGoal)
        let carbsProgress  = progress(current: input.todayCarbsGrams,
                                      target: input.targetCarbsGrams)
        let proteinProgress = progress(current: input.todayProteinGrams,
                                       target: input.targetProteinGrams)
        let fatProgress    = progress(current: input.todayFatGrams,
                                      target: input.targetFatGrams)

        // 4) Fortschritt relativ zur Tageszeit
        let energyVsTime: Double
        let carbsVsTime: Double
        let proteinVsTime: Double
        let fatVsTime: Double

        if isCompletedDay {
            // Abgeschlossene Tage → Tageszeit egal → VsTime = Progress
            energyVsTime = energyProgress
            carbsVsTime = carbsProgress
            proteinVsTime = proteinProgress
            fatVsTime = fatProgress
        } else {
            // Heute → Bewertung relativ zum erwarteten Tagesfortschritt
            energyVsTime = energyProgress / expectedProgress
            carbsVsTime  = carbsProgress  / expectedProgress
            proteinVsTime = proteinProgress / expectedProgress
            fatVsTime    = fatProgress    / expectedProgress
        }

        // 5) States für Energie & Makros bestimmen
        let energyState = progressState(progress: energyProgress,
                                        vsTime: energyVsTime,
                                        timeOfDay: timeOfDay,
                                        isCompletedDay: isCompletedDay)

        let carbsState = progressState(progress: carbsProgress,
                                       vsTime: carbsVsTime,
                                       timeOfDay: timeOfDay,
                                       isCompletedDay: isCompletedDay)

        let proteinState = progressState(progress: proteinProgress,
                                         vsTime: proteinVsTime,
                                         timeOfDay: timeOfDay,
                                         isCompletedDay: isCompletedDay)

        let fatState = progressState(progress: fatProgress,
                                     vsTime: fatVsTime,
                                     timeOfDay: timeOfDay,
                                     isCompletedDay: isCompletedDay)

        // 6) Fokus & Tonalität bestimmen
        let (focus, tone, dominantMacro) = determineFocusAndTone(
            energyState: energyState,
            carbsState: carbsState,
            proteinState: proteinState,
            fatState: fatState,
            energyProgress: energyProgress,
            isToday: isToday,
            timeOfDay: timeOfDay,
            isCompletedDay: isCompletedDay
        )

        // 7) Text generieren
        let text = buildInsightText(
            focus: focus,
            tone: tone,
            dominantMacro: dominantMacro,
            input: input,
            energyProgress: energyProgress,
            energyState: energyState,
            carbsState: carbsState,
            proteinState: proteinState,
            fatState: fatState,
            isToday: isToday,
            isCompletedDay: isCompletedDay,
            timeOfDay: timeOfDay
        )

        return text
    }

    // MARK: - Grundchecks

    private func isNoData(input: NutritionInsightInput) -> Bool {
        let totalIntake = input.todayEnergyKcal
            + input.todayCarbsGrams
            + input.todayProteinGrams
            + input.todayFatGrams
        return totalIntake <= 0
    }

    // MARK: - Time helpers

    private func timeOfDay(for date: Date) -> NutritionTimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<9:
            return .earlyMorning
        case 9..<12:
            return .lateMorning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .lateEvening
        }
    }

    private func dayFraction(for date: Date) -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let seconds = date.timeIntervalSince(start)
        let clamped = max(0, min(seconds, 24 * 60 * 60))
        return clamped / (24 * 60 * 60)
    }

    // MARK: - Progress & State

    private func progress(current: Int, target: Int) -> Double {
        guard target > 0 else { return 0.0 }
        return Double(max(current, 0)) / Double(target)
    }

    private func progressState(
        progress: Double,
        vsTime: Double,
        timeOfDay: NutritionTimeOfDay,
        isCompletedDay: Bool
    ) -> NutritionProgressState {

        if progress == 0 {
            return .noData
        }

        if isCompletedDay {
            // Abgeschlossene Tage → reine Zielbewertung
            if progress < 0.8 {
                return .veryLow
            } else if progress < 0.9 {
                return .slightlyLow
            } else if progress <= 1.1 {
                return .onTrack
            } else if progress <= 1.3 {
                return .slightlyHigh
            } else {
                return .veryHigh
            }
        } else {
            // HEUTE → Bewertung relativ zur Tageszeit
            let veryLowThreshold: Double
            let slightlyLowThreshold: Double
            let slightlyHighThreshold: Double
            let veryHighThreshold: Double

            switch timeOfDay {
            case .earlyMorning, .lateMorning:
                veryLowThreshold = 0.3
                slightlyLowThreshold = 0.6
                slightlyHighThreshold = 1.4
                veryHighThreshold = 1.8
            case .afternoon:
                veryLowThreshold = 0.5
                slightlyLowThreshold = 0.8
                slightlyHighThreshold = 1.2
                veryHighThreshold = 1.5
            case .evening, .lateEvening:
                veryLowThreshold = 0.7
                slightlyLowThreshold = 0.9
                slightlyHighThreshold = 1.1
                veryHighThreshold = 1.3
            }

            if vsTime < veryLowThreshold {
                return .veryLow
            } else if vsTime < slightlyLowThreshold {
                return .slightlyLow
            } else if vsTime <= slightlyHighThreshold {
                return .onTrack
            } else if vsTime <= veryHighThreshold {
                return .slightlyHigh
            } else {
                return .veryHigh
            }
        }
    }

    private func severity(of state: NutritionProgressState) -> Int {
        switch state {
        case .noData:
            return 0
        case .onTrack:
            return 0
        case .slightlyLow, .slightlyHigh:
            return 1
        case .veryLow, .veryHigh:
            return 2
        }
    }

    private func focus(for macro: MacroKind) -> NutritionInsightFocus {
        switch macro {
        case .carbs:
            return .carbsAttention
        case .protein:
            return .proteinAttention
        case .fat:
            return .fatAttention
        }
    }

    // MARK: - Fokus-Logik (welches Thema ist „wichtigstes“?)

    private func determineFocusAndTone(
        energyState: NutritionProgressState,
        carbsState: NutritionProgressState,
        proteinState: NutritionProgressState,
        fatState: NutritionProgressState,
        energyProgress: Double,
        isToday: Bool,
        timeOfDay: NutritionTimeOfDay,
        isCompletedDay: Bool
    ) -> (NutritionInsightFocus, NutritionInsightTone, MacroKind?) {

        // 0) Keine sinnvollen Daten?
        if energyState == .noData
            && carbsState == .noData
            && proteinState == .noData
            && fatState == .noData {
            return (.noData, .neutral, nil)
        }

        // 1) Abgeschlossene Tage: zuerst Gesamtenergie, dann Makros
        if isCompletedDay {

            // Energie deutlich daneben?
            if energyProgress < 0.8 || energyProgress > 1.3 {
                return (.energyBalance, .warning, nil)
            }

            if energyProgress < 0.9 || energyProgress > 1.1 {
                return (.energyBalance, .neutral, nil)
            }

            // Energie ok → schlechtesten Makro wählen
            let macroStates: [(MacroKind, NutritionProgressState)] = [
                (.carbs, carbsState),
                (.protein, proteinState),
                (.fat, fatState)
            ]

            if let worst = macroStates.max(by: { severity(of: $0.1) < severity(of: $1.1) }),
               severity(of: worst.1) > 0 {

                let sev = severity(of: worst.1)
                let tone: NutritionInsightTone = (sev >= 2) ? .warning : .neutral
                let focus = self.focus(for: worst.0)
                return (focus, tone, worst.0)
            }

            // Alles im Rahmen
            return (.macrosBalanced, .positive, nil)
        }

        // 2) HEUTE: Tageszeit ist oberste Ebene

        // 2a) Früher Tag: sehr hohe Energie → Fokus auf Energie
        if (timeOfDay == .earlyMorning || timeOfDay == .lateMorning || timeOfDay == .afternoon),
           energyState == .veryHigh {
            return (.energyBalance, .warning, nil)
        }

        // 2b) Abend/Nacht: deutlicher Unter- oder Überschuss
        if timeOfDay == .evening || timeOfDay == .lateEvening {
            if energyProgress < 0.85 || energyProgress > 1.25 {
                return (.energyBalance, .warning, nil)
            }
            if energyProgress < 0.93 || energyProgress > 1.10 {
                return (.energyBalance, .neutral, nil)
            }
        }

        // 2c) Energie grob im Rahmen → Makros anschauen
        if energyState == .onTrack
            || energyState == .slightlyLow
            || energyState == .slightlyHigh {

            let macroStates: [(MacroKind, NutritionProgressState)] = [
                (.carbs, carbsState),
                (.protein, proteinState),
                (.fat, fatState)
            ]

            if let worst = macroStates.max(by: { severity(of: $0.1) < severity(of: $1.1) }),
               severity(of: worst.1) > 0 {

                let sev = severity(of: worst.1)
                let tone: NutritionInsightTone = (sev >= 2) ? .warning : .neutral
                let focus = self.focus(for: worst.0)
                return (focus, tone, worst.0)
            }

            // Energie & Makros im Rahmen → alles ausgewogen
            return (.macrosBalanced, .positive, nil)
        }

        // 2d) Default: Energie leicht daneben, aber nicht dramatisch
        return (.energyBalance, .neutral, nil)
    }

    // MARK: - Textaufbau (kurze, zusammenfassende Sätze)

    private func buildInsightText(
        focus: NutritionInsightFocus,
        tone: NutritionInsightTone,
        dominantMacro: MacroKind?,
        input: NutritionInsightInput,
        energyProgress: Double,
        energyState: NutritionProgressState,
        carbsState: NutritionProgressState,
        proteinState: NutritionProgressState,
        fatState: NutritionProgressState,
        isToday: Bool,
        isCompletedDay: Bool,
        timeOfDay: NutritionTimeOfDay
    ) -> String {

        // Fallback
        if focus == .noData {
            return "No nutrition data recorded yet for this day."
        }

        let dayLabel: String = {
            switch input.dayContext {
            case .today:
                return "Today"
            case .yesterday:
                return "Yesterday"
            case .dayBefore:
                return "On that day"
            }
        }()

        switch focus {

        case .energyBalance:
            return energyText(
                tone: tone,
                dayLabel: dayLabel,
                isToday: isToday,
                isCompletedDay: isCompletedDay,
                energyProgress: energyProgress,
                energyState: energyState,
                timeOfDay: timeOfDay
            )

        case .macrosBalanced:
            if isToday {
                return "\(dayLabel), your calorie intake and macro distribution are broadly on track for this time of day."
            } else {
                return "\(dayLabel), your calorie intake and macros were well aligned with your daily targets."
            }

        case .carbsAttention, .proteinAttention, .fatAttention:
            guard let macro = dominantMacro else {
                // Sicherheitshalber: falls kein Macro übergeben wurde
                if isToday {
                    return "\(dayLabel), your calorie intake is roughly on track; keep an eye on your macro distribution over the rest of the day."
                } else {
                    return "\(dayLabel), overall energy was acceptable, with some deviations in macro distribution."
                }
            }
            return macroAttentionText(
                macro: macro,
                tone: tone,
                dayLabel: dayLabel,
                isToday: isToday
            )

        case .noData:
            // Bereits oben abgefangen, hier nur als Default
            return "No nutrition data recorded yet for this day."
        }
    }

    private func energyText(
        tone: NutritionInsightTone,
        dayLabel: String,
        isToday: Bool,
        isCompletedDay: Bool,
        energyProgress: Double,
        energyState: NutritionProgressState,
        timeOfDay: NutritionTimeOfDay
    ) -> String {

        if isCompletedDay {
            // Abgeschlossener Tag → klare Tagesbewertung
            switch tone {
            case .positive:
                return "\(dayLabel), your calorie intake was well matched to your daily target."
            case .neutral:
                if energyProgress < 1.0 {
                    return "\(dayLabel), your calorie intake was slightly below your daily target."
                } else {
                    return "\(dayLabel), your calorie intake was slightly above your daily target."
                }
            case .warning:
                if energyProgress < 1.0 {
                    return "\(dayLabel), your calorie intake was clearly below your daily target."
                } else {
                    return "\(dayLabel), your calorie intake was clearly above your daily target."
                }
            }
        } else {
            // HEUTE → tageszeitbasierte Formulierungen
            switch tone {
            case .positive:
                switch timeOfDay {
                case .earlyMorning, .lateMorning:
                    return "\(dayLabel), your calorie intake is developing well for this time of day."
                case .afternoon:
                    return "\(dayLabel), your calorie intake is on a good track for the rest of the day."
                case .evening, .lateEvening:
                    return "\(dayLabel), your calorie intake is close to your daily target."
                }

            case .neutral:
                if energyProgress < 1.0 {
                    switch timeOfDay {
                    case .earlyMorning, .lateMorning:
                        return "\(dayLabel), your calorie intake is still on the lower side, which can be normal for this time of day."
                    case .afternoon:
                        return "\(dayLabel), your calorie intake is moderate; there is still room to reach your daily target."
                    case .evening, .lateEvening:
                        return "\(dayLabel), your calorie intake is slightly below your daily target so far."
                    }
                } else {
                    switch timeOfDay {
                    case .earlyMorning, .lateMorning:
                        return "\(dayLabel), your calorie intake is already relatively high for this time of day."
                    case .afternoon:
                        return "\(dayLabel), your calorie intake is slightly ahead of the usual daily target."
                    case .evening, .lateEvening:
                        return "\(dayLabel), your calorie intake is slightly above your daily target."
                    }
                }

            case .warning:
                if energyProgress < 1.0 {
                    // Deutlich zu wenig (insbes. spät am Tag)
                    switch timeOfDay {
                    case .earlyMorning, .lateMorning:
                        return "\(dayLabel), your calorie intake is very low so far; plan your meals so that your needs are covered over the day."
                    case .afternoon:
                        return "\(dayLabel), your calorie intake is clearly behind your daily target; make sure upcoming meals cover your needs."
                    case .evening, .lateEvening:
                        return "\(dayLabel), your calorie intake is clearly below your daily target; pay attention to cover your basic needs."
                    }
                } else {
                    // Deutlich zu viel, insbes. früh am Tag
                    switch timeOfDay {
                    case .earlyMorning, .lateMorning:
                        return "\(dayLabel), your calorie intake is already high for this time of day; consider keeping the rest of the day lighter."
                    case .afternoon:
                        return "\(dayLabel), your calorie intake is clearly ahead of your daily target; be cautious with further intake."
                    case .evening, .lateEvening:
                        return "\(dayLabel), your calorie intake is clearly above your daily target for today."
                    }
                }
            }
        }
    }

    private func macroAttentionText(
        macro: MacroKind,
        tone: NutritionInsightTone,
        dayLabel: String,
        isToday: Bool
    ) -> String {

        let macroName: String
        switch macro {
        case .carbs:
            macroName = "carbohydrates"
        case .protein:
            macroName = "protein"
        case .fat:
            macroName = "fat"
        }

        let dayPrefix: String = isToday ? "\(dayLabel)," : "\(dayLabel),"

        switch tone {
        case .positive:
            return "\(dayPrefix) your overall energy is on track and your \(macroName) intake is supporting your targets."
        case .neutral:
            return "\(dayPrefix) your overall energy is on track, with a noticeable shift in \(macroName) compared with your target."
        case .warning:
            return "\(dayPrefix) your overall energy is acceptable, but \(macroName) intake clearly deviates from your target distribution."
        }
    }
}
