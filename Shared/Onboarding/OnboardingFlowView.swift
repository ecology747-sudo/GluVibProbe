//
//  OnboardingFlowView.swift
//  GluVibProbe
//
//  Domain: Onboarding
//  Screen Type: Full-Screen Flow
//
//  Purpose
//  - Guides the user through the initial GluVib setup flow.
//  - Covers disclaimer acknowledgement, optional CGM / insulin visibility,
//    Apple Health permission entry point, and final ready state.
//
//  Data Flow (SSoT)
//  - SwiftUI View → SettingsModel / HealthStore
//  - No direct business logic outside onboarding flow state handling
//
//  Key Connections
//  - SettingsModel
//  - HealthStore
//  - OnboardingDisclaimerStepView
//  - L10n.OnboardingFlow
//

import SwiftUI
import UIKit
import HealthKit

struct OnboardingFlowView: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    // ============================================================
    // MARK: - Flow State
    // ============================================================

    private enum Step: Int {
        case disclaimer = 1
        case sensorVisibility = 2
        case insulinVisibility = 3
        case healthPermission = 4
        case ready = 5
    }

    private enum ConnectState {
        case idle
        case requesting
    }

    @State private var step: Step = .disclaimer
    @State private var connectState: ConnectState = .idle

    @State private var showDenyAlert: Bool = false
    @State private var pendingExternalURL: URL? = nil

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
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.75)

    private var isDarkMode: Bool { colorScheme == .dark }

    private var secondaryBorderColor: Color {
        isDarkMode ? Color.Glu.backgroundSurface : Color.Glu.systemForeground.opacity(0.25)
    }

    private var primaryActionFill: Color {
        isDarkMode ? Color.Glu.backgroundSurface : Color.Glu.primaryBlue
    }

    private var primaryActionTextColor: Color {
        isDarkMode ? Color.Glu.primaryBlue : .white
    }

    private var primaryActionStroke: Color {
        .clear
    }

    private var secondaryActionFill: Color {
        isDarkMode ? .clear : .white
    }

    private var backButtonFill: Color {
        isDarkMode ? .clear : .white
    }

    private var backButtonStroke: Color {
        isDarkMode ? Color.Glu.systemForeground.opacity(0.22) : Color.Glu.systemForeground.opacity(0.12)
    }

    // ============================================================
    // MARK: - Derived State
    // ============================================================

    private var canGoBack: Bool {
        step != .disclaimer
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 18) {

                headerRow

                Text(L10n.OnboardingFlow.appSetupTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(titleColor)

                Divider()

                Group {
                    switch step {
                    case .disclaimer:
                        disclaimerContent
                    case .sensorVisibility:
                        sensorVisibilityContent
                    case .insulinVisibility:
                        insulinVisibilityContent
                    case .healthPermission:
                        healthPermissionContent
                    case .ready:
                        readyContent
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)

            bottomActions
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color("GluSoftGray").ignoresSafeArea())
        .tint(titleColor)
        .alert(L10n.OnboardingFlow.acknowledgementRequiredTitle, isPresented: $showDenyAlert) {

            Button(L10n.OnboardingFlow.openDisclaimer) {
                pendingExternalURL = disclaimerURL
                showDenyAlert = false
                openPendingURLAfterAlertDismiss()
            }

            Button(L10n.OnboardingFlow.openPrivacyPolicy) {
                pendingExternalURL = privacyURL
                showDenyAlert = false
                openPendingURLAfterAlertDismiss()
            }

            Button(L10n.OnboardingFlow.openTerms) {
                pendingExternalURL = termsURL
                showDenyAlert = false
                openPendingURLAfterAlertDismiss()
            }

            Button(L10n.OnboardingFlow.ok, role: .cancel) {
                pendingExternalURL = nil
            }

        } message: {
            Text(L10n.OnboardingFlow.acknowledgementRequiredMessage)
        }
        .onAppear {
            if settings.hasCompletedOnboarding { return }

            if !settings.hasAcceptedDisclaimer {
                step = .disclaimer
                return
            }

            if settings.hasAcceptedDisclaimer && settings.hasSeenHealthPermissionGate == false {
                step = .sensorVisibility
                return
            }

            step = .healthPermission
        }
    }

    // ============================================================
    // MARK: - Header
    // ============================================================

    private var headerRow: some View {
        HStack(alignment: .center) {

            Button {
                goBackOneStepV1()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .frame(width: 34, height: 34, alignment: .center)
                    .background(
                        Circle()
                            .fill(backButtonFill)
                            .overlay(
                                Circle()
                                    .stroke(backButtonStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)

            Spacer()

            Text(L10n.OnboardingFlow.stepCounter(step.rawValue, 5))
                .font(.caption.weight(.semibold))
                .foregroundStyle(titleColor.opacity(0.7))
        }
    }

    // ============================================================
    // MARK: - Step Content
    // ============================================================

    private var disclaimerContent: some View {
        OnboardingDisclaimerStepView(
            onAcknowledge: {
                settings.hasAcceptedDisclaimer = true
                settings.saveToDefaults()
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .sensorVisibility
                }
            },
            onDeny: {
                settings.hasAcceptedDisclaimer = false
                settings.saveToDefaults()
                showDenyAlert = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .disclaimer
                }
            }
        )
    }

    private var sensorVisibilityContent: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(L10n.OnboardingFlow.sensorVisibilityTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(L10n.OnboardingFlow.sensorVisibilityBody)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .lineSpacing(2)
        }
    }

    private var insulinVisibilityContent: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(L10n.OnboardingFlow.insulinVisibilityTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(L10n.OnboardingFlow.insulinVisibilityBody)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .lineSpacing(2)
        }
        .onAppear {
            if settings.hasCGM == false {
                settings.isInsulinTreated = false
                settings.saveToDefaults()
                step = .healthPermission
            }
        }
    }

    private var healthPermissionContent: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(L10n.OnboardingFlow.healthPermissionTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(L10n.OnboardingFlow.healthPermissionBody)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .lineSpacing(2)
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 12) {

            Image(systemName: "party.popper.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(titleColor)
                .padding(.bottom, 4)

            Text(L10n.OnboardingFlow.readyTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(L10n.OnboardingFlow.readyBody)
                .font(.footnote)
                .foregroundStyle(captionColor)
                .lineSpacing(2)
        }
    }

    // ============================================================
    // MARK: - Bottom Actions
    // ============================================================

    private var bottomActions: some View {
        VStack(spacing: 10) {

            switch step {

            case .disclaimer:
                EmptyView()

            case .sensorVisibility:
                Button {
                    settings.hasCGM = true
                    settings.saveToDefaults()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .insulinVisibility
                    }
                } label: {
                    Text(L10n.OnboardingFlow.showSensorData)
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

                Button {
                    settings.hasCGM = false
                    settings.isInsulinTreated = false
                    settings.saveToDefaults()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .healthPermission
                    }
                } label: {
                    Text(L10n.OnboardingFlow.doNotShowSensorData)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(secondaryActionFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(secondaryBorderColor, lineWidth: 1)
                        )
                        .foregroundStyle(titleColor)
                }
                .buttonStyle(.plain)

            case .insulinVisibility:
                Button {
                    settings.isInsulinTreated = true
                    settings.saveToDefaults()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .healthPermission
                    }
                } label: {
                    Text(L10n.OnboardingFlow.showInsulinData)
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

                Button {
                    settings.isInsulinTreated = false
                    settings.saveToDefaults()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .healthPermission
                    }
                } label: {
                    Text(L10n.OnboardingFlow.doNotShowInsulinData)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(secondaryActionFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(secondaryBorderColor, lineWidth: 1)
                        )
                        .foregroundStyle(titleColor)
                }
                .buttonStyle(.plain)

            case .healthPermission:
                Button {
                    startAuthorizationAndExitStepV1()
                } label: {
                    HStack(spacing: 10) {
                        if connectState == .requesting {
                            ProgressView()
                                .tint(primaryActionTextColor)
                        }

                        Text(
                            connectState == .requesting
                            ? L10n.OnboardingFlow.waitingForAppleHealth
                            : L10n.OnboardingFlow.connectAppleHealth
                        )
                        .font(.headline.weight(.semibold))
                    }
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
                .disabled(connectState == .requesting)

                Button {
                    settings.hasSeenHealthPermissionGate = true
                    settings.saveToDefaults()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .ready
                    }
                } label: {
                    Text(L10n.OnboardingFlow.skipForNow)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(titleColor.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(connectState == .requesting)

            case .ready:
                Button {
                    settings.hasCompletedOnboarding = true
                    settings.ensureTrialStartedIfEligible()
                    settings.saveToDefaults()
                } label: {
                    Text(L10n.OnboardingFlow.exploreNow)
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
            }
        }
    }

    // ============================================================
    // MARK: - Flow Actions
    // ============================================================

    private func goBackOneStepV1() {
        connectState = .idle

        withAnimation(.easeInOut(duration: 0.2)) {
            switch step {
            case .disclaimer:
                break
            case .sensorVisibility:
                step = .disclaimer
            case .insulinVisibility:
                step = .sensorVisibility
            case .healthPermission:
                if settings.hasCGM {
                    step = .insulinVisibility
                } else {
                    step = .sensorVisibility
                }
            case .ready:
                step = .healthPermission
            }
        }
    }

    private func startAuthorizationAndExitStepV1() {
        settings.hasSeenHealthPermissionGate = true
        settings.saveToDefaults()

        connectState = .requesting

        let scope: HealthStore.AuthorizationScopeV1
        if settings.hasCGM == false {
            scope = .baseOnly
        } else if settings.isInsulinTreated {
            scope = .basePlusCGMPlusInsulin
        } else {
            scope = .basePlusCGM
        }

        let readSet = healthStore.readTypesV1(for: scope)
        guard readSet.isEmpty == false else {
            connectState = .idle
            withAnimation(.easeInOut(duration: 0.2)) { step = .ready }
            return
        }

        healthStore.healthStore.requestAuthorization(toShare: [], read: readSet) { _, _ in
            DispatchQueue.main.async {
                self.connectState = .idle
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.step = .ready
                }
            }
        }
    }

    private func openPendingURLAfterAlertDismiss() {
        guard let url = pendingExternalURL else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            openURL(url)
            pendingExternalURL = nil
        }
    }
}

#Preview("OnboardingFlowView") {
    let previewStore = HealthStore.preview()
    let settings = SettingsModel.shared
    settings.hasCompletedOnboarding = false
    settings.hasAcceptedDisclaimer = false
    settings.hasSeenHealthPermissionGate = false
    settings.hasCGM = false
    settings.isInsulinTreated = false

    return OnboardingFlowView()
        .environmentObject(previewStore)
        .environmentObject(settings)
}
