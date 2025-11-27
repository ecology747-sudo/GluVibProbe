import SwiftUI

struct ActivityEnergyView: View {

    var body: some View {
        ZStack {
            Color.Glu.activityOrange.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Activity Energy")
                    .font(.title2)
                    .bold()

                Text("Activity Energy View wird später mit HealthStore & ViewModel gebaut.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }
}

#Preview("ActivityEnergyView – Placeholder") {
    ActivityEnergyView()
}
