//
//  BolusDebugCardView.swift
//  GluVibProbe
//
//  DEBUG VIEW (No MetabolicRingRowCard dependency)
//  - Purpose: isolate whether "no horizontal inset" issue comes from the reusable component.
//  - This view inlines the UI of MetabolicRingRowCard directly.
//  - Keeps: BolusViewModelV1 + HealthStore (SSoT), GluVibCardFrame, styling tokens.
//  - Removes: MetabolicRingRowCard + MetabolicAvgRing component dependency.
//

import SwiftUI

// MARK: - Bolus Debug Card View (inline UI)

struct BolusDebugCardView: View {

    @StateObject private var viewModel: BolusViewModelV1

    let onTap: () -> Void
    private let domainColor = Color.Glu.metabolicDomain

    // MARK: - Layout Tokens (copied from MetabolicRingRowCard)

    private let ringDiameter: CGFloat = 50
    private let ringLineWidth: CGFloat = 7
    private let ringSlotInnerPadding: CGFloat = 8
    private let ringValueSpacing: CGFloat = 4

    private let todayBlockWidth: CGFloat = 70
    private let todayValueFontSize: CGFloat = 30
    private let todayValueYOffset: CGFloat = -1
    private let todayLabelYOffset: CGFloat = 0

    init(
        healthStore: HealthStore,
        viewModel: BolusViewModelV1? = nil,
        onTap: @escaping () -> Void
    ) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: BolusViewModelV1(healthStore: healthStore))
        }
        self.onTap = onTap
    }

    var body: some View {

        let todayValue = viewModel.todayBolusUnits

        VStack(alignment: .leading, spacing: 8) {

            // Header
            Text("Bolus (U)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.Glu.primaryBlue)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Row: Today + Rings
            HStack(alignment: .top, spacing: 10) {

                // LEFT: Today
                VStack(alignment: .center, spacing: 2) {

                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.Glu.primaryBlue.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .offset(x: 0, y: todayLabelYOffset)

                    Text(format1(todayValue))
                        .font(.system(size: todayValueFontSize, weight: .bold))
                        .foregroundColor(Color.Glu.primaryBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .offset(x: 2, y: todayValueYOffset)
                }
                .frame(width: todayBlockWidth, height: ringDiameter, alignment: .center)

                // RIGHT: Rings
                HStack(spacing: 0) {
                    ringSlot(label: "7d",  todayValue: todayValue, avgValue: avgUnits(days: 7))
                    ringSlot(label: "14d", todayValue: todayValue, avgValue: avgUnits(days: 14))
                    ringSlot(label: "30d", todayValue: todayValue, avgValue: avgUnits(days: 30))
                    ringSlot(label: "90d", todayValue: todayValue, avgValue: avgUnits(days: 90))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .gluVibCardFrame(domainColor: domainColor)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Ring Slot (inline)

    private func ringSlot(label: String, todayValue: Double, avgValue: Double) -> some View {
        VStack(alignment: .center, spacing: ringValueSpacing) {

            let avg = max(avgValue, 0.0001)
            let ratio = min(max(todayValue / avg, 0.0), 1.0)

            ZStack {
                Circle()
                    .stroke(Color.Glu.primaryBlue.opacity(0.10), lineWidth: ringLineWidth)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        domainColor,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("Ø")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)

                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.Glu.primaryBlue)
                }
                .multilineTextAlignment(.center)
            }
            .frame(width: ringDiameter, height: ringDiameter)

            Text(formatAvg(avgValue))
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.Glu.primaryBlue.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, ringSlotInnerPadding)
    }

    // MARK: - Helpers

    private func avgUnits(days: Int) -> Double {
        Double(viewModel.periodAverages.first(where: { $0.days == days })?.value ?? 0)
    }

    private func format1(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.0001 { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }

    private func formatAvg(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.0001 { return "\(Int(value.rounded()))" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview("Bolus Debug Card View (Inline)") {
    let store = HealthStore.preview()
    let vm = BolusViewModelV1(healthStore: store)

    return VStack(spacing: 16) {
        BolusDebugCardView(healthStore: store, viewModel: vm, onTap: {})
    }
    .padding()
    .background(Color.Glu.backgroundNavy)
}
