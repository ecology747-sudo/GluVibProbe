//
//  NutritionOverviewView.swift
//  GluVibProbe
//
//  Nutrition Overview (Landing Page der Nutrition-Domain)
//  - Sticky-Header (OverviewHeader) mit Titel & Datum
//  - Blur + Tint, sobald gescrollt wird
//  - Horizontaler Pager für 3 Tage (DayBefore, Yesterday, Today)
//  - Score-Chip unter dem Header
//  - Macro Target Bars
//  - Macro Distribution Pie
//  - Daily Energy Balance
//  - Insight Card
//

import SwiftUI
import Charts

// MARK: - Scroll Offset Preference
// Dient dazu, festzustellen, ob der ScrollView nach oben bewegt wurde.
// Damit steuern wir, ob der Header seinen Blur-Hintergrund aktiviert.
private struct NutritionScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct NutritionOverviewView: View {

    // MARK: - Environment
    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel
    @StateObject private var viewModel: NutritionOverviewViewModel

    // MARK: - State (für Sticky-Header-Background & Pager)

    /// Steuert, ob der Blur im Header aktiv ist
    @State private var hasScrolled: Bool = false

    /// Pager-Index:
    /// 0 = DayBefore (vorvorgestern)
    /// 1 = Yesterday (gestern)
    /// 2 = Today (heute)
    /// 👉 Start immer auf Today (= 2), damit du nach RECHTS "zurück" wischen kannst
    @State private var selectedPage: Int = 2   // MARK: - NEU

    // MARK: - Header-Konstante (Design-Reserve, aktuell nicht zwingend gebraucht)
    private let headerHeight: CGFloat = 60

    // MARK: - Init

    init(viewModel: NutritionOverviewViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: NutritionOverviewViewModel(
                    healthStore: HealthStore.shared,
                    settings: .shared,
                    weightViewModel: WeightViewModel(
                        healthStore: HealthStore.shared,
                        settings: .shared
                    )
                )
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            // MARK: Hintergrund in Nutrition-Farbwelt (bleibt unverändert)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.Glu.nutritionAccent.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // MARK: - ZStack: Pager-Inhalt unten, Header oben drüber (Overlay)
            ZStack(alignment: .top) {

                // MARK: - Horizontaler Pager (3 Tage)
                TabView(selection: $selectedPage) {

                    // 0 = DayBefore (2 Tage zurück)
                    dayScrollView
                        .tag(0)

                    // 1 = Yesterday (1 Tag zurück)
                    dayScrollView
                        .tag(1)

                    // 2 = Today (heute)
                    dayScrollView
                        .tag(2)
                }
                // 🔴 System-Dots deaktivieren, wir nutzen CustomPageDots
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Blur-Aktivierung anhand des Scroll-Offsets (von allen Seiten gesammelt)
                .onPreferenceChange(NutritionScrollOffsetKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasScrolled = offset < 0
                    }
                }
                // MARK: - REAKTION auf Pager-Wechsel → ViewModel-Tag setzen + reload
                .onChange(of: selectedPage) { newIndex in
                    let newOffset = dayOffset(for: newIndex)       // 🔥 NICHT mehr selectedDate setzen
                    viewModel.selectedDayOffset = newOffset
                    Task {
                        await viewModel.refresh()
                    }
                }
                .onAppear {
                    // Beim ersten Anzeigen: Pager-Index an aktuell gesetzten Offset anpassen
                    selectedPage = pageIndex(for: viewModel.selectedDayOffset)
                }

                // MARK: - HEADER (Overlay, nutzt OverviewHeader-Komponente)
                OverviewHeader(
                    title: "Nutrition Overview",
                    subtitle: headerSubtitle,                      // 🔥 dynamisches Datum
                    tintColor: Color.Glu.nutritionAccent,
                    hasScrolled: hasScrolled
                )

                // MARK: - Custom PageDots (Nutrition-Farbe, immer sichtbar)
                VStack {
                    Spacer()
                    PageDots(
                        selected: selectedPage,
                        total: 3,
                        color: Color.Glu.nutritionAccent
                    )
                    .padding(.bottom, 12)
                }
            }
        }
        .task {
            // Initial-Ladung für den aktuellen Tag
            await viewModel.refresh()
        }
        .onChange(of: appState.currentStatsScreen) { newScreen in   // !!! NEW
            // Wenn wir aus einer Detail-Metrik zurück in die Overview kommen,
            // Daten für den aktuell gewählten Tag neu laden
            if newScreen == .nutritionOverview || newScreen == .none {   // !!! NEW
                Task {                                                   // !!! NEW
                    await viewModel.refresh()                            // !!! NEW
                }                                                        // !!! NEW
            }                                                            // !!! NEW
        }
    }
}

// MARK: - Datum-Formatierung / Header-Untertitel

private extension NutritionOverviewView {

    /// Liefert den Text für den Header:
    /// - TODAY      für offset 0
    /// - YESTERDAY  für offset -1
    /// - Datum      für offset ≤ -2
    var headerSubtitle: String {
        switch viewModel.selectedDayOffset {
        case 0:
            return "TODAY"
        case -1:
            return "YESTERDAY"
        default:
            return dateString(for: viewModel.selectedDate)
        }
    }

    func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // ... dayOffset(for:) und pageIndex(for:) bleiben unverändert


    /// Mapping Pager-Index → DayOffset (in Tagen relativ zu heute)
    /// 0 = DayBefore (-2), 1 = Yesterday (-1), 2 = Today (0)
    func dayOffset(for pageIndex: Int) -> Int {
        switch pageIndex {
        case 0: return -2
        case 1: return -1
        default: return 0
        }
    }

    /// Mapping DayOffset → Pager-Index
    ///  0 → 2 (Today)
    /// -1 → 1 (Yesterday)
    /// -2 → 0 (DayBefore)
    func pageIndex(for offset: Int) -> Int {
        switch offset {
        case -2: return 0
        case -1: return 1
        default: return 2
        }
    }
}

// MARK: - Tages-ScrollView (eine "Maske" für alle 3 Tage)

private extension NutritionOverviewView {

    /// Diese ScrollView wird für alle 3 Pager-Seiten wiederverwendet.
    /// Die Inhalte (Zahlen) ändern sich nur, weil das ViewModel andere Tagesdaten lädt.
    var dayScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Offset-Messung GLOBAL
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: NutritionScrollOffsetKey.self,
                            value: geo.frame(in: .global).minY   // globaler Offset
                        )
                }
                .frame(height: 0)

                // 1) SCORE-SECTION (Nutrition-spezifisch, bleibt im Inhalt!)
                scoreSection

                // 2) MACRO TARGET BARS
                macroTargetsSection

                // 3) MACRO DISTRIBUTION PIE
                macroDistributionSection

                // 4) DAILY ENERGY BALANCE
                energyRingSection

                // 5) INSIGHT CARD
                insightSection
            }
            // WICHTIG: Platz nach oben, damit der Inhalt UNTER dem Header startet
            .padding(.top, 30)
            .padding(.horizontal, 16)
            .padding(.bottom, 60)   // etwas mehr Platz für CustomPageDots
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Score-Section (Score-Chip unter dem Header)

private extension NutritionOverviewView {

    /// Zeigt nur den Score-Chip, nutzt weiterhin viewModel.nutritionScore
    var scoreSection: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Text("Nutrition Score")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))

                Text("\(viewModel.nutritionScore)")
                    .font(.caption.weight(.bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        viewModel.scoreColor.opacity(0.9),
                                        viewModel.scoreColor.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundStyle(Color.white)
            }
        }
    }
}

// MARK: - 2) Macro Target Bars (unter Score, vollbreit)

private extension NutritionOverviewView {

    var macroTargetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 10) {
                macroTargetRow(
                    label: "Carbs",
                    todayValue: viewModel.todayCarbsGrams,
                    targetValue: viewModel.targetCarbsGrams,
                    percentOfGoal: viewModel.carbsGoalPercent,
                    color: Color.Glu.nutritionDomain
                ) {
                    appState.currentStatsScreen = .carbs
                }

                macroTargetRow(
                    label: "Protein",
                    todayValue: viewModel.todayProteinGrams,
                    targetValue: viewModel.targetProteinGrams,
                    percentOfGoal: viewModel.proteinGoalPercent,
                    color: Color.Glu.metabolicDomain
                ) {
                    appState.currentStatsScreen = .protein
                }

                macroTargetRow(
                    label: "Fat",
                    todayValue: viewModel.todayFatGrams,
                    targetValue: viewModel.targetFatGrams,
                    percentOfGoal: viewModel.fatGoalPercent,
                    color: Color.Glu.bodyDomain
                ) {
                    appState.currentStatsScreen = .fat
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.nutritionDomain.opacity(0.80), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        )
    }

    func macroTargetRow(
        label: String,
        todayValue: Int,
        targetValue: Int,
        percentOfGoal: Int,
        color: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {

            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer()

                let todayText  = "\(todayValue) g"
                let targetText = targetValue > 0 ? "\(targetValue) g" : "–"

                Text("\(todayText) / \(targetText)  (\(percentOfGoal)%)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.8))
            }

            ZStack(alignment: .leading) {
                // Hintergrund-Balken (100 % Ziel)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.Glu.primaryBlue.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.Glu.primaryBlue.opacity(0.20), lineWidth: 0.6)
                    )

                GeometryReader { geo in
                    let width = geo.size.width
                    let ratio = min(max(CGFloat(percentOfGoal) / 100.0, 0), 1.0)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.90),
                                    color.opacity(0.70)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.Glu.primaryBlue.opacity(0.35), lineWidth: 0.5)
                        )
                        .frame(width: width * ratio)
                }
            }
            .frame(height: 12)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }
}

// MARK: - 3) Macro Distribution Pie (Makro-Verteilung)

private extension NutritionOverviewView {

    var macroDistributionSection: some View {
        HStack(spacing: 12) {

            // PIE-CHART – Tap auf Diagramm → CARBS-Metrik
            if #available(iOS 17.0, *) {
                Chart {
                    if viewModel.todayCarbsGrams > 0 {
                        SectorMark(
                            angle: .value("Carbs", viewModel.carbsShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.nutritionDomain)
                    }
                    if viewModel.todayProteinGrams > 0 {
                        SectorMark(
                            angle: .value("Protein", viewModel.proteinShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.metabolicDomain)
                    }
                    if viewModel.todayFatGrams > 0 {
                        SectorMark(
                            angle: .value("Fat", viewModel.fatShare),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.Glu.bodyDomain)
                    }
                }
                .chartLegend(.hidden)
                .frame(width: 110, height: 110)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentStatsScreen = .carbs
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                    Text("iOS 17 Pie only")
                        .font(.caption2)
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.6))
                }
                .frame(width: 110, height: 110)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentStatsScreen = .carbs
                }
            }

            // LEGEND + TAP-NAVIGATION
            VStack(alignment: .leading, spacing: 8) {

                macroLegendRow(
                    label: "Carbs",
                    grams: viewModel.todayCarbsGrams,
                    share: viewModel.carbsShare,
                    color: Color.Glu.nutritionDomain
                ) {
                    appState.currentStatsScreen = .carbs
                }

                macroLegendRow(
                    label: "Protein",
                    grams: viewModel.todayProteinGrams,
                    share: viewModel.proteinShare,
                    color: Color.Glu.metabolicDomain
                ) {
                    appState.currentStatsScreen = .protein
                }

                macroLegendRow(
                    label: "Fat",
                    grams: viewModel.todayFatGrams,
                    share: viewModel.fatShare,
                    color: Color.Glu.bodyDomain
                ) {
                    appState.currentStatsScreen = .fat
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.nutritionDomain.opacity(0.80), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        )
    }

    func macroLegendRow(
        label: String,
        grams: Int,
        share: Double,
        color: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        let percentage = Int((share * 100).rounded())

        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Spacer()

            Text("\(grams) g (\(percentage)%)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - 4) Daily Energy Balance

private extension NutritionOverviewView {

    var energyRingSection: some View {
        VStack(spacing: 12) {

            HStack(alignment: .center, spacing: 16) {

                // Ring links – gleiche Größe wie Pie (110x110)
                ZStack {
                    let ringColor: Color = viewModel.isEnergyRemaining
                        ? Color.Glu.nutritionDomain
                        : .red

                    // Hintergrund-Ring
                    Circle()
                        .stroke(
                            ringColor.opacity(0.22),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )

                    // Fortschritts-Ring
                    Circle()
                        .trim(from: 0, to: viewModel.energyProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    ringColor.opacity(0.95),
                                    ringColor.opacity(0.55),
                                    ringColor.opacity(0.95)
                                ]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: viewModel.energyProgress)

                    // 🔹 Neue Beschriftung im Ring:
                    //    "490 kcal"
                    //    "Remaining" / "Over" darunter
                    VStack(spacing: 2) {
                        Text("\(viewModel.formattedEnergyBalanceValue) kcal")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(
                                viewModel.isEnergyRemaining ? .green : .red
                            )

                        let label = viewModel.energyBalanceLabelText
                            .replacingOccurrences(of: "kcal ", with: "")
                            .capitalized   // "remaining" -> "Remaining"

                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(
                                viewModel.isEnergyRemaining
                                ? .green.opacity(0.9)
                                : .red.opacity(0.9)
                            )
                    }
                }
                .frame(width: 110, height: 110)

                // 🔹 Rechte Seite: Burned & Intake-Kacheln
                VStack(spacing: 10) {

                    // MARK: Burned-Card (Active + Resting)
                    VStack(alignment: .leading, spacing: 8) {

                        // Label-Capsule "Burned"
                        HStack {
                            Text("Burned")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.98))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.Glu.nutritionDomain, lineWidth: 0.6)                                        )
                                )

                            Spacer()
                        }

                        // Gesamt-Burned (Active + Resting)
                        let totalBurned = viewModel.todayActiveEnergyKcal + viewModel.restingEnergyKcal

                        Text("\(totalBurned.formatted(.number.grouping(.automatic))) kcal")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.Glu.primaryBlue)

                        // Detailzeilen: Active / Resting
                        HStack {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))

                            Spacer()

                            Text(viewModel.formattedActiveEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }

                        HStack {
                            Text("Resting")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))

                            Spacer()

                            Text(viewModel.formattedRestingEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        Color.Glu.nutritionDomain.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.Glu.nutritionDomain.opacity(0.9), lineWidth: 0.6)
                            )
                    )

                    // MARK: Intake-Card (Nutrition)
                    VStack(alignment: .leading, spacing: 8) {

                        // Label-Capsule "Intake"
                        HStack {
                            Text("Intake")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.Glu.nutritionDomain, lineWidth: 0.6)
                                        )
                                )

                            Spacer()
                        }

                        Text(viewModel.formattedNutritionEnergyKcal)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.Glu.primaryBlue)

                        HStack {
                            Text("Nutrition")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))

                            Spacer()

                            Text(viewModel.formattedNutritionEnergyKcal)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.95))
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(.systemGray6),
                                        Color.Glu.nutritionDomain.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.Glu.nutritionDomain.opacity(0.9), lineWidth: 0.6)                            )
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.nutritionDomain.opacity(0.80), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Ganze Kachel → Nutrition-Energy-Metrik
            appState.currentStatsScreen = .calories
        }
    }
}

private func energyRow(label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(.subheadline.weight(.semibold))   // wie Macro-Legende
            .foregroundStyle(Color.Glu.primaryBlue)

        Spacer()

        Text(value)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.Glu.primaryBlue)
    }
}


// MARK: - 5) Insight Card

private extension NutritionOverviewView {

    var insightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insight")
                .font(.headline)
                .foregroundStyle(Color.Glu.primaryBlue)

            Text(viewModel.insightText.isEmpty
                 ? "No nutrition data recorded yet today."
                 : viewModel.insightText
            )
            .font(.subheadline)
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.nutritionDomain.opacity(0.80), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        )
    }
}

// MARK: - Custom PageDots (wie in BodyOverview)

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

// MARK: - Preview

#Preview("NutritionOverviewView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()

    let previewVM = NutritionOverviewViewModel(
        healthStore: previewStore,
        settings: .shared,
        weightViewModel: WeightViewModel(
            healthStore: previewStore,
            settings: .shared
        )
    )

    NutritionOverviewView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
