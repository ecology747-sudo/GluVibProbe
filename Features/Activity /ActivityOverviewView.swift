//
//  ActivityOverviewView.swift
//  GluVibProbe
//
//  Einfache Activity-Overview:
//  - Sticky-Header (OverviewHeader) mit Datum
//  - 2 große Cards: Steps Today & Active Energy Today
//  - Tap auf Card → wechselt in die jeweilige Metrik (StepsView / ActivityEnergyView)
//

import SwiftUI

// MARK: - Scroll Offset Preference
// 👉 Neu: wie bei NutritionOverviewView, um den Scroll-Status für den Header zu erkennen
private struct ActivityScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ActivityOverviewView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - ViewModel

    @StateObject private var viewModel: ActivityOverviewViewModel

    // MARK: - State (für Sticky-Header-Background)
    // 👉 Neu: steuert, ob der OverviewHeader seinen Blur/Background aktivieren soll
    @State private var hasScrolled: Bool = false

    // MARK: - Init

    init(viewModel: ActivityOverviewViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? ActivityOverviewViewModel(healthStore: HealthStore.shared)
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // MARK: Hintergrund in ACTIVITY-Farbwelt (analog Nutrition/Body)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.Glu.activityDomain.opacity(0.4)   // ⬅️ Activity-Rot
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 👉 Neu: ZStack, damit der OverviewHeader ÜBER dem ScrollView liegt (wie bei Nutrition)
            ZStack(alignment: .top) {

                // MARK: - Scrollbarer Inhalt
                ScrollView {
                    VStack(spacing: 24) {

                        // 👉 Neu: unsichtbarer GeometryReader misst globalen Offset
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ActivityScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)

                        // TWO MAIN CARDS (unverändert)
                        VStack(spacing: 16) {
                            stepsCard
                            activeEnergyCard
                        }
                    }
                    // 👉 Neu: kleiner Top-Padding, damit Inhalt UNTER dem Header startet
                    .padding(.top, 25)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .onPreferenceChange(ActivityScrollOffsetKey.self) { offset in
                    // 👉 Neu: sobald nach oben gescrollt wird (offset < 0), Header „aktiv“
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }

                // MARK: - Sticky-Header mit Blur (OverviewHeader)
                OverviewHeader(
                    title: "Activity Overview",
                    subtitle: todayString,                      // Datum wie bei Nutrition
                    tintColor: Color.Glu.activityDomain,        // Domain-Farbe Activity
                    hasScrolled: hasScrolled                    // aktuell nicht in Header genutzt, API-ready
                )
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
}

// MARK: - Datum-Helper (wie in NutritionOverviewView)

private extension ActivityOverviewView {
    var todayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}

// MARK: - Cards

private extension ActivityOverviewView {

    /// Card: Steps Today
    var stepsCard: some View {
        Button {
            // 👉 in Steps-Metrik wechseln
            appState.currentStatsScreen = .steps
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Steps Today")
                        .font(.headline)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))

                    Text(formattedSteps(viewModel.todaySteps))
                        .font(.title.bold())
                        .foregroundStyle(Color.Glu.primaryBlue)

                    Text("Daily movement from all day")
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))
                }

                Spacer()

                // kleines Icon / Kreis rechts
                ZStack {
                    Circle()
                        .fill(Color.Glu.activityDomain.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.Glu.activityDomain)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.Glu.activityDomain.opacity(0.22),
                                Color.Glu.activityDomain.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.Glu.activityDomain.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(0.12),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Card: Active Energy Today
    var activeEnergyCard: some View {
        Button {
            // 👉 in Activity-Energy-Metrik wechseln
            appState.currentStatsScreen = .activityEnergy
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Energy")
                        .font(.headline)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))

                    Text("\(viewModel.todayActiveEnergyKcal) kcal")
                        .font(.title.bold())
                        .foregroundStyle(Color.Glu.primaryBlue)

                    Text("Move calories from workouts & daily activity")
                        .font(.caption)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.Glu.activityDomain.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.Glu.activityDomain)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.Glu.activityDomain.opacity(0.22),
                                Color.Glu.activityDomain.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.Glu.activityDomain.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(0.12),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    func formattedSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Preview

#Preview("ActivityOverviewView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM    = ActivityOverviewViewModel(healthStore: previewStore)

    return ActivityOverviewView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .background(Color.Glu.backgroundSurface)
}
