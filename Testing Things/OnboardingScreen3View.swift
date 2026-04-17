import SwiftUI

struct OnboardingScreen3View: View {
    var onContinue: () -> Void = {}

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 24)

                topLabel
                    .padding(.bottom, 18)

                titleBlock
                    .padding(.bottom, 16)

                introText
                    .padding(.horizontal, 10)
                    .padding(.bottom, 18)

                heroStack
                    .padding(.horizontal, 6)
                    .padding(.bottom, 20)

                supportingText
                    .padding(.horizontal, 8)
                    .padding(.bottom, 22)

                ctaButton
                    .padding(.horizontal, 6)
                    .padding(.top, 24)

                pageDots
                    .padding(.top, 20)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color.Glu.activityDomain.opacity(0.15),
                Color.Glu.nutritionDomain.opacity(0.25),
                Color.Glu.bodyDomain.opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header

    private var topLabel: some View {
        Text("GLUCOSE INFLUENCERS")
            .font(.system(size: 13.5, weight: .medium))
            .kerning(2.4)
            .foregroundStyle(titleColor.opacity(0.78))
            .multilineTextAlignment(.center)
    }

    // MARK: - Title

    private var titleBlock: some View {
        (
            Text("See how ")
                .foregroundStyle(titleColor)
            + Text("activity")
                .foregroundStyle(Color.Glu.activityDomain)
            + Text(", ")
                .foregroundStyle(titleColor)
            + Text("body")
                .foregroundStyle(Color.Glu.bodyDomain)
            + Text(", and ")
                .foregroundStyle(titleColor)
            + Text("nutrition")
                .foregroundStyle(Color.Glu.nutritionDomain)
            + Text("\naffect glucose.")
                .foregroundStyle(titleColor)
        )
        .font(.system(size: 29, weight: .semibold))
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Intro Text

    private var introText: some View {
        Text("Know the influences. Manage glucose more clearly.")
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(bodyColor)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: 342)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Hero Stack

    private var heroStack: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                topInfluencerCard(
                    title: "Activity",
                    subtitle: "Movement can shift glucose patterns.",
                    accent: Color.Glu.activityDomain,
                    icon: "figure.run",
                    chartIcon: "chart.line.uptrend.xyaxis"
                )

                topInfluencerCard(
                    title: "Body",
                    subtitle: "Recovery can affect glucose stability.",
                    accent: Color.Glu.bodyDomain,
                    icon: "bed.double.fill",
                    chartIcon: "waveform.path.ecg"
                )
            }

            nutritionCard
        }
        .frame(maxWidth: .infinity)
    }

    private func topInfluencerCard(
        title: String,
        subtitle: String,
        accent: Color,
        icon: String,
        chartIcon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(bodyColor)
                .lineSpacing(2)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(0.06))

                VStack(spacing: 8) {
                    Image(systemName: chartIcon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(accent)

                    Text("Placeholder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)
                }
            }
            .frame(height: 92)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 188)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white)
                .shadow(
                    color: Color.Glu.primaryBlue.opacity(0.07),
                    radius: 14,
                    x: 0,
                    y: 8
                )
        )
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Glu.nutritionDomain.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Glu.nutritionDomain)
                }

                Text("Ernährung")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Glu.nutritionDomain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Text("Carbs, protein, and fat can shape how glucose responds.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(bodyColor)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.Glu.nutritionDomain.opacity(0.06))

                Text("Placeholder")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.Glu.nutritionDomain)
            }
            .frame(height: 88)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white)
                .shadow(
                    color: Color.Glu.primaryBlue.opacity(0.07),
                    radius: 14,
                    x: 0,
                    y: 8
                )
        )
    }

    // MARK: - Supporting Text

    private var supportingText: some View {
        (
            Text("Activity, nutrition, and ")
                .foregroundStyle(bodyColor)
            + Text("body signals")
                .foregroundStyle(Color.Glu.bodyDomain)
                .fontWeight(.medium)
            + Text(" can all affect glucose—helping you see ")
                .foregroundStyle(bodyColor)
            + Text("patterns")
                .foregroundStyle(Color.Glu.activityDomain)
                .fontWeight(.medium)
            + Text(" in context.")
                .foregroundStyle(bodyColor)
        )
        .font(.system(size: 16.5, weight: .regular))
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .frame(maxWidth: 342)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Style Helpers

    private var titleColor: Color {
        Color(red: 0.06, green: 0.10, blue: 0.18)
    }

    private var bodyColor: Color {
        Color(red: 0.45, green: 0.48, blue: 0.55)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: onContinue) {
            Text("Continue to your history.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.Glu.primaryBlue, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.Glu.primaryBlue.opacity(0.22))
                .frame(width: 10, height: 10)

            Circle()
                .fill(Color.Glu.primaryBlue.opacity(0.22))
                .frame(width: 10, height: 10)

            Circle()
                .fill(Color.Glu.primaryBlue)
                .frame(width: 11, height: 11)
        }
    }
}

#Preview {
    OnboardingScreen3View()
}
