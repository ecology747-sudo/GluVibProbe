//
//  PremiumOverviewViewV1.swift
//  GluVibProbe
//
//  Premium Home (Overview) — V1
//
//  FIX: Unified vertical spacing between ALL overview cards (Single Source of Truth)
//  - Use ONE spacing token for the main stack
//  - Conditional blocks must NOT introduce extra/irregular gaps
//  - Therapy cards are inserted as normal items (no nested VStack)
//

import SwiftUI

private struct PremiumScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PremiumOverviewViewV1: View {

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var appState: AppState

    @State private var hasScrolled: Bool = false

    @Environment(\.verticalSizeClass) private var vSizeClass
    private var isLandscape: Bool { vSizeClass == .compact }

    @State private var isMainChartLandscapePresented: Bool = false
    @State private var didInitialLoad: Bool = false

    // Single Source of Truth for vertical spacing between cards
    private let cardSpacing: CGFloat = 16

    var body: some View {
        ZStack(alignment: .top) {

            LinearGradient(
                colors: [
                    .white,
                    Color.Glu.metabolicDomain.opacity(0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: cardSpacing) {

                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: PremiumScrollOffsetKey.self,
                                value: geo.frame(in: .global).minY
                            )
                    }
                    .frame(height: 0)

                    if settings.hasCGM {
                        MainChartViewV1(
                            healthStore: healthStore,
                            chipLayout: .twoRows,
                            interactionMode: .embedded
                        )
                        .environmentObject(settings)
                    }

                    if settings.hasCGM {
                        GlucoseOverviewAverageCardV1()
                        GlucoseOverviewTIRCardV1()
                        GlucoseSummaryKPIsSectionV1()
                    }

                    if settings.isInsulinTreated {
                        BolusOverviewCard(
                            healthStore: healthStore,
                            onTap: { appState.currentStatsScreen = .bolus }
                        )

                        BasalOverviewCard(
                            healthStore: healthStore,
                            onTap: { appState.currentStatsScreen = .basal }
                        )

                        CarbsOverviewCard(
                            healthStore: healthStore,
                            settings: settings,
                            onTap: {
                                appState.currentStatsScreen = .carbs
                                appState.requestedTab = .nutrition
                            }
                        )

                        ActivityEnergyOverviewCard(
                            healthStore: healthStore,
                            onTap: {
                                appState.currentStatsScreen = .activityEnergy
                                appState.requestedTab = .activity
                            }
                        )

                        CarbsBolusRatioOverviewCard(
                            healthStore: healthStore,
                            onTap: { appState.currentStatsScreen = .carbsBolusRatio }
                        )

                        BolusBasalRatioOverviewCard(
                            healthStore: healthStore,
                            onTap: { appState.currentStatsScreen = .bolusBasalRatio }
                        )
                    }

                    Spacer(minLength: 8)
                }
                .padding(.top, 30)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .onPreferenceChange(PremiumScrollOffsetKey.self) { offset in
                withAnimation(.easeInOut(duration: 0.22)) {
                    hasScrolled = offset < 0
                }
            }
            .refreshable {
                // UPDATED: Overview should only load what is visible on this screen (lightweight)
                await healthStore.refreshMetabolicOverview(.pullToRefresh)
            }
            .task {
                guard !didInitialLoad else { return }
                didInitialLoad = true
                // UPDATED: Initial load should use the lightweight Overview refresh (no detail metrics)
                await healthStore.refreshMetabolicOverview(.navigation)
            }

            OverviewHeader(
                title: "Premium Overview",
                subtitle: premiumHeaderSubtitle,
                tintColor: Color.Glu.metabolicDomain,
                hasScrolled: hasScrolled
            )
        }
        .fullScreenCover(isPresented: $isMainChartLandscapePresented) {
            MainChartLandscapeViewV1()
                .environmentObject(healthStore)
                .environmentObject(settings)
        }
        .onChange(of: vSizeClass) { _ in
            if !isLandscape, isMainChartLandscapePresented {
                isMainChartLandscapePresented = false
            }
        }
    }

    private var premiumHeaderSubtitle: String {
        settings.isInsulinTreated
            ? "Satus: Insulin metrics On"
            : "Status: Insulin metrics Off"
    }}

// MARK: - Preview

#Preview("Premium Overview V1") {
    let store = HealthStore.preview()
    let state = AppState()

    return PremiumOverviewViewV1()
        .environmentObject(store)
        .environmentObject(SettingsModel.shared)
        .environmentObject(state)
}
