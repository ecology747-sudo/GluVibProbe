//
//  ActivitySettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: ACTIVITY – Targets wie Daily Step Goal
///
/// - Nutzt die Domain-Farbe: Color.Glu.activityAccent
/// - Zeigt nur den Activity-Bereich (Daily Step Target)
/// - Optik wie eine Domain-Kachel (ähnlich BodySettingsSection)
struct ActivitySettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var dailyStepTarget: Int

    // MARK: - Sheet Flag

    @State private var showStepTargetSheet: Bool = false

    // MARK: - Formatter

    private func stepLabel(for steps: Int) -> String {
        "\(steps) steps"
    }

    // MARK: - GluVibe Done-Button (gleicher Stil wie BodySettingsSection)

    private func doneButton(_ title: String, action: @escaping () -> Void) -> some View {
        let color = Color.Glu.primaryBlue

        return Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 22)
                .background(Capsule().fill(color.opacity(0.15)))
                .overlay(
                    Capsule().stroke(color, lineWidth: 1)
                )
                .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body

    var body: some View {
        Section {
            ZStack {
                // Hintergrundkarte
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.activityAccent.opacity(0.06))

                // Rahmen in Activity-Farbe
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.activityAccent.opacity(0.7), lineWidth: 1)

                VStack(alignment: .leading, spacing: 16) {
                    dailyStepTargetRow
                }
                .padding(16)
            }
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    // MARK: - Rows

    /// Daily Step Target – einzeilig + Sheet (analog BodySettingsSection)
    private var dailyStepTargetRow: some View {
        Button {
            showStepTargetSheet = true
        } label: {
            HStack {
                Text("Daily Step Target")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(stepLabel(for: dailyStepTarget))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showStepTargetSheet) {
            stepTargetSheet
        }
    }

    // MARK: - Sheet

    private var stepTargetSheet: some View {
        VStack(spacing: 12) {
            Text("Daily Step Target")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)
                .padding(.top, 10)

            Picker("", selection: $dailyStepTarget) {
                ForEach(Array(stride(from: 1_000, through: 30_000, by: 500)), id: \.self) { steps in
                    Text(stepLabel(for: steps))
                        .font(.title3)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(steps)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 220)

            doneButton("Done") {
                showStepTargetSheet = false
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview("ActivitySettingsSection") {
    NavigationStack {
        Form {
            ActivitySettingsSection(dailyStepTarget: .constant(10_000))
        }
    }
}
