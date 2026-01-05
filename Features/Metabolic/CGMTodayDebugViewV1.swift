//
//  CGMTodayDebugViewV1.swift
//  GluVibProbe
//
//  Provisorische Debug-View:
//  - Zeigt NUR heutigen Tag aus HealthStore.cgmSamples3Days
//  - Keine Berechnungen (kein SD/CV/TIR), nur rohe Linie
//

import SwiftUI
import Charts

struct CGMTodayDebugViewV1: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    private var todaySamples: [CGMSamplePoint] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = Date()

        return healthStore.cgmSamples3Days
            .filter { $0.timestamp >= start && $0.timestamp <= end }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var minY: Double {
        guard let minVal = todaySamples.map(\.glucoseMgdl).min() else { return 70 }
        return floor(minVal / 10) * 10
    }

    private var maxY: Double {
        guard let maxVal = todaySamples.map(\.glucoseMgdl).max() else { return 180 }
        return ceil(maxVal / 10) * 10
    }

    var body: some View {
        MetricDetailScaffold(
            headerTitle: "Metabolic",
            headerTint: Color.Glu.metabolicDomain,
            onBack: { appState.currentStatsScreen = .none },
            onRefresh: {
                await healthStore.refreshMetabolicTodayRaw3DaysV1(refreshSource: "pullToRefresh")   // !!! UPDATED
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

                // Quick status
                HStack {
                    Text("CGM Today")
                        .font(.headline)
                    Spacer()
                    Text("\(todaySamples.count) samples")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }

                // Chart
                if todaySamples.isEmpty {
                    Text("No CGM samples for today yet.")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                        .padding(.top, 8)
                } else {
                    Chart(todaySamples) { p in
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .task {
            await healthStore.refreshMetabolicTodayRaw3DaysV1(refreshSource: "navigation")           // !!! UPDATED
        }
    }
}

// MARK: - Preview

#Preview("CGMTodayDebugViewV1") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return CGMTodayDebugViewV1()
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .environmentObject(SettingsModel.shared)
}
