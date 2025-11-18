//
//  HomeView.swift
//  GluVibProbe
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        Text("Home")
    }
}

#Preview {
    HomeView()
        .environmentObject(HealthStore())   // 👈 Dummy HealthStore für den Canvas
}
