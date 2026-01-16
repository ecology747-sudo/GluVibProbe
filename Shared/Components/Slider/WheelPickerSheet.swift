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

import SwiftUI

struct WheelPickerSheet<Value: Hashable & Comparable>: View {

    // MARK: - Inputs

    let title: String
    @Binding var selection: Value
    let values: [Value]
    let valueLabel: (Value) -> String
    let detent: PresentationDetent

    @Environment(\.dismiss) private var dismiss

    // MARK: - Style Tokens (SSoT)

    private let primaryColor: Color = Color.Glu.primaryBlue
    private let titleFont: Font = .title3.weight(.semibold)

    private let pickerFont: Font = .title2.weight(.semibold)
    private let pickerHeight: CGFloat = 320

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // UPDATED: centered title BELOW toolbar (no collision with Done)
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(primaryColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

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
            .navigationTitle("")                    // keep navbar visually clean
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
        detent: PresentationDetent = .fraction(0.72)
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
            detent: detent
        )
    }
}
