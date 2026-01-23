//
//  SettingsView.swift
//  GluVibProbe
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.dismiss) private var dismiss

    // Settings owns navigation
    @State private var path: [SettingsDomain] = []

    // MARK: - Typography (match domain rows)

    private let titleColor: Color = Color.Glu.primaryBlue
    private let rowFont: Font = .title3.weight(.semibold)

    var body: some View {

        NavigationStack(path: $path) {

            List {

                Section {
                    domainRow("Metabolic (Home)", .metabolic)
                    domainRow("Activity", .activity)
                    domainRow("Body", .body)
                    domainRow("Nutrition", .nutrition)
                    domainRow("Units", .units)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color("GluSoftGray"))

            // Custom blue title
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(rowFont)
                        .foregroundStyle(titleColor)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
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

    // MARK: - Done behavior (stable, matches your sheet strategy)

    private func handleDone() {
        // 1) If inside Level 3: go back to Settings root list
        if !path.isEmpty {
            path.removeAll()
            return
        }

        // 2) If already on Settings root: close Settings AND re-open Account sheet
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            appState.isAccountSheetPresented = true
        }
    }

    // MARK: - Domain Row Helper (Text-only, bigger, with chevron)

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
}
