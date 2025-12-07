//
//  NutritionEnergyBalancePrototype.swift
//  GluVibProbe
//
//  Prototype für Burned + Intake Cards + Energy Ring
//

import SwiftUI

struct NutritionEnergyBalancePrototype: View {

    // MARK: - Dummy-Werte (nur Design-Test)
    private let activeKcal: Int   = 620
    private let restingKcal: Int  = 1850
    private let intakeKcal: Int   = 1980

    private var totalBurnedKcal: Int { activeKcal + restingKcal }
    private var balanceKcal: Int { totalBurnedKcal - intakeKcal }
    private var isEnergyRemaining: Bool { balanceKcal >= 0 }

    private var formattedBalanceValue: String {
        String(abs(balanceKcal))
    }

    private var balanceLabelText: String {
        isEnergyRemaining ? "remaining" : "over"
    }

    private var energyProgress: Double {
        guard totalBurnedKcal > 0 else { return 0 }
        let ratio = Double(intakeKcal) / Double(totalBurnedKcal)
        return min(max(ratio, 0), 1.2)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.Glu.backgroundSurface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {

                Text("Energy Balance Prototype")
                    .font(.headline)
                    .foregroundStyle(Color.Glu.primaryBlue)

                HStack(alignment: .center, spacing: 16) {

                    energyRing

                    VStack(spacing: 10) {
                        burnedCard
                        intakeCard
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.Glu.nutritionDomain.opacity(0.35), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.08),
                                radius: 10,
                                x: 0,
                                y: 6)
                )

                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Energy Ring
    private var energyRing: some View {
        ZStack {
            let ringColor: Color = .Glu.nutritionDomain

            Circle()
                .stroke(
                    ringColor.opacity(0.20),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: energyProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            ringColor.opacity(0.95),
                            ringColor.opacity(0.55),
                            ringColor.opacity(0.95)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formattedBalanceValue)
                        .font(.headline.weight(.bold))
                        .foregroundColor(isEnergyRemaining ? .green : .red)

                    Text("kcal")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(
                            isEnergyRemaining
                            ? .green.opacity(0.9)
                            : .red.opacity(0.9)
                        )
                }

                Text(balanceLabelText)
                    .font(.caption2)
                    .foregroundColor(
                        isEnergyRemaining
                        ? .green.opacity(0.9)
                        : .red.opacity(0.9)
                    )
            }
        }
        .frame(width: 110, height: 110)
    }

    // MARK: - Burned Card
    private var burnedCard: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 6) {
                Text("Burned")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                            .overlay(
                                Capsule()
                                    .stroke(Color.Glu.primaryBlue, lineWidth: 0.5)
                            )
                    )

                Spacer()

                Text("\(totalBurnedKcal) kcal")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.Glu.primaryBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                energyRow(label: "Active", value: "\(activeKcal) kcal")
                energyRow(label: "Resting", value: "\(restingKcal) kcal")
            }

        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color.Glu.nutritionDomain.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.nutritionDomain.opacity(0.55), lineWidth: 0.9)
                )
        )
    }

    // MARK: - Intake Card
    private var intakeCard: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(spacing: 6) {
                Text("Intake")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Glu.primaryBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                            .overlay(
                                Capsule()
                                    .stroke(Color.Glu.primaryBlue, lineWidth: 0.5)
                            )
                    )

                Spacer()

                Text("\(intakeKcal) kcal")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.Glu.primaryBlue)
            }

            Text("Nutrition energy from today’s logged intake.")
                .font(.caption2)
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.82))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.94),
                            Color.Glu.nutritionDomain.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Glu.nutritionDomain.opacity(0.55), lineWidth: 0.9)
                )
        )
    }

    private func energyRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue)

            Spacer()

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.Glu.primaryBlue)
        }
    }
}

#Preview("Nutrition Energy Balance Prototype") {
    NutritionEnergyBalancePrototype()
}
