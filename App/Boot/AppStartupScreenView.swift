//
//  AppStartupScreenView.swift
//  GluVibProbe
//

import SwiftUI

struct AppStartupScreenView: View {

    @State private var animateBars = false
    @State private var animateTitle = false
    @State private var animateClaim = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundLayer
                contentLayer(in: geo.size)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) {
                    animateBars = true
                    animateTitle = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    withAnimation(.easeInOut(duration: 0.9)) {
                        animateClaim = true
                    }
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 10 / 255, green: 26 / 255, blue: 47 / 255),
                    Color(red: 0.00, green: 0.03, blue: 0.12),
                    Color(red: 0.03, green: 0.08, blue: 0.22),
                    Color(red: 0.09, green: 0.17, blue: 0.37),
                    Color(red: 0.18, green: 0.28, blue: 0.56)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.42),
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 410
            )
            .scaleEffect(x: 1.08, y: 0.96, anchor: .topTrailing)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.12, green: 0.18, blue: 0.42).opacity(0.10),
                    Color(red: 0.20, green: 0.28, blue: 0.56).opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Content

    private func contentLayer(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: size.height * 0.21)

            headerBlock(in: size) // 🟨 UPDATED
                .padding(.horizontal, size.width < 380 ? 18 : 28) // 🟨 UPDATED

            Spacer()

            barsBlock(in: size)
                .padding(.bottom, size.height * 0.17)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func headerBlock(in size: CGSize) -> some View { // 🟨 UPDATED
        let claimFontSize: CGFloat = size.width < 380 ? 13 : 15 // 🟨 UPDATED
        let claimTracking: CGFloat = size.width < 380 ? 0.7 : 1.1 // 🟨 UPDATED

        return VStack(spacing: 16) {
            Text("GluVib")
                .font(.system(size: 62, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(animateTitle ? 0.995 : 0.0))
                .tracking(-0.8)
                .shadow(color: Color.black.opacity(0.10), radius: 1, x: 0, y: 1)

            Text("HEALTH DATA. CLEARLY VISUALIZED.")
                .font(.system(size: claimFontSize, weight: .bold, design: .rounded)) // 🟨 UPDATED
                .foregroundStyle(Color.white.opacity(animateClaim ? 0.80 : 0.0))
                .tracking(claimTracking) // 🟨 UPDATED
                .shadow(color: .white.opacity(animateClaim ? 0.14 : 0.0), radius: 10, x: 0, y: 0)
                .multilineTextAlignment(.center)
                .lineLimit(1) // 🟨 UPDATED
                .minimumScaleFactor(0.78) // 🟨 UPDATED
                .allowsTightening(true) // 🟨 UPDATED
                .frame(maxWidth: .infinity) // 🟨 UPDATED
                .opacity(animateClaim ? 1.0 : 0.0)
                .offset(y: animateClaim ? 0 : 6)
        }
    }

    // MARK: - Bars

    private func barsBlock(in size: CGSize) -> some View {
        let availableWidth = size.width - 56
        let gap: CGFloat = 12
        let barWidth = (availableWidth - (gap * 3)) / 4
        let barHeight: CGFloat = 24
        let totalBarsWidth = (barWidth * 4) + (gap * 3)
        let startX = -totalBarsWidth / 2 + barWidth / 2

        return ZStack {
            startupBar(
                leadingColor: Color(red: 0.73, green: 0.89, blue: 0.25),
                trailingColor: Color(red: 0.84, green: 0.96, blue: 0.47),
                width: barWidth,
                height: barHeight
            )
            .offset(
                x: startX,
                y: 18
            )

            startupBar(
                leadingColor: Color(red: 0.90, green: 0.44, blue: 0.41),
                trailingColor: Color(red: 0.97, green: 0.63, blue: 0.58),
                width: barWidth,
                height: barHeight
            )
            .offset(
                x: startX + (barWidth + gap),
                y: -8
            )

            startupBar(
                leadingColor: Color(red: 0.93, green: 0.76, blue: 0.45),
                trailingColor: Color(red: 0.98, green: 0.84, blue: 0.60),
                width: barWidth,
                height: barHeight
            )
            .offset(
                x: startX + (barWidth + gap) * 2,
                y: 2
            )

            startupBar(
                leadingColor: Color(red: 0.50, green: 0.86, blue: 0.91),
                trailingColor: Color(red: 0.67, green: 0.92, blue: 0.96),
                width: barWidth,
                height: barHeight
            )
            .offset(
                x: startX + (barWidth + gap) * 3,
                y: 14
            )
        }
        .frame(height: 120)
        .opacity(animateBars ? 1.0 : 0.0)
        .offset(y: animateBars ? 0 : 10)
    }

    private func startupBar(
        leadingColor: Color,
        trailingColor: Color,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        leadingColor,
                        trailingColor
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .frame(width: width, height: height)
            .shadow(color: leadingColor.opacity(0.34), radius: 6, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.06), radius: 1.5, x: 0, y: -1)
    }
}

#Preview {
    AppStartupScreenView()
}
