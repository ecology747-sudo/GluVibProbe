import SwiftUI

struct OnboardingScreen2View: View {
    var onContinue: () -> Void = {}

    var body: some View {
        OnboardingStepContainer(
            currentStep: 1,
            totalSteps: 12,
            activeDotColor: metabolicAccentText,
            inactiveDotColor: metabolicAccentText.opacity(0.22),
            topSpacing: 16,
            horizontalPadding: 28,
            introBottomSpacing: 24,
            heroBottomSpacing: 26,
            supportingBottomSpacing: 30,
            ctaTopSpacing: 60,
            dotsTopSpacing: 26,
            bottomMinSpacing: 22
        ) {
            backgroundGradient
        } introContent: {
            VStack(spacing: 0) {
                topLabel
                    .padding(.bottom, 18)

                titleBlock
                    .padding(.bottom, 18)

                introText
            }
        } heroContent: {
            heroGrid
        } supportingContent: {
            supportingText
        } ctaContent: {
            ctaButton
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color.Glu.metabolicDomain.opacity(0.08),
                Color.Glu.metabolicDomain.opacity(0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var topLabel: some View {
        Text("METABOLIC DATA")
            .font(.system(size: 13.5, weight: .medium))
            .kerning(2.4)
            .foregroundStyle(metabolicAccentText)
            .multilineTextAlignment(.center)
    }

    // MARK: - Title

    private var titleBlock: some View {
        (
            Text("See ")
                .foregroundStyle(titleColor)
            + Text("glucose")
                .foregroundStyle(metabolicAccentText)
            + Text(" in context.")
                .foregroundStyle(titleColor)
        )
        .font(.system(size: 31, weight: .semibold))
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Intro Text

    private var introText: some View {
        VStack(spacing: 8) {
            Text("“Why is my glucose level rising?”")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(metabolicAccentText)
                .multilineTextAlignment(.center)

            Text("“Why is my Time in Range so low?”")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(metabolicAccentText)
                .multilineTextAlignment(.center)

            Text("GluVib helps you find clearer answers.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: 342)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Hero Grid

    private var heroGrid: some View {
        HStack(spacing: 16) {
            trendImageCard
            patternImageCard
        }
        .frame(maxWidth: .infinity)
    }

    private var trendImageCard: some View {
        Image("onboarding-screen2-trend-card")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .shadow(
                color: Color.Glu.primaryBlue.opacity(0.06),
                radius: 10,
                x: 0,
                y: 6
            )
    }

    private var patternImageCard: some View {
        Image("onboarding-screen2-pattern-card")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .shadow(
                color: Color.Glu.primaryBlue.opacity(0.06),
                radius: 10,
                x: 0,
                y: 6
            )
    }

    // MARK: - Supporting Text

    private var supportingText: some View {
        (
            Text("Clear charts, meaningful ")
                .foregroundStyle(bodyColor)
            + Text("trends")
                .foregroundStyle(metabolicAccentText)
                .fontWeight(.medium)
            + Text(", and metabolic ")
                .foregroundStyle(bodyColor)
            + Text("patterns")
                .foregroundStyle(metabolicAccentText)
                .fontWeight(.medium)
            + Text("—designed to help you understand your glucose data over time.")
                .foregroundStyle(bodyColor)
        )
        .font(.system(size: 17, weight: .regular))
        .multilineTextAlignment(.center)
        .lineSpacing(5)
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

    private var metabolicAccentText: Color {
        Color(red: 0.44, green: 0.63, blue: 0.10)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: onContinue) {
            Text("See what influences it.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    LinearGradient(
                        colors: [
                            metabolicAccentText.opacity(0.96),
                            metabolicAccentText
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(
                    color: metabolicAccentText.opacity(0.18),
                    radius: 14,
                    x: 0,
                    y: 8
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingScreen2View()
}
