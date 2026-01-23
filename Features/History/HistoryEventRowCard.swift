//
//  HistoryEventRowCard.swift
//  GluVibProbe
//
//  HISTORY — Generic Tile Card (Design V1)
//
//  ✅ This file contains ONLY the tappable card (Tile).
//  ✅ Chevron is NOT part of this card anymore (it lives in the row wrapper).
//
//  Rules:
//  - Entire card is tappable -> Metric detail (caller handles navigation)
//  - Domain-colored outline (with Metabolic overrides for Bolus/Basal like MainChart)
//  - Icon left (per metric)
//  - All text uses Glu Primary Blue (opacity for hierarchy)
//  - Tight vertical spacing (no wasted space)
//  - Glucose row: optional, max 3 markers (S/+30/+60 or S/E+30/E+60)
//  - Card frame MUST use GluVibCardStyle (SSoT) via .gluVibCardFrame(domainColor:)
//

import SwiftUI

// MARK: - Model (read-only input for the card)

struct HistoryEventRowCardModel: Identifiable, Hashable {

    // MARK: Domain

    enum Domain: Hashable {
        case activity
        case nutrition
        case metabolic
        case body

        fileprivate var baseOutlineColor: Color {
            switch self {
            case .activity:  return Color.Glu.activityDomain
            case .nutrition: return Color.Glu.nutritionDomain
            case .metabolic: return Color.Glu.metabolicDomain
            case .body:      return Color.Glu.bodyDomain
            }
        }
    }

    // MARK: Metabolic Metric Style (MainChart-aligned)

    enum MetabolicMetricStyle: Hashable {
        case none
        case bolus
        case basal

        fileprivate var outlineColor: Color? {
            switch self {
            case .none:  return nil
            case .bolus: return Color("acidBolusDarkGreen")
            case .basal: return Color("GluBasalMagenta").opacity(0.5)
            }
        }

        fileprivate var iconColor: Color? {
            switch self {
            case .none:  return nil
            case .bolus: return Color("acidBolusDarkGreen")
            case .basal: return Color("GluBasalMagenta").opacity(0.5)
            }
        }

        fileprivate static func infer(from titleText: String) -> MetabolicMetricStyle {
            switch titleText {
            case "Bolus": return .bolus
            case "Basal": return .basal
            default:      return .none
            }
        }
    }

    // MARK: Glucose Marker

    enum GlucoseMarkerKind: Hashable {
        case start
        case plus30
        case plus60
        case plus30AfterEnd
        case plus60AfterEnd
        case noData

        var label: String {
            switch self {
            case .start: return "S"
            case .plus30: return "+30"
            case .plus60: return "+60"
            case .plus30AfterEnd: return "E+30"
            case .plus60AfterEnd: return "E+60"
            case .noData: return ""
            }
        }
    }

    struct GlucoseMarker: Identifiable, Hashable {
        let id: UUID = UUID()
        let kind: GlucoseMarkerKind
        let valueText: String
    }

    // MARK: Identity

    let id: UUID = UUID()

    // MARK: Content

    let domain: Domain
    let titleText: String
    let detailText: String
    let timeText: String
    let glucoseMarkers: [GlucoseMarker]
    let contextHint: String?

    // ✅ NEW: optional dynamic label for glucose row ("Glucose (mg/dL)" / "Glucose (mmol/L)")
    let glucoseRowTitleText: String?          // !!! NEW

    // MARK: Derived Styling (ONE place)

    private let metabolicStyle: MetabolicMetricStyle

    var outlineColor: Color {
        if domain == .metabolic, let c = metabolicStyle.outlineColor {
            return c
        }
        return domain.baseOutlineColor
    }

    // MARK: Icon (ONE place)

    fileprivate enum LeadingIconKind: Hashable {
        case workout(symbol: String)
        case carbs
        case bolus
        case basal
        case weight
        case none
    }

    fileprivate var leadingIcon: LeadingIconKind {
        switch domain {
        case .activity:
            return .workout(symbol: WorkoutBadgeHelper.symbolName(for: titleText))
        case .nutrition:
            if titleText == "Carbs" { return .carbs }
            return .none
        case .metabolic:
            switch metabolicStyle {
            case .bolus: return .bolus
            case .basal: return .basal
            case .none:  return .none
            }
        case .body:
            if titleText == "Weight" { return .weight }
            return .none
        }
    }

    fileprivate var leadingIconColor: Color {
        switch leadingIcon {
        case .bolus, .basal:
            return metabolicStyle.iconColor ?? outlineColor
        case .carbs, .workout, .weight:
            return outlineColor
        default:
            return outlineColor
        }
    }

    // MARK: Init (keeps old call-sites stable)

    init(
        domain: Domain,
        titleText: String,
        detailText: String,
        timeText: String,
        glucoseMarkers: [GlucoseMarker],
        contextHint: String?,
        glucoseRowTitleText: String? = nil      // !!! NEW (default keeps old call-sites stable)
    ) {
        self.domain = domain
        self.titleText = titleText
        self.detailText = detailText
        self.timeText = timeText
        self.glucoseMarkers = glucoseMarkers
        self.contextHint = contextHint
        self.glucoseRowTitleText = glucoseRowTitleText    // !!! NEW

        if domain == .metabolic {
            self.metabolicStyle = .infer(from: titleText)
        } else {
            self.metabolicStyle = .none
        }
    }
}

// MARK: - Card

struct HistoryEventRowCard: View {

    let model: HistoryEventRowCardModel
    let onTapTile: () -> Void

    private var primaryBlue: Color { Color.Glu.primaryBlue }
    private var primaryBlueSecondary: Color { Color.Glu.primaryBlue.opacity(0.70) }
    private var primaryBlueTertiary: Color { Color.Glu.primaryBlue.opacity(0.55) }

    var body: some View {
        Button(action: onTapTile) {
            VStack(alignment: .leading, spacing: 6) {

                HStack(alignment: .firstTextBaseline, spacing: 10) {

                    LeadingIcon(model: model)

                    Text(model.titleText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryBlue)

                    Spacer(minLength: 8)

                    Text(model.timeText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryBlueSecondary)
                }

                HistoryDetailText(
                    text: model.detailText,
                    valueColor: primaryBlue.opacity(0.95),
                    unitColor: primaryBlueSecondary
                )
                .lineLimit(1)
                .allowsTightening(true)

                if let hint = model.contextHint, !hint.isEmpty {
                    Text(hint)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(primaryBlueTertiary)
                        .lineLimit(1)
                        .padding(.top, 1)
                }

                if !model.glucoseMarkers.isEmpty {
                    HistoryEventGlucoseRow(
                        title: model.glucoseRowTitleText ?? "Glucose",   // !!! UPDATED
                        markers: model.glucoseMarkers,
                        accent: model.outlineColor
                    )
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .gluVibCardFrame(domainColor: model.outlineColor)
    }
}

// MARK: - Detail Text (value emphasized)

private struct HistoryDetailText: View {

    let text: String
    let valueColor: Color
    let unitColor: Color

    var body: some View {
        if let parts = splitLeadingNumberAndRest(text) {
            Text(parts.value)
                .font(.headline.weight(.bold))
                .foregroundStyle(valueColor)
            + Text(" " + parts.rest)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(unitColor)
        } else {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(unitColor)
        }
    }

    private func splitLeadingNumberAndRest(_ s: String) -> (value: String, rest: String)? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let spaceIdx = trimmed.firstIndex(where: { $0.isWhitespace }) else { return nil }

        let value = String(trimmed[..<spaceIdx])
        let rest = String(trimmed[spaceIdx...]).trimmingCharacters(in: .whitespaces)

        guard !value.isEmpty, !rest.isEmpty else { return nil }

        guard let first = value.first, (first.isNumber || first == "-" || first == "+") else { return nil }

        let allowed: Set<Character> = Set("0123456789.,+-")
        guard value.allSatisfy({ allowed.contains($0) }) else { return nil }

        return (value, rest)
    }
}

// MARK: - Leading Icon

private struct LeadingIcon: View {

    let model: HistoryEventRowCardModel

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(model.leadingIconColor)
            .frame(width: 18, alignment: .leading)
    }

    private var symbolName: String {
        switch model.leadingIcon {
        case .workout(let symbol): return symbol
        case .carbs:               return "fork.knife"
        case .bolus:               return "drop.fill"
        case .basal:               return "drop.fill"
        case .weight:              return "scalemass.fill"
        case .none:                return "circle.fill"
        }
    }
}

// MARK: - Glucose Row

private struct HistoryEventGlucoseRow: View {

    let title: String
    let markers: [HistoryEventRowCardModel.GlucoseMarker]
    let accent: Color

    private var primaryBlueSecondary: Color { Color.Glu.primaryBlue.opacity(0.70) }
    private var primaryBlue: Color { Color.Glu.primaryBlue }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryBlueSecondary)

            HStack(spacing: 6) {
                ForEach(markers.prefix(3)) { m in
                    glucoseChip(label: m.kind.label, valueText: m.valueText, accent: accent)
                }
            }
        }
    }

    private func glucoseChip(label: String, valueText: String, accent: Color) -> some View {
        HStack(spacing: label.isEmpty ? 0 : 6) {                    // ✅ UPDATED

            if !label.isEmpty {                                     // ✅ UPDATED
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(primaryBlueSecondary)
            }

            Text(valueText)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(primaryBlue.opacity(0.95))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(accent.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(accent.opacity(0.55), lineWidth: 0.8)
        )
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {

        HistoryEventRowCard(
            model: .init(
                domain: .activity,
                titleText: "Outdoor Walk",
                detailText: "42 min · 380 kcal · 18.2 km",
                timeText: "18:10",
                glucoseMarkers: [
                    .init(kind: .start, valueText: "128"),
                    .init(kind: .plus30AfterEnd, valueText: "112"),
                    .init(kind: .plus60AfterEnd, valueText: "104")
                ],
                contextHint: nil,
                glucoseRowTitleText: "Glucose (mg/dL)"
            ),
            onTapTile: {}
        )

        // ✅ NEW: No-data marker preview
        HistoryEventRowCard(
            model: .init(
                domain: .metabolic,
                titleText: "Bolus",
                detailText: "4.0 U",
                timeText: "02:10",
                glucoseMarkers: [
                    .init(kind: .noData, valueText: "No CGM data")
                ],
                contextHint: nil,
                glucoseRowTitleText: "Glucose (mg/dL)"
            ),
            onTapTile: {}
        )
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
