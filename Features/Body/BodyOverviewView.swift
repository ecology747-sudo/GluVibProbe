//
//  BodyOverviewView.swift
//  GluVibProbe
//
//  Overview-Screen für die Body-Domain:
//  - Header ("Body Overview" + Datum + Domain-Label)
//  - 2 Kacheln: Sleep Today, Weight Today
//  - Navigation in die Detail-Metriken über AppState
//

import SwiftUI

struct BodyOverviewView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthStore: HealthStore

    @StateObject private var viewModel: BodyOverviewViewModel

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        _viewModel = StateObject(
            wrappedValue: BodyOverviewViewModel(healthStore: healthStore)
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                headerSection

                overviewCardsSection
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .background(Color.Glu.backgroundSurface.ignoresSafeArea())
        .task {
            viewModel.refresh()
        }
        .refreshable {
            viewModel.refresh()
        }
    }
}

// MARK: - Header

private extension BodyOverviewView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Titel zentriert oben
            HStack {
                Spacer()
                Text("Body Overview")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Glu.primaryBlue)
                Spacer()
            }

            // Zweite Zeile: Datum links, Domain-Label rechts
            HStack {
                Text(todayString)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))

                Spacer()

                Text("Body Domain")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Glu.bodyDomain)
            }
        }
    }

    var todayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - Overview Cards (Sleep + Weight)

private extension BodyOverviewView {

    var overviewCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Today's Body Snapshot")
                .font(.headline)
                .foregroundStyle(Color.Glu.primaryBlue)
                .padding(.leading, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2),
                spacing: 14
            ) {

                // SLEEP
                bodyCard(
                    title: "Sleep",
                    value: viewModel.formattedTodaySleep,
                    subtitle: "Last night",
                    color: Color.Glu.bodyDomain
                ) {
                    // 👉 auf Sleep-Detail umschalten
                    appState.currentStatsScreen = .sleep
                }

                // WEIGHT
                bodyCard(
                    title: "Weight",
                    value: viewModel.formattedTodayWeight,
                    subtitle: "Latest value",
                    color: Color.Glu.bodyDomain.opacity(0.85)
                ) {
                    // 👉 auf Weight-Detail umschalten
                    appState.currentStatsScreen = .weight
                }
            }
        }
    }

    func bodyCard(
        title: String,
        value: String,
        subtitle: String,
        color: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color.Glu.primaryBlue)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))

            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.22),
                            color.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.12),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .onTapGesture { onTap() }
    }
}

// MARK: - Preview

#Preview("BodyOverviewView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    return BodyOverviewView(healthStore: previewStore)
        .environmentObject(previewStore)
        .environmentObject(previewState)
        .background(Color.Glu.backgroundSurface)
}
