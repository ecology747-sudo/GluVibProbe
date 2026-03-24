//
//  SettingsView.swift
//  GluVibProbe
//

import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthStore: HealthStore
    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var path: [SettingsDomain] = []

    private let titleColor: Color = Color.Glu.systemForeground
    private let rowFont: Font = .title3.weight(.semibold)
    private let trailingAccessoryColumnWidth: CGFloat = 34 // 🟨 UPDATED

    // ============================================================
    // MARK: - Permission Alarm (V1) — Domain aggregation + UI gating
    // ============================================================

    private var needsHealthKitPermissionsV1: Bool {
        guard settings.showPermissionWarnings else { return false }

        let insulinNeeds =
            settings.isInsulinTreated &&
            healthStore.metabolicTherapyAuthIssueAnyV1

        let glucoseNeeds =
            settings.hasCGM &&
            healthStore.metabolicGlucoseAuthIssueAnyV1

        let metabolicCarbsNeeds =
            settings.isInsulinTreated &&
            healthStore.metabolicCarbsAuthIssueAnyV1

        let nutritionNeeds = healthStore.nutritionAnyAuthIssueForBadgesV1
        let activityNeeds  = healthStore.activityAnyAuthIssueForBadgesV1
        let bodyNeeds      = healthStore.bodyAnyAuthIssueForBadgesV1

        return
            insulinNeeds ||
            glucoseNeeds ||
            metabolicCarbsNeeds ||
            nutritionNeeds ||
            activityNeeds ||
            bodyNeeds
    }

    private var disregardPermissionWarningsBinding: Binding<Bool> {
        Binding(
            get: { !settings.showPermissionWarnings },
            set: { settings.showPermissionWarnings = !$0 }
        )
    }

    private var checkButtonBgV1: Color {
        needsHealthKitPermissionsV1 ? Color.Glu.acidCGMRed : Color.Glu.systemForeground
    }

    // MARK: - Body

    var body: some View {

        NavigationStack(path: $path) {

            List {

                Section {
                    domainRow(L10n.Avatar.Menu.metabolicHome, .metabolic) // 🟨 UPDATED
                    domainRow(
                        String(
                            localized: "Activity",
                            defaultValue: "Activity",
                            comment: "Settings domain row title for activity"
                        ),
                        .activity
                    )
                    domainRow(
                        String(
                            localized: "Body",
                            defaultValue: "Body",
                            comment: "Settings domain row title for body"
                        ),
                        .body
                    )
                    domainRow(
                        String(
                            localized: "Nutrition",
                            defaultValue: "Nutrition",
                            comment: "Settings domain row title for nutrition"
                        ),
                        .nutrition
                    )
                    domainRow(L10n.Avatar.Menu.units, .units)
                }

                Section {

                    Button {
                        openAppSettingsV1()
                    } label: {
                        HStack(spacing: 12) {

                            Text(
                                String(
                                    localized: "HealthKit Permissions",
                                    defaultValue: "HealthKit Permissions",
                                    comment: "Settings row title for HealthKit permissions"
                                )
                            )
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(titleColor)

                            Spacer(minLength: 0)

                            Button {
                                openAppSettingsV1()
                            } label: {
                                Text(
                                    String(
                                        localized: "Check",
                                        defaultValue: "Check",
                                        comment: "Button title for checking HealthKit permissions"
                                    )
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    Capsule()
                                        .fill(checkButtonBgV1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                String(
                                    localized: "Check HealthKit permissions",
                                    defaultValue: "Check HealthKit permissions",
                                    comment: "Accessibility label for checking HealthKit permissions"
                                )
                            )
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))

                    Toggle(isOn: disregardPermissionWarningsBinding) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                String(
                                    localized: "Disregard Permission Warnings",
                                    defaultValue: "Disregard Permission Warnings",
                                    comment: "Toggle title for disregarding permission warnings"
                                )
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(titleColor.opacity(0.88))

                            Text(
                                String(
                                    localized: "Hides warning badges when Apple Health permissions are missing.",
                                    defaultValue: "Hides warning badges when Apple Health permissions are missing.",
                                    comment: "Description for disregarding permission warnings toggle"
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(titleColor.opacity(0.60))
                        }
                    }
                    .tint(Color.Glu.systemForeground)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color("GluSoftGray"))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .principal) {
                    Text(
                        String(
                            localized: "Settings",
                            defaultValue: "Settings",
                            comment: "Navigation title for settings view"
                        )
                    )
                    .font(rowFont)
                    .foregroundStyle(titleColor)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(
                        String(
                            localized: "Done",
                            defaultValue: "Done",
                            comment: "Done button title in settings view"
                        )
                    ) {
                        handleDone()
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(titleColor)
                }
            }

            .navigationDestination(for: SettingsDomain.self) { domain in
                SettingsDomainCardScreen(
                    domain: domain,
                    onBackToSettingsHome: {
                        if !path.isEmpty { path.removeLast() }
                    }
                )
            }
        }
        .tint(titleColor)
    }

    // MARK: - Done behavior (stable)

    private func handleDone() {
        if !path.isEmpty {
            path.removeAll()
            return
        }

        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            appState.isAccountSheetPresented = true
        }
    }

    // MARK: - HealthKit permissions (App Settings deep link)

    private func openAppSettingsV1() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    // MARK: - Domain Row Helper (Text-only, bigger, with chevron; NO badges)

    private func domainRow(_ title: String, _ domain: SettingsDomain) -> some View {
        Button {
            path.append(domain)
        } label: {
            HStack(spacing: 10) {

                Text(title)
                    .font(rowFont)
                    .foregroundStyle(titleColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .frame(width: trailingAccessoryColumnWidth, alignment: .trailing) // 🟨 UPDATED
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Settings Home") {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(SettingsModel.shared)
        .environmentObject(HealthStore.preview())
}
