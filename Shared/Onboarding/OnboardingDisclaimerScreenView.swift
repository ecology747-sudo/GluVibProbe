import SwiftUI

struct OnboardingDisclaimerScreenView: View {
    let onAccept: () -> Void
    let onDeny: () -> Void

    @Environment(\.openURL) private var openURL

    private var disclaimerURL: URL {
        URL(string: "https://gluvib.com/\(L10n.Common.languageCode)/disclaimer")!
    }

    private var privacyURL: URL {
        URL(string: "https://gluvib.com/\(L10n.Common.languageCode)/privacy")!
    }

    private var termsURL: URL {
        URL(string: "https://gluvib.com/\(L10n.Common.languageCode)/terms")!
    }

    var body: some View {
        OnboardingStepContainer(
            currentStep: 9,
            totalSteps: 11,
            activeDotColor: Color.white.opacity(0.72),
            inactiveDotColor: Color.Glu.primaryBlue.opacity(0.18),
            activeDotStrokeColor: Color.Glu.primaryBlue,
            topSpacing: 16,
            horizontalPadding: 28,
            introBottomSpacing: 20,
            heroBottomSpacing: 22,
            supportingBottomSpacing: 20,
            ctaTopSpacing: 20,
            dotsTopSpacing: 24,
            bottomPadding: 22
        ) {
            backgroundGradient
        } introContent: {
            VStack(spacing: 0) {
                topLabel
                    .padding(.bottom, 18)

                titleBlock
                    .padding(.bottom, 16)

                introText
            }
        } heroContent: {
            legalLinksCard
        } supportingContent: {
            supportingText
        } ctaContent: {
            ctaButtons
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color.Glu.primaryBlue.opacity(0.08),
                Color.Glu.primaryBlue.opacity(0.14)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var topLabel: some View {
        Text("LEGAL")
            .font(.system(size: 13.5, weight: .medium))
            .kerning(2.4)
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.82))
            .multilineTextAlignment(.center)
    }

    // MARK: - Title

    private var titleBlock: some View {
        Text("Please review this\nbefore you continue.")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(titleColor)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Intro Text

    private var introText: some View {
        Text("GluVib is a read-only health data visualization app for informational purposes only. It does not provide medical advice, diagnosis, or treatment recommendations, is not a medical device, and does not replace professional medical care. Always consult a qualified healthcare professional for diagnosis and treatment options.")
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(bodyColor)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: 344)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Hero

    private var legalLinksCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("More Information")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

            HStack(spacing: 10) {
                legalLinkButton("Disclaimer", url: disclaimerURL)
                legalLinkButton("Privacy Policy", url: privacyURL)
                legalLinkButton("Terms of Use", url: termsURL)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white)
                .shadow(
                    color: Color.Glu.primaryBlue.opacity(0.07),
                    radius: 16,
                    x: 0,
                    y: 8
                )
        )
    }

    private func legalLinkButton(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.Glu.primaryBlue)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.Glu.primaryBlue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.Glu.primaryBlue.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Supporting Text

    private var supportingText: some View {
        VStack(spacing: 0) {
            Text("You can review these documents again later at any time in the app or under")
                .font(.system(size: 16.5, weight: .regular))
                .foregroundStyle(bodyColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Link("www.gluvib.com", destination: URL(string: "https://www.gluvib.com")!)
                .font(.system(size: 16.5, weight: .regular))
                .foregroundStyle(Color.Glu.primaryBlue)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: 342)
        .fixedSize(horizontal: false, vertical: true)
    }
    // MARK: - CTA

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button(action: onAccept) {
                Text("I understand and continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.Glu.primaryBlue,
                                Color.Glu.primaryBlue.opacity(0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(
                        color: Color.Glu.primaryBlue.opacity(0.16),
                        radius: 14,
                        x: 0,
                        y: 8
                    )
            }
            .buttonStyle(.plain)

            Button(action: onDeny) {
                Text("Review again")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Style Helpers

    private var titleColor: Color {
        Color(red: 0.06, green: 0.10, blue: 0.18)
    }

    private var bodyColor: Color {
        Color(red: 0.45, green: 0.48, blue: 0.55)
    }
}

#Preview {
    OnboardingDisclaimerScreenView(
        onAccept: {},
        onDeny: {}
    )
}
