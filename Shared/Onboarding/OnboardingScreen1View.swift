import SwiftUI

struct GluVibOnboardingScreen1View: View {
    var onContinue: () -> Void = {}

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 16)

                topLabel
                    .padding(.bottom, 18)

                titleBlock
                    .padding(.bottom, 18)

                introText
                    .padding(.horizontal, 10)
                    .padding(.bottom, 24)

                heroPanel
                    .padding(.horizontal, 6)
                    .padding(.bottom, 26)

                supportingText
                    .padding(.horizontal, 8)
                    .padding(.bottom, 30)

                ctaButton
                    .padding(.horizontal, 6)
                    .padding(.top, 40)

                pageDots
                    .padding(.top, 26)

                Spacer(minLength: 22)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.975, green: 0.978, blue: 0.995),
                Color(red: 0.915, green: 0.938, blue: 1.000),
                Color(red: 0.955, green: 0.980, blue: 0.935)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var topLabel: some View {
        Text("WELCOME TO GLUVIB")
            .font(.system(size: 13.5, weight: .medium))
            .kerning(2.4)
            .foregroundStyle(Color(red: 0.34, green: 0.54, blue: 0.96))
            .multilineTextAlignment(.center)
    }

    // MARK: - Title

    private var titleBlock: some View {
        (
            Text("See your ")
                .foregroundStyle(titleColor)
            + Text("glucose data")
                .foregroundStyle(highlightBlue)
            + Text("\nlike never before.")
                .foregroundStyle(titleColor)
        )
        .font(.system(size: 31, weight: .semibold))
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Intro Text

    private var introText: some View {
        VStack(spacing: 6) {
            (
                Text("Get insights on how your ")
                    .foregroundStyle(bodyColor)
                + activityHighlight
                + Text(", ")
                    .foregroundStyle(bodyColor)
                + foodHighlight
                + Text(", and ")
                    .foregroundStyle(bodyColor)
                + restHighlight
                + Text(" affect your glucose levels throughout the day—without switching between multiple charts and apps.")
                    .foregroundStyle(bodyColor)
            )
            .font(.system(size: 17, weight: .regular))
            .multilineTextAlignment(.center)
            .lineSpacing(4)

            Text("All in one clear view.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 350)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var activityHighlight: Text {
        Text("activity")
            .foregroundStyle(highlightBlue)
            .fontWeight(.semibold)
    }

    private var foodHighlight: Text {
        Text("food")
            .foregroundStyle(highlightBlue)
            .fontWeight(.semibold)
    }

    private var restHighlight: Text {
        Text("rest")
            .foregroundStyle(highlightBlue)
            .fontWeight(.semibold)
    }

    // MARK: - Style Helpers

    private var highlightBlue: Color {
        Color(red: 0.34, green: 0.54, blue: 0.96)
    }

    private var titleColor: Color {
        Color(red: 0.06, green: 0.10, blue: 0.18)
    }

    private var bodyColor: Color {
        Color(red: 0.45, green: 0.48, blue: 0.55)
    }

    // MARK: - Hero Panel

    private var heroPanel: some View {
        Image("onboarding-screen1-hero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .shadow(
                color: Color(red: 0.20, green: 0.30, blue: 0.55).opacity(0.08),
                radius: 14,
                x: 0,
                y: 6
            )
    }

    // MARK: - Supporting Text

    private var supportingText: some View {
        VStack(spacing: 6) {
            Text("Make your glucose data understandable.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(red: 0.29, green: 0.32, blue: 0.39))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)

            Text("Day by day.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(highlightBlue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: onContinue) {
            Text("Ready for more clarity.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.19, green: 0.50, blue: 0.97),
                            Color(red: 0.29, green: 0.60, blue: 1.00)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(
                    color: Color(red: 0.20, green: 0.46, blue: 0.95).opacity(0.18),
                    radius: 16,
                    x: 0,
                    y: 10
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(red: 0.28, green: 0.58, blue: 1.00))
                .frame(width: 11, height: 11)

            Circle()
                .fill(Color(red: 0.76, green: 0.78, blue: 0.85))
                .frame(width: 10, height: 10)

            Circle()
                .fill(Color(red: 0.76, green: 0.78, blue: 0.85))
                .frame(width: 10, height: 10)
        }
    }
}

#Preview {
    GluVibOnboardingScreen1View()
}
