//
//  TargetsThresholdsMenuView.swift
//  GluVibProbe
//
//  ACCOUNT SHEET — Targets & Thresholds Menu (Level 3)
//

import SwiftUI

struct TargetsThresholdsMenuView: View {

    let onOpenMetabolic: () -> Void
    let onOpenActivity: () -> Void
    let onOpenBody: () -> Void
    let onOpenNutrition: () -> Void

    // 🟨 UPDATED: sheet/settings foreground now uses adaptive system foreground
    private let titleColor: Color = Color.Glu.systemForeground

    var body: some View {
        List {
            Section {
                Button { onOpenMetabolic() } label: { Label("Metabolic", systemImage: "waveform.path.ecg") }
                Button { onOpenActivity() } label: { Label("Activity", systemImage: "figure.walk") }
                Button { onOpenBody() } label: { Label("Body", systemImage: "figure.stand") }
                Button { onOpenNutrition() } label: { Label("Nutrition", systemImage: "fork.knife") }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Targets & Thresholds")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
        }
        .tint(titleColor)
    }
}

#if DEBUG
#Preview("TargetsThresholdsMenuView") {
    NavigationStack {
        TargetsThresholdsMenuView(
            onOpenMetabolic: {},
            onOpenActivity: {},
            onOpenBody: {},
            onOpenNutrition: {}
        )
    }
}
#endif
