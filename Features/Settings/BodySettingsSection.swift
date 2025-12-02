//
//  BodySettingsSection.swift
//  GluVibProbe
//

import SwiftUI

/// Domain: BODY – Personal & Körperdaten
///
/// - Sheets für: Birth Date, Body Height, Body Weight, Target Weight, Target Sleep
/// - Inline bleibt nur: Gender (Segmented)
struct BodySettingsSection: View {

    // MARK: - Bindings aus SettingsView

    @Binding var gender: String
    @Binding var birthDate: Date
    @Binding var heightCm: Int
    @Binding var weightKg: Int
    @Binding var targetWeightKg: Int
    @Binding var dailySleepGoalMinutes: Int

    let heightUnit: HeightUnit
    let weightUnit: WeightUnit

    // MARK: - Sheet Flags

    @State private var showBirthDateSheet: Bool = false
    @State private var showHeightSheet: Bool = false
    @State private var showWeightSheet: Bool = false
    @State private var showTargetWeightSheet: Bool = false
    @State private var showTargetSleepSheet: Bool = false

    // MARK: - Date Range

    private var birthDateRange: ClosedRange<Date> {
        let cal = Calendar.current
        var c = DateComponents()
        c.year = 1920
        c.month = 1
        c.day = 1
        let start = cal.date(from: c) ?? Date.distantPast
        return start...Date()
    }

    // MARK: - Formatter

    private func heightLabel(for cm: Int) -> String {
        switch heightUnit {
        case .cm:
            return "\(cm) cm"
        case .feetInches:
            let inches = Int((Double(cm) / 2.54).rounded())
            let ft = inches / 12
            let inc = inches % 12
            return "\(ft) ft \(inc) in"
        }
    }

    private func weightLabel(for kg: Int) -> String {
        switch weightUnit {
        case .kg:
            return "\(kg) kg"
        case .lbs:
            let lbs = Int(Double(kg) * 2.20462)
            return "\(lbs) lbs"
        }
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
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Glu.bodyAccent.opacity(0.20))

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Glu.bodyAccent.opacity(0.7), lineWidth: 1)

                VStack(alignment: .leading, spacing: 16) {
                    genderRow
                    birthDateRow
                    heightRow
                    weightRow
                    targetWeightRow
                    targetSleepRow
                }
                .padding(16)
            }
            .padding(.horizontal, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    // MARK: - Rows (Reihenfolge wie im UI)

    private var genderRow: some View {
        HStack {
            Text("Gender")
                .font(.subheadline)
                .foregroundColor(Color.Glu.primaryBlue)

            Spacer()

            Picker("", selection: $gender) {
                Text("Male")
                    .foregroundColor(Color.Glu.primaryBlue)
                    .tag("Male")

                Text("Female")
                    .foregroundColor(Color.Glu.primaryBlue)
                    .tag("Female")

                Text("Other")
                    .foregroundColor(Color.Glu.primaryBlue)
                    .tag("Other")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(.vertical, 4)
    }

    // 🔹 Birth Date – einzeilig + Sheet
    private var birthDateRow: some View {
        Button { showBirthDateSheet = true } label: {
            HStack {
                Text("Birth Date")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(birthDate.formatted(date: .numeric, time: .omitted))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "calendar")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBirthDateSheet) {
            birthDateSheet
        }
    }

    // 🔹 Body Height – einzeilig + Sheet
    private var heightRow: some View {
        Button { showHeightSheet = true } label: {
            HStack {
                Text("Body Height")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(heightLabel(for: heightCm))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showHeightSheet) {
            heightSheet
        }
    }

    // 🔹 Body Weight – einzeilig + Sheet
    private var weightRow: some View {
        Button { showWeightSheet = true } label: {
            HStack {
                Text("Body Weight")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(weightLabel(for: weightKg))
                    .font(.body.weight(.medium))
                    .foregroundColor(Color.Glu.primaryBlue)

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(Color.Glu.primaryBlue.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showWeightSheet) {
            weightSheet
        }
    }

    // 🔹 Target Weight – einzeilig + Sheet
    private var targetWeightRow: some View {
        Button {
            showTargetWeightSheet = true
        } label: {
            HStack {
                Text("Target Weight")
                    .font(.subheadline)
                    .foregroundColor(Color.Glu.primaryBlue)

                Spacer()

                Text(weightLabel(for: targetWeightKg))
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
                    // 1-kg-Intervalle, 40–250 kg
                    ForEach(40...250, id: \.self) { kg in
                        Text(weightLabel(for: kg))
                            .font(.title3)
                            .foregroundColor(Color.Glu.primaryBlue)
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

    // 🔹 Target Sleep – einzeilig + Sheet
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
                    // 15-Minuten-Intervalle: 300–720 in 15er Schritten
                    ForEach(Array(stride(from: 300, through: 720, by: 15)), id: \.self) { minutes in
                        Text(sleepLabel(for: minutes))
                            .font(.title3)
                            .foregroundColor(Color.Glu.primaryBlue)
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

    // MARK: - Sheets (Implementierungen)

    private var birthDateSheet: some View {
        VStack(spacing: 12) {
            Text("Birth Date")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)
                .padding(.top, 10)

            DatePicker(
                "",
                selection: $birthDate,
                in: birthDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 220)

            doneButton("Done") {
                showBirthDateSheet = false
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
    }

    private var heightSheet: some View {
        VStack(spacing: 12) {
            Text("Body Height")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)
                .padding(.top, 10)

            Picker("", selection: $heightCm) {
                ForEach(130...220, id: \.self) { cm in
                    Text(heightLabel(for: cm))
                        .font(.title3)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(cm)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 220)

            doneButton("Done") {
                showHeightSheet = false
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
    }

    private var weightSheet: some View {
        VStack(spacing: 12) {
            Text("Body Weight")
                .font(.headline)
                .foregroundColor(Color.Glu.primaryBlue)
                .padding(.top, 10)

            Picker("", selection: $weightKg) {
                ForEach(40...300, id: \.self) { kg in
                    Text(weightLabel(for: kg))
                        .font(.title3)
                        .foregroundColor(Color.Glu.primaryBlue)
                        .tag(kg)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 220)

            doneButton("Done") {
                showWeightSheet = false
            }
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview("BodySettingsSection") {
    Form {
        BodySettingsSection(
            gender: .constant("Male"),
            birthDate: .constant(Date()),
            heightCm: .constant(175),
            weightKg: .constant(80),
            targetWeightKg: .constant(75),
            dailySleepGoalMinutes: .constant(8 * 60),
            heightUnit: .cm,
            weightUnit: .kg
        )
    }
}
