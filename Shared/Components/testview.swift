import SwiftUI

struct ColorTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Primary Blue")
                .padding()
                .background(Color.Glu.primaryBlue)
                .foregroundStyle(.white)

            Text("Lime Glow")
                .padding()
                .background(Color.Glu.limeGlow)
                .foregroundStyle(.black)

            Text("Deep Navy")
                .padding()
                .background(Color.Glu.deepNavy)
                .foregroundStyle(.white)
        }
        .padding()
    }
}

#Preview {
    ColorTestView()
}
