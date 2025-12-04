//
//  ActivityOverviewView.swift
//  GluVibProbe
//
//  Einfache Activity-Overview:
//  - Header mit Datum
//  - 2 große Cards: Steps Today & Active Energy Today
//  - Tap auf Card → wechselt in die jeweilige Metrik (StepsView / ActivityEnergyView)
//

import SwiftUI

struct ActivityOverviewView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - ViewModel

    @StateObject private var viewModel: ActivityOverviewViewModel

    // MARK: - Init

    init(viewModel: ActivityOverviewViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: viewModel ?? ActivityOverviewViewModel(healthStore: HealthStore.shared)
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // HEADER: Titel + Datum
                header

                // TWO MAIN CARDS
                VStack(spacing: 16) {
                    stepsCard
                    activeEnergyCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color.Glu.backgroundSurface.ignoresSafeArea())
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Header

private extension ActivityOverviewView {

    var header: some View {
        VStack(spacing: 4) {

            Text("Activity Overview")
                .font(.title2.bold())
                .foregroundStyle(Color.Glu.primaryBlue)

            HStack {
                // Linksbündig: Datum
                Text(Date.now, style: .date)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))

                Spacer()

                // Rechtsbündig: kleiner Tag-Label (optional)
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Glu.activityDomain.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.Glu.activityDomain.opacity(0.18))
                    )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
