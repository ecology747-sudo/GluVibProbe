//
//  BodyOverviewView.swift
//  GluVibProbe
//
//  Real Body Overview View
//  - Uses BodyOverviewViewModel
//  - Design based on the approved BodyOverviewDesignView
//  - Sticky OverviewHeader (analog zur NutritionOverviewView)
//

import SwiftUI
import Charts

// MARK: - Scroll Offset Preference (für Sticky-Header)

private struct BodyScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BodyOverviewView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel

    @StateObject private var viewModel: BodyOverviewViewModel

    // MARK: - State (für Sticky-Header-Background)

    @State private var hasScrolled: Bool = false

    // MARK: - Init

    init(viewModel: BodyOverviewViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: BodyOverviewViewModel(
                    healthStore: HealthStore.shared,
                    settings: .shared
                )
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            // Hintergrund-Gradient in Body-Farbwelt
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.Glu.bodyDomain.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Inhalt + Sticky Header im Overlay
            ZStack(alignment: .top) {

                // MARK: - ScrollView mit Offset-Messung
                ScrollView {
                    VStack(spacing: 16) {

                        // Globaler Scroll-Offset für Sticky-Header
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: BodyScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)

                        // Inhalt unter dem Header
                        content
                    }
                    // Abstand vom Header
                    .padding(.top, 52)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .onPreferenceChange(BodyScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }

                // MARK: - Sticky OverviewHeader (Overlay)
                OverviewHeader(
                    title: "Body Overview",
                    subtitle: formattedToday(),
                    tintColor: Color.Glu.bodyDomain,
                    hasScrolled: hasScrolled
                )
            }
        }
    }

    // MARK: - Inhalt-Stapel (ohne Header)

    private var content: some View {
        VStack(spacing: 16) {

            // 🔶 Weight → .weight
            WeightMainCard(viewModel: viewModel)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentStatsScreen = .weight
                }

            HStack(spacing: 12) {

                // 🔵 Sleep → .sleep
                SleepSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.currentStatsScreen = .sleep
                    }

                // ❤️ Heart & stress → .restingHeartRate
                HeartSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.currentStatsScreen = .restingHeartRate
                    }
            }

            HStack(spacing: 12) {

                // 🧍‍♂️ BMI → .bmi
                BMISmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.currentStatsScreen = .bmi
                    }

                // 🧈 Body fat → .bodyFat
                BodyFatSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.currentStatsScreen = .bodyFat
                    }
            }

            BodyInsightCard(viewModel: viewModel)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Optional: später z.B. zu .weight oder .sleep springen
                }
        }
    }

    // MARK: - Datum für Header

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - Weight main card

private struct WeightMainCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // eigenes Accent-Color für diese Card
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Title row with big trend arrow on the right
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(accent)

                    Text("Weight & trend")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.headline.weight(.semibold))

                Spacer()

                Image(systemName: viewModel.trendArrowSymbol())
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(viewModel.trendArrowColor())
            }

            // KPI
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedWeight(viewModel.todayWeightKg))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                HStack(spacing: 8) {
                    Text("Target: \(viewModel.formattedWeight(viewModel.targetWeightKg))")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text("·")
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    Text(viewModel.formattedDeltaKg(viewModel.weightDeltaKg))
                        .foregroundColor(viewModel.deltaColor(for: viewModel.weightDeltaKg))
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            // Compact bar chart
            if !viewModel.weightTrend.isEmpty {
                WeightMiniTrendChart(data: viewModel.weightTrend)
                    .frame(height: 60)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.70), lineWidth: 1.2)   // stärkere Outline
                )
        )
    }
}

// MARK: - Sleep small tile

private struct SleepSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Lime wie „Protein“ (Recovery-Feeling)
    private let accent = Color.Glu.metabolicDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(accent)

                    Text("Sleep")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedSleep(minutes: viewModel.lastNightSleepMinutes))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Last night")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            // 🔧 HIER ist die korrigierte Version
            VStack(alignment: .leading, spacing: 4) {
                let ratio = min(viewModel.sleepGoalCompletion, 1.5)
                let percent = Int(ratio * 100)

                let goalMinutes = viewModel.sleepGoalMinutes
                let goalHours = Double(goalMinutes) / 60.0

                let goalString = goalHours.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f h", goalHours)
                    : String(format: "%.1f h", goalHours)

                ProgressView(value: ratio, total: 1.0)
                    .tint(accent)

                Text("Goal completion: \(percent)% of \(goalString)")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 170)   // ✅ feste Höhe für Sleep
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Heart small tile

private struct HeartSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Aqua wie „Carbs“ – energetisch, frisch
    private let accent = Color.Glu.nutritionDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(accent)

                    Text("Heart")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.restingHeartRateBpm) bpm")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Resting heart rate")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.hrvMs) ms")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("HRV today")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 170)   // ✅ gleiche Höhe wie Sleep
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - BMI tile

private struct BMISmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Wieder Lime wie Protein/Sleep
    private let accent = Color.Glu.metabolicDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.arms.open")
                        .foregroundColor(accent)

                    Text("BMI")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", viewModel.bmi))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text(viewModel.bmiCategoryText(for: viewModel.bmi))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)   // ✅ feste Höhe für BMI
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Body fat tile

private struct BodyFatSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Orange wie Fat / Body-Domain
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(accent)

                    Text("Body fat")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f %%", viewModel.bodyFatPercent))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Estimated body fat")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)   // ✅ gleiche Höhe wie BMI
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Insight card

private struct BodyInsightCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Insight")                    // 🔁 Titel angepasst
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                Spacer()
            }

            Text(viewModel.bodyInsightText())
                .font(.subheadline)
                .foregroundColor(Color.Glu.primaryBlue)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Mini bar chart for weight

private struct WeightMiniTrendChart: View {

    let data: [WeightTrendPoint]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Weight", point.weightKg)
            )
        }
        .foregroundStyle(Color.Glu.bodyDomain)   // 🔶 Body Domain Farbe
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
    }
}

// MARK: - Preview

#Preview("BodyOverviewView") {
    BodyOverviewView(viewModel: BodyOverviewViewModel.preview)
        .environmentObject(AppState())
}
