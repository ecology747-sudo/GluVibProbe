//
//  CGMRaw3DaysDebugViewV1.swift
//  GluVibProbe
//
//  Debug View (Raw3Days):
//  - Today / Yesterday / Day-2
//  - EIN Datenpfad: samplesForSelectedDay ist SSOT für Count/First/Last/List/Chart
//  - Keine Berechnungen (kein TIR, kein SD/CV)
//

import SwiftUI
import Charts

struct CGMRaw3DaysDebugViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @State private var selectedIndex: Int = 0   // 0 = Today, 1 = Yesterday, 2 = Day-2

    // MARK: - Day Selection Helpers

    private var selectedDayStart: Date {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -selectedIndex, to: todayStart) ?? todayStart
    }

    private var selectedDayEnd: Date {
        let cal = Calendar.current

        // Today: bis "jetzt"
        if selectedIndex == 0 {
            return Date()
        }

        // Past day: bis Start+1 Tag (exklusiv)
        return cal.date(byAdding: .day, value: 1, to: selectedDayStart) ?? Date()
    }

    // ✅ EINZIGE Quelle für UI (Count/First/Last/List/Chart)
    private var samplesForSelectedDay: [CGMSamplePoint] {
        healthStore.cgmSamples3Days
            .filter { $0.timestamp >= selectedDayStart && $0.timestamp < selectedDayEnd }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var firstSampleText: String {
        guard let first = samplesForSelectedDay.first else { return "–" }
        return first.timestamp.formatted(.dateTime.day().month().year().hour().minute())
    }

    private var lastSampleText: String {
        guard let last = samplesForSelectedDay.last else { return "–" }
        return last.timestamp.formatted(.dateTime.day().month().year().hour().minute())
    }

    private var minY: Double {
        guard let minVal = samplesForSelectedDay.map(\.glucoseMgdl).min() else { return 70 }
        return floor(minVal / 10) * 10
    }

    private var maxY: Double {
        guard let maxVal = samplesForSelectedDay.map(\.glucoseMgdl).max() else { return 180 }
        return ceil(maxVal / 10) * 10
    }

    // MARK: - Body

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,

            onBack: { appState.currentStatsScreen = .none },

            onRefresh: {
                await healthStore.refreshMetabolicTodayRaw3DaysV1(refreshSource: "pullToRefresh")
            },

            background: {
                LinearGradient(
                    colors: [.white, Color.Glu.metabolicDomain.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        ) {

            VStack(alignment: .leading, spacing: 12) {

                Text("CGM Raw3Days Debug")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 16)

                Picker("", selection: $selectedIndex) {
                    Text("Today").tag(0)
                    Text("Yesterday").tag(1)
                    Text("Day -2").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Samples: \(samplesForSelectedDay.count)")
                        .font(.headline)

                    Text("First: \(firstSampleText)")
                        .font(.subheadline)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))

                    Text("Last:  \(lastSampleText)")
                        .font(.subheadline)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.8))
                }
                .padding(.horizontal, 16)

                // ----------------------------
                // Chart
                // ----------------------------
                if samplesForSelectedDay.isEmpty {
                    Text("No CGM samples for selected day.")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                } else {
                    Chart(samplesForSelectedDay) { p in
                        LineMark(
                            x: .value("Time", p.timestamp),
                            y: .value("mg/dL", p.glucoseMgdl)
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: minY...maxY)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 6))
                    }
                    .frame(height: 220)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.Glu.backgroundSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.Glu.metabolicDomain.opacity(0.25), lineWidth: 1.6)
                    )
                    .padding(.horizontal, 16)
                }

                // ----------------------------
                // List (Scroll)
                // ----------------------------
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(samplesForSelectedDay) { s in
                            HStack {
                                Text(s.timestamp.formatted(.dateTime.hour().minute()))
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(Color.Glu.primaryBlue)

                                Spacer()

                                Text("\(Int(s.glucoseMgdl.rounded())) mg/dL")
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider()
                                .opacity(0.25)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .task {
            await healthStore.refreshMetabolicTodayRaw3DaysV1(refreshSource: "navigation")
        }
    }
}

// MARK: - Preview

#Preview("CGMRaw3DaysDebugViewV1") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return CGMRaw3DaysDebugViewV1()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
