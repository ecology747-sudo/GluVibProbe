import SwiftUI

struct GluVibPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 32)
            .background(
                Capsule()
                    .fill(Color.Glu.primaryBlue.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.04 : 0.08),
                radius: configuration.isPressed ? 1 : 3,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("GluVibPrimaryButtonStyle") {
    VStack(spacing: 24) {
        Button("Save Settings") {}
            .buttonStyle(GluVibPrimaryButtonStyle())
    }
    .padding()
    .background(Color.Glu.backgroundSurface.ignoresSafeArea())
}
