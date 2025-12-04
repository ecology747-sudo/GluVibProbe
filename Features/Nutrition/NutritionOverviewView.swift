//
//  NutritionOverviewView.swift
//  GluVibProbe
//
//  Nutrition Overview (Landing Page der Nutrition-Domain)
//  - Header mit Titel, Datum & Nutrition Score
//  - Macro Target Bars (Carbs / Protein / Fat) – direkt unter dem Header
//  - Macro Distribution Pie (Makro-Verteilung des heutigen Intakes)
//  - Daily Energy Balance (Ring + Active/Resting/Nutrition)
//  - Insight Card
//

import SwiftUI
import Charts

struct NutritionOverviewView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel

    @StateObject private var viewModel: NutritionOverviewViewModel

    // MARK: - Init

    init(viewModel: NutritionOverviewViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(
                wrappedValue: NutritionOverviewViewModel(
                    healthStore: HealthStore.shared,
                    settings: .shared
                )
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Hintergrund in Nutrition-Farbwelt
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.Glu.nutritionAccent.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // 1) HEADER (Title + Date + Score)
                    headerSection

                    // 2) MACRO TARGET BARS (vollbreit, direkt unter Header)
                    macroTargetsSection

                    // 3) MACRO DISTRIBUTION PIE (Makro-Verteilung)
                    macroDistributionSection

                    // 4) DAILY ENERGY BALANCE
                    energyRingSection

                    // 5) INSIGHT CARD
                    insightSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - 1) Header

private extension NutritionOverviewView {

    var headerSection: some View {
        VStack(spacing: 8) {

            // Titel zentriert
            Text("Nutrition Overview")
                .font(.title2.bold())
                .foregroundStyle(Color.Glu.primaryBlue)
                .frame(maxWidth: .infinity, alignment: .center)

            // Unterzeile mit Datum (links) & Nutrition Score (rechts)
            HStack {
                Text("Today · \(todayString)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))

                Spacer()

                HStack(spacing: 6) {
                    Text("Score")
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
                                            Color.Glu.nutritionDomain.opacity(0.9),
                                            Color.Glu.nutritionDomain.opacity(0.6)
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

    var todayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}

// MARK: - 2) Macro Target Bars (unter Header, vollbreit)

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

                let todayText  = todayValue > 0 ? "\(todayValue) g" : "0 g"
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
                    // Balken max. 100 % Breite – schießt nicht mehr rechts heraus
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
        HStack(spacing: 16) {

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
                .frame(width: 130, height: 130)
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
                .frame(width: 130, height: 130)
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

            // 👉 Identisch wie Energy-Kachel: Label = semibold
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Spacer()

            // 👉 Werte = bold, wie in Energy-Kachel
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

                // Ring links – gleiche Größe wie Pie (130x130)
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

                    // Nur Zahl + "kcal remaining/over"
                    VStack(spacing: 4) {
                        Text(viewModel.formattedEnergyBalanceValue)
                            .font(.headline.weight(.bold))
                            .foregroundColor(
                                viewModel.isEnergyRemaining ? .green : .red
                            )

                        Text(viewModel.energyBalanceLabelText)
                            .font(.caption2)
                            .foregroundColor(
                                viewModel.isEnergyRemaining
                                ? .green.opacity(0.9)
                                : .red.opacity(0.9)
                            )
                    }
                }
                .frame(width: 130, height: 130)

                // Werte rechts vom Ring – gleiche Font wie Macro-Legende
                VStack(alignment: .leading, spacing: 6) {

                    energyRow(label: "Active",
                              value: viewModel.formattedActiveEnergyKcal)

                    energyRow(label: "Resting",
                              value: viewModel.formattedRestingEnergyKcal)

                    energyRow(label: "Nutrition",
                              value: viewModel.formattedNutritionEnergyKcal)
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
        .frame(maxWidth: .infinity, alignment: .leading)   // ⬅️ WICHTIG
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

// MARK: - Preview

#Preview("NutritionOverviewView") {
    let previewStore = HealthStore.preview()
    let previewState = AppState()
    let previewVM   = NutritionOverviewViewModel(
        healthStore: previewStore,
        settings: .shared
    )

    return NutritionOverviewView(viewModel: previewVM)
        .environmentObject(previewStore)
        .environmentObject(previewState)
}
