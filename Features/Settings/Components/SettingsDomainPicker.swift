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

    // Standardzeilen → so muss man in SettingsView nichts extra übergeben
    let firstRow: [SettingsDomain] = [.body, .activity, .nutrition, .metabolic]
    let secondRow: [SettingsDomain] = [.units]

    @Binding var selectedDomain: SettingsDomain

    var body: some View {
        VStack(spacing: 8) {
            domainRow(firstRow)
            domainRow(secondRow)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 0)
    }

    // MARK: - Rows

    private func domainRow(_ domains: [SettingsDomain]) -> some View {
        HStack(spacing: 10) {
            ForEach(domains, id: \.self) { domain in
                domainButton(for: domain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Buttons

    private func domainButton(for domain: SettingsDomain) -> some View {
        let isSelected = (domain == selectedDomain)

        return Button {
            selectedDomain = domain
        } label: {
            Text(domain.title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(domain.color.opacity(isSelected ? 0.15 : 0.0))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            domain.color.opacity(isSelected ? 1.0 : 0.6),
                            lineWidth: isSelected ? 1.5 : 1.0
                        )
                )
                .foregroundColor(Color.Glu.primaryBlue)
        }
    }
}

// MARK: - Preview (sauber & warning-free)

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
