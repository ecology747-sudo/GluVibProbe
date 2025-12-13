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

    // MARK: - State (für Sticky-Header & Pager)

    @State private var hasScrolled: Bool = false
    @State private var selectedPage: Int = 2      // 0 = DayBefore, 1 = Yesterday, 2 = Today

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

            // Inhalt + Sticky Header + Custom Dots im Overlay
            ZStack(alignment: .top) {

                // MARK: - Horizontaler Pager (3 Tage)
                TabView(selection: $selectedPage) {

                    dayScrollView.tag(0)  // DayBefore
                    dayScrollView.tag(1)  // Yesterday
                    dayScrollView.tag(2)  // Today
                }
                .tabViewStyle(.page(indexDisplayMode: .never))   // System-Dots AUS
                .onPreferenceChange(BodyScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                .onChange(of: selectedPage) { newIndex in
                    viewModel.selectedDayOffset = dayOffset(for: newIndex)
                    Task { await viewModel.refresh() }
                }
                .onAppear {
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)
                }

                // MARK: - Sticky OverviewHeader (Overlay)
                OverviewHeader(
                    title: "Body Overview",
                    subtitle: formattedHeaderSubtitle(),
                    tintColor: Color.Glu.bodyDomain,
                    hasScrolled: hasScrolled
                )

                // MARK: - Custom PageDots
                VStack {
                    Spacer()
                    PageDots(
                        selected: selectedPage,
                        total: 3,
                        color: Color.Glu.bodyDomain
                    )
                    .padding(.bottom, 12)
                }
            }
        }
        .task(id: viewModel.selectedDayOffset) {
            await viewModel.refresh()
        }
    }

    // MARK: - Inhalt-Stapel (ohne Header)

    private var content: some View {
        VStack(spacing: 16) {

            WeightMainCard(viewModel: viewModel)
                .contentShape(Rectangle())
                .onTapGesture { appState.currentStatsScreen = .weight }

            HStack(spacing: 12) {
                SleepSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.currentStatsScreen = .sleep }

                HeartSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.currentStatsScreen = .restingHeartRate }
            }

            HStack(spacing: 12) {
                BMISmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.currentStatsScreen = .bmi }

                BodyFatSmallCard(viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture { appState.currentStatsScreen = .bodyFat }
            }

            BodyInsightCard(viewModel: viewModel)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Tages-ScrollView

private extension BodyOverviewView {

    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {

                GeometryReader { geo in
                    Color.clear.preference(
                        key: BodyScrollOffsetKey.self,
                        value: geo.frame(in: .global).minY
                    )
                }
                .frame(height: 0)

                content
            }
            .padding(.top, 52)
            .padding(.horizontal, 16)
            .padding(.bottom, 60)   // Platz für CustomDots
        }
        .refreshable { await viewModel.refresh() }
    }
}

// MARK: - Datum / Header Subtitle

private extension BodyOverviewView {

    /// TODAY, YESTERDAY oder Datum
    func formattedHeaderSubtitle() -> String {
        switch viewModel.selectedDayOffset {
        case 0:
            return "TODAY"
        case -1:
            return "YESTERDAY"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: viewModel.selectedDate)
        }
    }
}

// MARK: - Pager Mapping

private extension BodyOverviewView {

    func dayOffset(for pageIndex: Int) -> Int {
        switch pageIndex {
        case 0: return -2
        case 1: return -1
        default: return 0
        }
    }

    func pageIndex(for offset: Int) -> Int {
        switch offset {
        case -2: return 0
        case -1: return 1
        default: return 2
        }
    }
}

// MARK: - Custom PageDots

private struct PageDots: View {
    let selected: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == selected ? color : color.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Weight main card

private struct WeightMainCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // eigenes Accent-Color für diese Card (bleibt Body-Domain)
    private let accent = Color.Glu.bodyDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // HEADER mit Titel + Trendpfeil (analog ActivityOverview)
            HStack {
                Label {
                    Text("Weight")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                } icon: {
                    Image(systemName: "figure.stand")
                        .foregroundColor(Color.Glu.bodyDomain)
                }

                Spacer()

                // Trendpfeil – exakt wie in ActivityOverview-Steps (Design)
                Image(systemName: viewModel.trendArrowSymbol())      // <<< aus ViewModel
                    .font(.title2.weight(.bold))                    // gleiche Größe
                    .foregroundColor(viewModel.trendArrowColor())   // grün / rot / blau
                    .padding(.trailing, 2)
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

            // Compact BAR chart
            if !viewModel.weightTrend.isEmpty {
                WeightMiniBarChart(data: viewModel.weightTrend)
                    .frame(height: 60)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.6)
                )
        )
    }
}


// MARK: - Sleep small tile

private struct SleepSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Lime wie „Protein“ (Recovery-Feeling) – nur Icon/Text, nicht mehr Rahmenfarbe
    private let accent = Color.Glu.metabolicDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // HEADER (Icon + Titel)
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

            // MITTLERER BLOCK (Wert + Beschreibung)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedSleep(minutes: viewModel.lastNightSleepMinutes))
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Last night")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            // UNTERER BLOCK (Progress + Text)
            VStack(alignment: .leading, spacing: 4) {
                // !!! CHANGED: 100 % Target = voller Balken
                let rawRatio = viewModel.sleepGoalMinutes > 0
                    ? Double(viewModel.lastNightSleepMinutes) / Double(viewModel.sleepGoalMinutes)
                    : 0.0

                let ratio = max(0.0, min(rawRatio, 1.0))          // !!! CHANGED (Clamp 0...1)
                let percent = Int(rawRatio * 100)                 // !!! CHANGED (Prozent aus Rohwert)

                let goalMinutes = viewModel.sleepGoalMinutes
                let goalHours = Double(goalMinutes) / 60.0

                let goalString = goalHours.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f h", goalHours)
                    : String(format: "%.1f h", goalHours)

                ProgressView(value: ratio, total: 1.0)           // !!! CHANGED (Total = 1.0)
                    .tint(accent)

                Text("\(percent)% of \(goalString)")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Heart small tile

private struct HeartSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Aqua wie „Carbs“ – nur Icon/Text, nicht mehr Rahmenfarbe
    private let accent = Color.Glu.nutritionDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // HEADER (Icon + Titel) – exakt wie Sleep
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)

                    Text("Heart")
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()
            }

            // MITTLERER BLOCK (Wert + Beschreibung) – analog Sleep
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.restingHeartRateBpm) bpm")
                    .font(.title3.bold())
                    .foregroundColor(Color.Glu.primaryBlue)

                Text("Resting heart rate")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
            }

            // UNTERER BLOCK – Progress „blind“ + Textzeile
            // → gleiche vertikale Höhe wie bei Sleep
            VStack(alignment: .leading, spacing: 4) {

                // Unsichtbare ProgressBar nur für das Layout,
                // damit der Abstand nach unten identisch zu Sleep ist.
                ProgressView(value: 0.5)
                    .tint(accent)
                    .opacity(0)   // 🔥 unsichtbar, aber gleiche Höhe wie bei Sleep

                Text("\(viewModel.hrvMs) ms · HRV today")
                    .font(.footnote)
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - BMI tile

private struct BMISmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Wieder Lime wie Protein/Sleep – nur Icon/Text
    private let accent = Color.Glu.metabolicDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.arms.open")
                        .foregroundColor(Color.Glu.nutritionDomain)

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
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    // !!! CHANGED: Rahmenfarbe vereinheitlicht auf Body-Domain
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}

// MARK: - Body fat tile

private struct BodyFatSmallCard: View {

    @ObservedObject var viewModel: BodyOverviewViewModel

    // Orange wie Fat / Body-Domain – nur Icon/Text
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
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                .overlay(
                    // !!! CHANGED: Rahmenfarbe vereinheitlicht auf Body-Domain
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.2)
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
                Text("Insight")
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
                    // !!! CHANGED: Rahmenfarbe vereinheitlicht auf Body-Domain
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.Glu.bodyDomain.opacity(0.55), lineWidth: 1.2)
                )
        )
    }
}
// MARK: - Mini bar chart for weight

private struct WeightMiniBarChart: View {

    let data: [WeightTrendPoint]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Weight", point.weightKg)
            )
        }
        .foregroundStyle(Color.Glu.bodyDomain)   // Body-Domain-Farbe
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
    }
}

// MARK: - Preview

#Preview("BodyOverviewView") {
    BodyOverviewView(viewModel: BodyOverviewViewModel.preview)
        .environmentObject(AppState())
}
