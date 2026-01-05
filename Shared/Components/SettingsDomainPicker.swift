//
//  SettingsDomainPicker.swift
//  GluVibProbe
//

import SwiftUI

// MARK: - Domain Enum

enum SettingsDomain: CaseIterable {
    case body
    case activity
    case metabolic
    case nutrition
    case units

    var title: String {
        switch self {
        case .body:      return "Body"
        case .activity:  return "Activity"
        case .metabolic: return "Metabolic"
        case .nutrition: return "Nutrition"
        case .units:     return "Units"
        }
    }

    var color: Color {
        switch self {
        case .body:      return Color.Glu.bodyAccent
        case .activity:  return Color.Glu.activityAccent
        case .metabolic: return Color.Glu.accentLime
        case .nutrition: return Color.Glu.nutritionAccent
        case .units:     return Color.Glu.primaryBlue
        }
    }
}

// MARK: - Picker Component

struct SettingsDomainPicker: View {

    // !!! UPDATED: Metabolic in zweite Reihe, damit Reihe 1 nicht quetscht
    let firstRow: [SettingsDomain] = [.body, .activity, .nutrition]          // !!! UPDATED
    let secondRow: [SettingsDomain] = [.metabolic, .units]                   // !!! UPDATED

    @Binding var selectedDomain: SettingsDomain

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                ForEach(firstRow, id: \.self) { domain in
                    chip(domain)
                }
            }

            HStack(spacing: 6) {
                ForEach(secondRow, id: \.self) { domain in
                    chip(domain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 0)
    }

    // MARK: - Chip (1:1 MetricChipGroup Style, aber ohne Text-Shrink)

    private func chip(_ domain: SettingsDomain) -> some View {
        let isActive = (domain == selectedDomain)

        let strokeColor: Color = isActive
            ? Color.white.opacity(0.90)
            : domain.color.opacity(0.90)

        let lineWidth: CGFloat = isActive ? 1.6 : 1.2

        let backgroundFill: some ShapeStyle = isActive
            ? LinearGradient(
                colors: [domain.color.opacity(0.95), domain.color.opacity(0.75)],
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

        return Button {
            selectedDomain = domain
        } label: {
            Text(domain.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                // !!! UPDATED: keine automatische Schriftverkleinerung mehr
                // .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .fixedSize(horizontal: true, vertical: false) // !!! NEW: hält Text stabil
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
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
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview (minimal, realistisch)

#Preview("SettingsDomainPicker") {
    SettingsDomainPickerPreview()
}

struct SettingsDomainPickerPreview: View {
    @State private var selected: SettingsDomain = .body

    var body: some View {
        SettingsDomainPicker(selectedDomain: $selected)
            .padding()
    }
}
