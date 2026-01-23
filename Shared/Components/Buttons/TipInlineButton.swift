//
//  TipInlineButton.swift
//  GluVibProbe
//

import SwiftUI

struct TipInlineButton: View {

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Info")
    }
}
