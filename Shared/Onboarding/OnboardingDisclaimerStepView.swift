//
//  OnboardingDisclaimerStepView.swift
//  GluVibProbe
//
//  Domain: Onboarding
//  Screen Type: Step Content View
//
//  Purpose
//  - Displays the disclaimer acknowledgement step inside the onboarding flow.
//  - Shows the core informational disclaimer, legal links, and accept / deny actions.
//
//  Data Flow (SSoT)
//  - SwiftUI View → callback closures
//  - No HealthKit access, no fetch logic
//
//  Key Connections
//  - OnboardingFlowView
//  - L10n.OnboardingDisclaimer
//

import SwiftUI

struct OnboardingDisclaimerStepView: View {

    // ============================================================
    // MARK: - External Links
    // ============================================================

    private var disclaimerURL: URL { // 🟨 UPDATED
        URL(string: "https://gluvib.com/\(L10n.Common.languageCode)/disclaimer")!
    }

    private var privacyURL: URL { // 🟨 UPDATED
        URL(string: "https://gluvib.com/\(L10n.Common.languageCode)/privacy")!
    }

    private var termsURL: URL { // 🟨 UPDATED
        URL(string: "https://gluvib.com/\(L10n.Common.languageCode)/terms")!
    }

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let onAcknowledge: () -> Void
    let onDeny: () -> Void

    // ============================================================
    // MARK: - Environment
    // ============================================================

    @Environment(\.colorScheme) private var colorScheme

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.82)
    private let helperColor: Color = Color.Glu.systemForeground.opacity(0.75)

    private var isDarkMode: Bool { colorScheme == .dark }

    private var primaryActionFill: Color {
        isDarkMode ? Color.Glu.backgroundSurface : Color.Glu.primaryBlue
    }

    private var primaryActionTextColor: Color {
        isDarkMode ? Color.Glu.primaryBlue : .white
    }

    private var primaryActionStroke: Color {
        .clear
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text(L10n.OnboardingDisclaimer.welcomeTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(L10n.OnboardingDisclaimer.welcomeBody)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 4)

            Text(L10n.OnboardingDisclaimer.moreInformation)
                .font(.caption.weight(.semibold))
                .foregroundStyle(helperColor)

            VStack(alignment: .leading, spacing: 6) {
                Link(L10n.OnboardingDisclaimer.disclaimerLink, destination: disclaimerURL)
                Link(L10n.OnboardingDisclaimer.privacyPolicyLink, destination: privacyURL)
                Link(L10n.OnboardingDisclaimer.termsLink, destination: termsURL)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(titleColor)

            Spacer(minLength: 10)

            Button(action: onAcknowledge) {
                Text(L10n.OnboardingDisclaimer.accept)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(primaryActionFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(primaryActionStroke, lineWidth: 1)
                    )
                    .foregroundStyle(primaryActionTextColor)
            }
            .buttonStyle(.plain)

            Button(action: onDeny) {
                Text(L10n.OnboardingDisclaimer.deny)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(titleColor.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview("OnboardingDisclaimerStepView") {
    OnboardingDisclaimerStepView(
        onAcknowledge: {},
        onDeny: {}
    )
    .padding()
    .background(Color("GluSoftGray"))
}
#endif
