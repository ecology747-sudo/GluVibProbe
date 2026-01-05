//
//  BodySettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: BODY – Targets only (V1-konform)
///
/// ✅ Zeigt NUR:
/// - Target Weight
/// - Target Sleep
///
/// ⛔ REMOVED (V1 Regel): Gender, Birth Date, Body Height, Body Weight
/// - Keine Messwert-/Personaldaten-Eingaben mehr im Settings UI.
/// - Targets bleiben über SettingsModel als SSoT für Goals erhalten.
struct BodySettingsSection: View {

    // MARK: - Bindings aus SettingsView (Targets only)

    @Binding var targetWeightKg: Int
    @Binding var dailySleepGoalMinutes: Int

    // MARK: - Sheet Flags

    @State private var showTargetWeightSheet: Bool = false
    @State private var showTargetSleepSheet: Bool = false

    // MARK: - Formatter

    private func targetWeightLabel(for kg: Int) -> String {
        "\(kg) kg"   // Base Unit: kg (Display hier bewusst Base Unit)
    }

    private func sleepLabel(for minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    // MARK: - GluVibe Done-Button

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
            VStack(alignment: .leading, spacing: 16) {                                  // !!! UPDATED
                targetWeightRow
                targetSleepRow
            }
            .padding(16)
            // !!! UPDATED: Domain-tinted Innenfläche (konsistent zu Activity/Nutrition/Metabolic)
            .background(                                                               // !!! UPDATED
                RoundedRectangle(cornerRadius: GluVibCardStyle.cornerRadius, style: .continuous) // !!! UPDATED
                    .fill(Color.Glu.bodyAccent.opacity(0.06))                          // !!! UPDATED (was 0.20)
            )
            // !!! UPDATED: zentraler Card-Style (Stroke-Dicke + Highlight + Shadow)
            .gluVibCardFrame(domainColor: Color.Glu.bodyAccent)                        // !!! UPDATED
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    // MARK: - Rows

    private var targetWeightRow: some View {
        Button {
            showTargetWeightSheet = true
        } label: {
            HStack {
                Text("Target Weight")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(targetWeightLabel(for: targetWeightKg))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTargetWeightSheet) {
            VStack(spacing: 12) {
                Text("Target Weight")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(.top, 10)

                Picker("", selection: $targetWeightKg) {
                    ForEach(40...250, id: \.self) { kg in
                        Text(targetWeightLabel(for: kg))
                            .font(.title3)
                            .foregroundColor(Color.Glu.primaryBlue)
                            .tag(kg)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 220)

                doneButton("Done") {
                    showTargetWeightSheet = false
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .presentationDetents([.medium])
        }
    }

    private var targetSleepRow: some View {
        Button {
            showTargetSleepSheet = true
        } label: {
            HStack {
                Text("Target Sleep")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(sleepLabel(for: dailySleepGoalMinutes))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTargetSleepSheet) {
            VStack(spacing: 12) {
                Text("Target Sleep")
                    .font(.headline)
                    .foregroundColor(Color.Glu.primaryBlue)
                    .padding(.top, 10)

                Picker("", selection: $dailySleepGoalMinutes) {
                    ForEach(Array(stride(from: 300, through: 720, by: 15)), id: \.self) { minutes in
                        Text(sleepLabel(for: minutes))
                            .font(.title3)
                            .foregroundColor(Color.Glu.primaryBlue)
                            .tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 220)

                doneButton("Done") {
                    showTargetSleepSheet = false
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Preview

#Preview("BodySettingsSection – Targets only") {
    Form {
        BodySettingsSection(
            targetWeightKg: .constant(75),
            dailySleepGoalMinutes: .constant(8 * 60)
        )
    }
}
