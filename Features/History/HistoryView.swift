//
//  HistoryView.swift
//  GluVibProbe
//
//  Created by MacBookAir on 16.11.25.
//

import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                Text("History")
                    .font(.title2.bold())

                Text("History – Platzhalter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
