//
//  HomeView.swift
//  GluVibProbe
//

import SwiftUI

struct HomeView: View {

    // ------------------------------------------------------------
    // MARK: - Environment
    // ------------------------------------------------------------
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthStore: HealthStore

    // Orientation detection (robust, ohne UIKit)
    @Environment(\.verticalSizeClass) private var vSizeClass

    private var isLandscape: Bool {
        vSizeClass == .compact
    }

    // Fullscreen Landscape Presenter (iOS16-kompatibel)
    @State private var isMainChartLandscapePresented: Bool = false

    var body: some View {

        // ============================================================
        // Portrait Mode = dein bestehender ScrollView (UNVERÄNDERT)
        // Landscape wird als FullscreenCover darüber gelegt
        // ============================================================
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ------------------------------------------------------------
                // MARK: - Header
                // ------------------------------------------------------------
                VStack(alignment: .leading, spacing: 4) {
                    Text("")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text("")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // ------------------------------------------------------------
                // MARK: - MainChart (V1) — Embedded Component (Top)
                // ------------------------------------------------------------
                VStack(alignment: .leading, spacing: 12) {
                    MainChartViewV1(healthStore: healthStore)
                }
                .padding(.horizontal, 16)

                // ------------------------------------------------------------
                // MARK: - Metabolic Last 24 Hours (Quick KPIs)
                // ------------------------------------------------------------
                GlucoseSummaryCardV1()
                    .environmentObject(healthStore) // falls du HealthStore nicht sowieso schon als Env hast

                // ------------------------------------------------------------
                // MARK: - Metabolic Entry (V1) — Hook only (Buttons)
                // ------------------------------------------------------------
                VStack(alignment: .leading, spacing: 12) {

                    Text("Metabolic (V1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    HStack(spacing: 10) {

                        Button { appState.currentStatsScreen = .bolus } label: {
                            quickNavTile(
                                title: "Bolus",
                                subtitle: "Daily (90d) + periods",
                                systemImage: "drop.fill"
                            )
                        }

                        Button { appState.currentStatsScreen = .basal } label: {
                            quickNavTile(
                                title: "Basal",
                                subtitle: "Daily (90d) + periods",
                                systemImage: "capsule.fill"
                            )
                        }
                    }

                    HStack(spacing: 10) {

                        Button { appState.currentStatsScreen = .bolusBasalRatio } label: {
                            quickNavTile(
                                title: "Bolus/Basal",
                                subtitle: "Ratio (90d)",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }

                        Button { appState.currentStatsScreen = .carbsBolusRatio } label: {
                            quickNavTile(
                                title: "Carbs/Bolus",
                                subtitle: "g per IE (90d)",
                                systemImage: "chart.bar.fill"
                            )
                        }
                    }

                    HStack(spacing: 10) {

                        Button { appState.currentStatsScreen = .timeInRange } label: {
                            quickNavTile(
                                title: "Time in Range",
                                subtitle: "TIR (90d) — TODO",
                                systemImage: "checkmark.seal.fill"
                            )
                        }

                        Button { appState.currentStatsScreen = .gmi } label: {
                            quickNavTile(
                                title: "GMI",
                                subtitle: "GMI (90d) — TODO",
                                systemImage: "percent"
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)

                // ------------------------------------------------------------
                // MARK: - Placeholder
                // ------------------------------------------------------------
                VStack(alignment: .leading, spacing: 10) {
                    Text("Coming next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text("• Home content modules\n• Metabolic domain screens\n• Later: gating based on the toggles")
                        .font(.caption)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                }
                .padding(.horizontal, 16)

                // ------------------------------------------------------------
                // MARK: - Metabolic Setup (moved to bottom)
                // ------------------------------------------------------------
                VStack(alignment: .leading, spacing: 12) {

                    Text("Metabolic setup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    VStack(alignment: .leading, spacing: 10) {

                        statusRow(
                            title: "Insulin therapy",
                            subtitle: "Enabled if you regularly use insulin (bolus and/or basal).",
                            isOn: settings.isInsulinTreated
                        )

                        Divider().opacity(0.4)

                        statusRow(
                            title: "CGM sensor available",
                            subtitle: "Enabled if your glucose is tracked continuously via a sensor.",
                            isOn: settings.hasCGM
                        )
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.Glu.backgroundSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.Glu.primaryBlue.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.clear)
        .task {
            await healthStore.refreshMetabolicTodayRaw3DaysV1(refreshSource: "home")
            healthStore.recomputeCGMPeriodKPIsHybridV1()
        }

        // ============================================================
        // MARK: - Landscape Fullscreen (TabBar garantiert weg)
        // ============================================================
        .fullScreenCover(isPresented: $isMainChartLandscapePresented) {
            MainChartLandscapeViewV1()
                .environmentObject(healthStore)
                .environmentObject(settings)
        }
        .onAppear {
            if isLandscape, !isMainChartLandscapePresented {
                isMainChartLandscapePresented = true
            }
        }
        .onChange(of: vSizeClass) { _ in
            if isLandscape {
                if !isMainChartLandscapePresented {
                    isMainChartLandscapePresented = true
                }
            } else {
                if isMainChartLandscapePresented {
                    isMainChartLandscapePresented = false
                }
            }
        }
    }

    // ============================================================
    // MARK: - Strings
    // ============================================================

    private var meanGlucoseText: String {
        guard let mean = healthStore.last24hGlucoseMeanMgdl else { return "–" }
        return String(format: "%.0f mg/dL", mean)
    }

    private var glucoseSdLast24hText: String {
        guard let sd = healthStore.last24hGlucoseSdMgdl else { return "–" }
        return String(format: "%.0f mg/dL", sd)
    }

    private var glucoseCvLast24hText: String {
        // CV = SD / Mean * 100
        guard
            let mean = healthStore.last24hGlucoseMeanMgdl,
            let sd = healthStore.last24hGlucoseSdMgdl,
            mean > 0
        else { return "–" }

        let cv = (sd / mean) * 100.0
        return "\(Int(cv.rounded()))%"
    }

    private var tirLast24hText: String {
        let inRange = max(0, healthStore.last24hTIRInRangeMinutes)
        let cov = max(0, healthStore.last24hTIRCoverageMinutes)
        guard cov > 0 else { return "–" }
        let pct = Int((Double(inRange) / Double(cov) * 100).rounded())
        return "\(pct)%"
    }

    private var tirLast24hSubtitle: String {
        let cov = max(0, healthStore.last24hTIRCoverageMinutes)
        guard cov > 0 else { return "Last 24 h" }

        let low = max(0, healthStore.last24hTIRLowMinutes)
        let high = max(0, healthStore.last24hTIRHighMinutes)

        let lowPct = Int((Double(low) / Double(cov) * 100).rounded())
        let highPct = Int((Double(high) / Double(cov) * 100).rounded())

        let partial = healthStore.last24hTIRIsPartial ? " • partial" : ""
        return "Low \(lowPct)% • High \(highPct)%\(partial)"
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func statusRow(title: String, subtitle: String, isOn: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }

            Spacer()

            Text(isOn ? "On" : "Off")
                .font(.caption.weight(.semibold))
                .foregroundColor(isOn ? Color.Glu.metabolicDomain : Color.Glu.primaryBlue.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.Glu.metabolicDomain.opacity(isOn ? 0.14 : 0.06))
                )
        }
    }

    private func metabolicKpiTile(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {

                // !!! UPDATED: KPI icon in primaryBlue (not metabolicDomain)
                Image(systemName: systemImage)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.90))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.backgroundSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.metabolicDomain.opacity(0.25), lineWidth: 1.6)
            )
        }
        .buttonStyle(.plain)
    }

    private func quickNavTile(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 10) {

            Image(systemName: systemImage)
                .foregroundColor(Color.Glu.metabolicDomain.opacity(0.85))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.45))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.Glu.backgroundSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Glu.metabolicDomain.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("HomeView") {
    HomeView()
        .environmentObject(SettingsModel.shared)
        .environmentObject(AppState())
        .environmentObject(HealthStore.preview())
}
