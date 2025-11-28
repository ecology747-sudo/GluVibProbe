//
//  NutritionDashboard.swift
//  GluVibProbe
//
//  Created by MacBookAir on 16.11.25.
//

import SwiftUI

struct NutritionDashboard: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                // 🔹 Platzhalter-Header
                Text("Nutrition")
                    .font(.title2.bold())

                Text("Nutrition Dashboard – Platzhalter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Nutrition")
        }
    }
}

#Preview {
    NutritionDashboard()
}
