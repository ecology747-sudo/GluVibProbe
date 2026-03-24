//
//  HealthKitPermissionsViewV1.swift
//  GluVibProbe
//
//  Account Sheet — HealthKit Permissions Leaf
//  Purpose:
//  - Explains where Apple Health permissions can be changed.
//  - Exposes warning-visibility control and debug-only no-data simulation.
//
//  Data Flow (SSoT):
//  - SettingsModel -> bindings -> HealthKitPermissionsViewV1 -> UI
//  - Debug toggle -> HealthStore refreshAll() -> refreshed SSoT data flow
//
//  Key Connections:
//  - SettingsModel.shared
//  - HealthStore
//  - Account / Settings permission warning flow
//

import SwiftUI
import UIKit

struct HealthKitPermissionsViewV1: View {

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var healthStore: HealthStore

    // ============================================================
    // MARK: - Styling
    // ============================================================

    private let titleColor: Color = Color.Glu.systemForeground
    private let captionColor: Color = Color.Glu.systemForeground.opacity(0.70)

    // ============================================================
    // MARK: - Bindings / Helpers
    // ============================================================

    private var disregardPermissionWarningsBinding: Binding<Bool> {
        Binding(
            get: { !settings.showPermissionWarnings },
            set: { settings.showPermissionWarnings = !$0 }
        )
    }

    private var debugSimulateNoHealthDataBinding: Binding<Bool> { // 🟨 UPDATED
        Binding(
            get: { settings.debugSimulateNoHealthData },
            set: { newValue in
                settings.debugSimulateNoHealthData = newValue

                Task { @MainActor in
                    await healthStore.refreshAll(.pullToRefresh)
                }
            }
        )
    }

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        List {
            Section {

                VStack(alignment: .leading, spacing: 10) {

                    Text(
                        String(
                            localized: "Health Permissions can be changed in the iOS Settings.",
                            defaultValue: "Health Permissions can be changed in the iOS Settings.",
                            comment: "Explanation text in HealthKit permissions view"
                        )
                    ) // 🟨 UPDATED
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(titleColor)

                    Text(
                        String(
                            localized: "Go to Settings → Apps → Health → Data Access & Devices → GluVib.",
                            defaultValue: "Go to Settings → Apps → Health → Data Access & Devices → GluVib.",
                            comment: "Instruction text in HealthKit permissions view"
                        )
                    ) // 🟨 UPDATED
                    .font(.subheadline)
                    .foregroundStyle(titleColor.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        String(
                            localized: "Or open Health App, tap your profile picture in the top right, then go to Privacy → Apps → GluVib.",
                            defaultValue: "Or open Health App, tap your profile picture in the top right, then go to Privacy → Apps → GluVib.",
                            comment: "Alternative instruction text in HealthKit permissions view"
                        )
                    ) // 🟨 UPDATED
                    .font(.subheadline)
                    .foregroundStyle(titleColor.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))

                Toggle(isOn: disregardPermissionWarningsBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            String(
                                localized: "Disregard Permission Warnings",
                                defaultValue: "Disregard Permission Warnings",
                                comment: "Toggle title in HealthKit permissions view"
                            )
                        ) // 🟨 UPDATED
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor.opacity(0.88))

                        Text(
                            String(
                                localized: "Hides warning badges when Apple Health permissions are missing.",
                                defaultValue: "Hides warning badges when Apple Health permissions are missing.",
                                comment: "Toggle description in HealthKit permissions view"
                            )
                        ) // 🟨 UPDATED
                        .font(.caption)
                        .foregroundStyle(titleColor.opacity(0.60))
                    }
                }
                .tint(Color.Glu.systemForeground)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            }
            .listRowSeparator(.hidden)

            #if DEBUG
            Section {

                Toggle(isOn: debugSimulateNoHealthDataBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            String(
                                localized: "Debug: Simulate No Health Data",
                                defaultValue: "Debug: Simulate No Health Data",
                                comment: "Debug toggle title in HealthKit permissions view"
                            )
                        ) // 🟨 UPDATED
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor.opacity(0.88))

                        Text(
                            String(
                                localized: "Simulates a global no-data state across all Apple Health based metrics without faking permission errors.",
                                defaultValue: "Simulates a global no-data state across all Apple Health based metrics without faking permission errors.",
                                comment: "Debug toggle description in HealthKit permissions view"
                            )
                        ) // 🟨 UPDATED
                        .font(.caption)
                        .foregroundStyle(captionColor)
                    }
                }
                .tint(Color.Glu.systemForeground)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            } footer: {
                Text(
                    String(
                        localized: "Debug only: Use this to test empty-state flows when Apple Health permissions are granted but no readable data is available.",
                        defaultValue: "Debug only: Use this to test empty-state flows when Apple Health permissions are granted but no readable data is available.",
                        comment: "Debug footer text in HealthKit permissions view"
                    )
                ) // 🟨 UPDATED
                .font(.caption)
                .foregroundStyle(captionColor)
            }
            .listRowSeparator(.hidden)
            #endif
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color("GluSoftGray"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(
                    String(
                        localized: "HealthKit Permissions",
                        defaultValue: "HealthKit Permissions",
                        comment: "Navigation title for HealthKit permissions view"
                    )
                ) // 🟨 UPDATED
                .font(.title3.weight(.semibold))
                .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#if DEBUG
#Preview("HealthKitPermissionsViewV1") {
    NavigationStack {
        HealthKitPermissionsViewV1()
            .environmentObject(SettingsModel.shared)
            .environmentObject(HealthStore.preview())
    }
}
#endif
