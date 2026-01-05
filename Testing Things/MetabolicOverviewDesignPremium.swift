//
//  MetabolicOverviewDesignPremium.swift
//  GluVibProbe
//
//  DESIGN CONCEPT (Premium Metabolic Overview)
//  - ONE single MainChart card (no extra card below it)
//  - Header subtitle: LAST 24 HOURS
//  - Glucose Summary card: uses GlucoseSummaryCardDesign.swift (design-only)
//  - Example numbers baked in (design-only)
//

import SwiftUI

// MARK: - Scroll Offset Preference (Sticky Header)

private struct MetabolicScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MetabolicOverviewDesignPremium: View {

    // MARK: - Environment

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // MARK: - Sticky Header

    @State private var hasScrolled: Bool = false

    // MARK: - Design Sample Numbers (24h)

    private let avgGlucoseMgdl: Int = 132
    private let avgTirPercent: Int = 74
    private let avgSdMgdl: Int = 42
    private let avgCvPercent: Int = 31

    private let gmi90dPercent: Double = 6.8

    private let activeEnergyKcal24h: Int = 820
    private let carbsG24h: Int = 185

    private let bolusIU24h: Double = 14.5
    private let basalIU24h: Double = 18.0
    private let bolusBasalRatio: Double = 0.81
    private let carbsBolusRatio: Double = 12.8

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.metabolicDomain.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ZStack(alignment: .top) {

                ScrollView {
                    VStack(spacing: 16) {

                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: MetabolicScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)

                        // ------------------------------------------------------------
                        // MARK: - MainChart (ONE card only)
                        // ------------------------------------------------------------
                        VStack(alignment: .leading, spacing: 0) {

                            // ✅ IMPORTANT: no surrounding "extra card" or background here
                            MainChartViewV1(healthStore: healthStore)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.90), lineWidth: 1.6)
                                )
                        }
                        .padding(.horizontal, 16)

                        // ------------------------------------------------------------
                        // MARK: - Glucose Summary (REPLACED)
                        // ------------------------------------------------------------
                        GlucoseSummaryCardDesign(
                            avgGlucoseMgdl: 132,
                            avgTirPercent: 74,
                            avgSdMgdl: 42,
                            avgCvPercent: 31,
                            gmi90dPercent: 6.8
                        ).padding(.horizontal, 16)

                      

                        // ------------------------------------------------------------
                        // MARK: - Active Energy + Carbs (24h)
                        // ------------------------------------------------------------
                        HStack(spacing: 12) {
                            MetricHalfCardDesign(
                                icon: "flame.fill",
                                iconTint: Color.Glu.nutritionDomain.opacity(0.95),
                                title: "Active energy",
                                value: "\(activeEnergyKcal24h)",
                                unit: "kcal",
                                subtitle: "Last 24 hours",
                                domainColor: Color.Glu.metabolicDomain,
                                onTap: { appState.currentStatsScreen = .activityEnergy }
                            )

                            MetricHalfCardDesign(
                                icon: "leaf.fill",
                                iconTint: Color.Glu.nutritionDomain.opacity(0.95),
                                title: "Carbs",
                                value: "\(carbsG24h)",
                                unit: "g",
                                subtitle: "Last 24 hours",
                                domainColor: Color.Glu.metabolicDomain,
                                onTap: { appState.currentStatsScreen = .carbs }
                            )
                        }
                        .padding(.horizontal, 16)

                        // ------------------------------------------------------------
                        // MARK: - Insulin (24h)
                        // ------------------------------------------------------------
                        VStack(alignment: .leading, spacing: 12) {

                            HStack(spacing: 8) {
                                Image(systemName: "syringe")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))

                                Text("Insulin & Ratios")
                                    .font(.headline)
                                    .foregroundColor(Color.Glu.primaryBlue)

                                Spacer()
                            }

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ],
                                spacing: 10
                            ) {

                                MetricKpiTileDesign(
                                    title: "Average Bolus",
                                    value: String(format: "%.1f", bolusIU24h),
                                    unit: "IU",
                                    subtitle: "Last 24 hours",
                                    systemImage: "drop.fill",
                                    onTap: { appState.currentStatsScreen = .bolus }
                                )

                                MetricKpiTileDesign(
                                    title: "Average Basal",
                                    value: String(format: "%.1f", basalIU24h),
                                    unit: "IU",
                                    subtitle: "Last 24 hours",
                                    systemImage: "capsule.fill",
                                    onTap: { appState.currentStatsScreen = .basal }
                                )

                                MetricKpiTileDesign(
                                    title: "Bolus / Basal",
                                    value: String(format: "%.2f", bolusBasalRatio),
                                    unit: "",
                                    subtitle: "Ratio (Last 24 hours)",
                                    systemImage: "arrow.left.arrow.right",
                                    onTap: { appState.currentStatsScreen = .bolusBasalRatio }
                                )

                                MetricKpiTileDesign(
                                    title: "Carbs / Bolus",
                                    value: String(format: "%.1f", carbsBolusRatio),
                                    unit: "g/IU",
                                    subtitle: "Ratio (Last 24 hours)",
                                    systemImage: "chart.bar.fill",
                                    onTap: { appState.currentStatsScreen = .carbsBolusRatio }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 30)
                }
                .onPreferenceChange(MetabolicScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }

                // ------------------------------------------------------------
                // MARK: - Header (reserved space, subtitle LAST 24 HOURS)
                // ------------------------------------------------------------
                OverviewHeader(
                    title: "Metabolic Overview",
                    subtitle: "LAST 24 HOURS",
                    tintColor: Color.Glu.metabolicDomain,
                    hasScrolled: hasScrolled
                )
            }
        }
    }
}

// ============================================================
// MARK: - KPI Tiles (Design)
// ============================================================

private struct MetricKpiTileDesign: View {

    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let systemImage: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {

                Image(systemName: systemImage)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.95))
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 3) {

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.80))

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(value)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.Glu.primaryBlue)

                        if !unit.isEmpty {
                            Text(unit)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color.Glu.primaryBlue.opacity(0.70))
                        }
                    }

                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.35))
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
}

private struct MetricHalfCardDesign: View {

    let icon: String
    let iconTint: Color
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let domainColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {

                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconTint)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Spacer()
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {

                    Text(value)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

                    Spacer()
                }

                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.65))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.backgroundSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(domainColor.opacity(0.25), lineWidth: 1.6)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MetricWideCardDesign: View {

    let icon: String
    let iconTint: Color
    let title: String
    let value: String
    let subtitle: String
    let domainColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {

                Image(systemName: icon)
                    .foregroundColor(iconTint)
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))

                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.60))
                }

                Spacer()
            }

            Text(value)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color.Glu.primaryBlue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.Glu.backgroundSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(domainColor.opacity(0.25), lineWidth: 1.6)
        )
    }
}

// MARK: - Preview (minimal)

#Preview("Metabolic Overview Design Premium") {
    MetabolicOverviewDesignPremium()
        .environmentObject(SettingsModel.shared)
        .environmentObject(AppState())
        .environmentObject(HealthStore.preview())
}
