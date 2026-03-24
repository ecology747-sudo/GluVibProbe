//
//  WheelPickerSheet.swift
//  GluVibProbe
//
//  Reusable Apple-style Wheel Picker Sheet
//  - Single Done button (top-right)
//  - Title rendered BELOW the nav bar (centered), so long titles never collide with Done
//  - Slightly smaller wheel values (less crowded)
//  - Taller sheet (~70–75% height)
//  - Liquid Glass / Apple-native presentation
//
//  UPDATED:
//  - Adds optional hintText rendered BELOW the title (and ABOVE the wheel), so it is always visible.
//

import SwiftUI

struct WheelPickerSheet<Value: Hashable & Comparable>: View {

    // MARK: - Inputs

    let title: String
    @Binding var selection: Value
    let values: [Value]
    let valueLabel: (Value) -> String
    let detent: PresentationDetent

    // UPDATED
    let hintText: String?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Style Tokens (SSoT)

    // 🟨 UPDATED: sheet foreground now uses adaptive system foreground
    private let primaryColor: Color = Color.Glu.systemForeground
    private let titleFont: Font = .title3.weight(.semibold)

    private let pickerFont: Font = .title2.weight(.semibold)
    private let pickerHeight: CGFloat = 320

    // 🟨 UPDATED: hint follows the same adaptive sheet foreground logic
    private let hintFont: Font = .caption
    private let hintColor: Color = Color.Glu.systemForeground.opacity(0.7)

    // MARK: - Init

    init(
        title: String,
        selection: Binding<Value>,
        values: [Value],
        valueLabel: @escaping (Value) -> String,
        detent: PresentationDetent = .fraction(0.72),
        hintText: String? = nil // UPDATED
    ) {
        self.title = title
        self._selection = selection
        self.values = values
        self.valueLabel = valueLabel
        self.detent = detent
        self.hintText = hintText
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // Centered title BELOW toolbar (no collision with Done)
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(primaryColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                // UPDATED: hint below title, above wheel
                if let hintText, !hintText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(hintText)
                        .font(hintFont)
                        .foregroundStyle(hintColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.top, -2)
                }

                Picker("", selection: $selection) {
                    ForEach(values, id: \.self) { value in
                        Text(valueLabel(value))
                            .font(pickerFont)
                            .foregroundStyle(primaryColor)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: pickerHeight)
                .tint(primaryColor)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(primaryColor)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDragIndicator(.visible)
        .presentationDetents([detent])
    }
}

// MARK: - Convenience Factories (SSoT)

extension WheelPickerSheet {

    static func ints(
        title: String,
        selection: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        unitText: String?,
        detent: PresentationDetent = .fraction(0.72),
        hintText: String? = nil // UPDATED
    ) -> WheelPickerSheet<Int> {

        let values = Array(stride(from: range.lowerBound, through: range.upperBound, by: step))

        return WheelPickerSheet<Int>(
            title: title,
            selection: selection,
            values: values,
            valueLabel: { value in
                if let unitText {
                    return "\(value) \(unitText)"
                } else {
                    return "\(value)"
                }
            },
            detent: detent,
            hintText: hintText
        )
    }
}

#Preview("WheelPickerSheet") {
    WheelPickerSheet<Double>(
        title: "Bolus Priming Threshold",
        selection: .constant(0.3),
        values: Array(stride(from: 0.1, through: 1.5, by: 0.1)).map { (Double($0) * 10.0).rounded() / 10.0 },
        valueLabel: { String(format: "%.1f U", $0) },
        detent: .fraction(0.72),
        hintText: "Applies to doses ≤ 0.3 U."
    )
}
