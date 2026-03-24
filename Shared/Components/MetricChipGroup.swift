//
//  MetricChipGroup.swift
//  GluVibProbe
//

import SwiftUI

struct MetricChipGroup: View {

    // ============================================================
    // MARK: - Layout Strategy
    // ============================================================

    enum LayoutStyle {
        case automatic
        case bodyDomain
    }

    // ============================================================
    // MARK: - Inputs (Rows)
    // ============================================================

    private let row1: [String]
    private let row2: [String]

    let selected: String
    let accent: Color

    let onSelect: (String) -> Void

    // Premium gating hooks (UI-only)
    private let isLocked: (String) -> Bool
    private let onSelectLocked: (String) -> Void

    private let showsWarningBadge: (String) -> Bool

    // ============================================================
    // MARK: - Init (Default / Backwards compatible)
    // ============================================================

    init(
        metrics: [String],
        selected: String,
        accent: Color,
        onSelect: @escaping (String) -> Void,
        isLocked: @escaping (String) -> Bool = { _ in false },
        onSelectLocked: @escaping (String) -> Void = { _ in },
        showsWarningBadge: @escaping (String) -> Bool = { _ in false }
    ) {
        self.row1 = Array(metrics.prefix(2))
        self.row2 = Array(metrics.dropFirst(2))

        self.selected = selected
        self.accent = accent
        self.onSelect = onSelect

        self.isLocked = isLocked
        self.onSelectLocked = onSelectLocked
        self.showsWarningBadge = showsWarningBadge
    }

    // ============================================================
    // MARK: - Init (Domain style, keeps others unchanged)
    // ============================================================

    init(
        metrics: [String],
        layoutStyle: LayoutStyle,
        selected: String,
        accent: Color,
        onSelect: @escaping (String) -> Void,
        isLocked: @escaping (String) -> Bool = { _ in false },
        onSelectLocked: @escaping (String) -> Void = { _ in },
        showsWarningBadge: @escaping (String) -> Bool = { _ in false }
    ) {
        switch layoutStyle {
        case .automatic:
            self.row1 = Array(metrics.prefix(2))
            self.row2 = Array(metrics.dropFirst(2))

        case .bodyDomain:
            let preferredRow1 = [ // 🟨 UPDATED
                L10n.Weight.title,
                L10n.Sleep.title,
                L10n.BMI.title
            ]
            let preferredRow2 = [ // 🟨 UPDATED
                L10n.BodyFat.title,
                L10n.RestingHeartRate.title
            ]

            let set = Set(metrics)

            let r1 = preferredRow1.filter { set.contains($0) }
            let r2 = preferredRow2.filter { set.contains($0) }

            if r1.count == 3 && r2.count == 2 {
                self.row1 = r1
                self.row2 = r2
            } else {
                self.row1 = Array(metrics.prefix(2))
                self.row2 = Array(metrics.dropFirst(2))
            }
        }

        self.selected = selected
        self.accent = accent
        self.onSelect = onSelect

        self.isLocked = isLocked
        self.onSelectLocked = onSelectLocked
        self.showsWarningBadge = showsWarningBadge
    }

    // ============================================================
    // MARK: - Init (Explicit rows)
    // ============================================================

    init(
        row1: [String],
        row2: [String],
        selected: String,
        accent: Color,
        onSelect: @escaping (String) -> Void,
        isLocked: @escaping (String) -> Bool = { _ in false },
        onSelectLocked: @escaping (String) -> Void = { _ in },
        showsWarningBadge: @escaping (String) -> Bool = { _ in false }
    ) {
        self.row1 = row1
        self.row2 = row2
        self.selected = selected
        self.accent = accent
        self.onSelect = onSelect

        self.isLocked = isLocked
        self.onSelectLocked = onSelectLocked
        self.showsWarningBadge = showsWarningBadge
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                ForEach(row1, id: \.self) { metric in
                    chip(metric)
                }
                Spacer(minLength: 0)
            }

            if !row2.isEmpty {
                HStack(spacing: 6) {
                    ForEach(row2, id: \.self) { metric in
                        chip(metric)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // ============================================================
    // MARK: - Title Resolution
    // ============================================================

    private func resolvedMetricTitle(for metric: String) -> String {
        switch metric {

        // Activity
        case "Steps", L10n.Steps.title:
            return L10n.Steps.title
        case "Workout Minutes", L10n.WorkoutMinutes.title:
            return L10n.WorkoutMinutes.title
        case "Activity Energy", "Active Energy", L10n.ActivityEnergy.title:
            return L10n.ActivityEnergy.title
        case "Movement Split", L10n.MovementSplit.title:
            return L10n.MovementSplit.title

        // Body
        case "Weight", L10n.Weight.title: // 🟨 UPDATED
            return L10n.Weight.title
        case "Sleep", L10n.Sleep.title: // 🟨 UPDATED
            return L10n.Sleep.title
        case "BMI", L10n.BMI.title: // 🟨 UPDATED
            return L10n.BMI.title
        case "Body Fat", L10n.BodyFat.title: // 🟨 UPDATED
            return L10n.BodyFat.title
        case "Resting Heart Rate", "Resting HR", L10n.RestingHeartRate.title: // 🟨 UPDATED
            return L10n.RestingHeartRate.title

        // Nutrition
        case "Carbs", L10n.Carbs.title:
            return L10n.Carbs.title
        case "Carbs Split", L10n.CarbsDayparts.title:
            return L10n.CarbsDayparts.title
        case "Sugar", L10n.Sugar.title:
            return L10n.Sugar.title
        case "Protein", L10n.Protein.title:
            return L10n.Protein.title
        case "Fat", L10n.Fat.title:
            return L10n.Fat.title
        case "Calories", L10n.NutritionEnergy.title:
            return L10n.NutritionEnergy.title

        // Metabolic
        case "Bolus", L10n.Bolus.title:
            return L10n.Bolus.title
        case "Basal", L10n.Basal.title:
            return L10n.Basal.title
        case "Bolus/Basal", L10n.BolusBasalRatio.title:
            return L10n.BolusBasalRatio.title
        case "Carbs/Bolus", L10n.CarbsBolusRatio.title:
            return L10n.CarbsBolusRatio.title
        case "TIR", L10n.TimeInRange.title:
            return L10n.TimeInRange.title
        case "IG", L10n.IG.title:
            return L10n.IG.title
        case "GMI", L10n.GMI.title:
            return L10n.GMI.title
        case "SD", L10n.SD.title:
            return L10n.SD.title
        case "CV", L10n.CV.title:
            return L10n.CV.title
        case "Range", L10n.Range.title:
            return L10n.Range.title

        default:
            return metric
        }
    }

    private func normalizedComparisonValue(_ value: String) -> String {
        resolvedMetricTitle(for: value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ============================================================
    // MARK: - Chip
    // ============================================================

    private func chip(_ metric: String) -> some View {
        let resolvedTitle = resolvedMetricTitle(for: metric)
        let isActive = normalizedComparisonValue(metric) == normalizedComparisonValue(selected)
        let locked = isLocked(metric)

        let strokeColor: Color = isActive
            ? Color.white.opacity(0.90)
            : accent.opacity(0.90)

        let lineWidth: CGFloat = isActive ? 1.6 : 1.2

        let backgroundFill: some ShapeStyle = isActive
            ? LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        let shadowOpacity: Double = isActive ? 0.25 : 0.15
        let shadowRadius: CGFloat = isActive ? 4 : 2.5
        let shadowYOffset: CGFloat = isActive ? 2 : 1.5

        let showWarn = showsWarningBadge(metric)

        return Button {
            if locked {
                onSelectLocked(metric)
            } else {
                onSelect(metric)
            }
        } label: {

            ZStack(alignment: .topTrailing) {

                HStack(spacing: 6) {
                    Text(resolvedTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)

                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.75))
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 11)
                .background(
                    Capsule().fill(backgroundFill)
                )
                .overlay(
                    Capsule().stroke(strokeColor, lineWidth: lineWidth)
                )
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowYOffset
                )
                .foregroundStyle(
                    isActive ? Color.white : Color.Glu.primaryBlue.opacity(0.95)
                )
                .opacity(locked && !isActive ? 0.92 : 1.0)
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isActive)

                if showWarn {
                    warningBadgeView
                        .offset(x: 7, y: -7)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // ============================================================
    // MARK: - Badge
    // ============================================================

    private var warningBadgeView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.Glu.acidCGMRed, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 1.5, x: 0, y: 1)

            Image(systemName: "exclamationmark")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.Glu.acidCGMRed)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("MetricChipGroup") {
    VStack(spacing: 16) {

        MetricChipGroup(
            metrics: [
                "Steps",
                "Workout Minutes",
                "Activity Energy",
                "Movement Split"
            ],
            selected: L10n.ActivityEnergy.title,
            accent: Color.Glu.activityAccent,
            onSelect: { _ in },
            isLocked: { name in
                name != "Steps"
            },
            onSelectLocked: { _ in },
            showsWarningBadge: { metric in
                metric == "Workout Minutes"
            }
        )

        MetricChipGroup(
            metrics: [
                L10n.Weight.title,
                L10n.Sleep.title,
                L10n.BMI.title,
                L10n.BodyFat.title,
                L10n.RestingHeartRate.title
            ], // 🟨 UPDATED
            layoutStyle: .bodyDomain,
            selected: L10n.Weight.title, // 🟨 UPDATED
            accent: Color.Glu.bodyAccent,
            onSelect: { _ in },
            isLocked: { name in
                name != L10n.Weight.title
            },
            onSelectLocked: { _ in },
            showsWarningBadge: { metric in
                metric == L10n.Sleep.title
            }
        )

        MetricChipGroup(
            metrics: ["Carbs", "Carbs Split", "Sugar", "Protein", "Fat", "Calories"],
            selected: L10n.Carbs.title,
            accent: Color.Glu.nutritionDomain,
            onSelect: { _ in },
            isLocked: { name in
                name == "Fat" || name == "Calories"
            },
            onSelectLocked: { _ in },
            showsWarningBadge: { metric in
                metric == "Carbs" || metric == "Protein"
            }
        )

        MetricChipGroup(
            metrics: [
                L10n.Bolus.title,
                L10n.Basal.title,
                L10n.BolusBasalRatio.title,
                L10n.CarbsBolusRatio.title,
                L10n.TimeInRange.title,
                L10n.IG.title,
                L10n.GMI.title,
                L10n.SD.title,
                L10n.CV.title,
                L10n.Range.title
            ],
            selected: L10n.TimeInRange.title,
            accent: Color.Glu.metabolicDomain,
            onSelect: { _ in },
            isLocked: { _ in false },
            onSelectLocked: { _ in },
            showsWarningBadge: { metric in
                metric == L10n.Bolus.title
            }
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
