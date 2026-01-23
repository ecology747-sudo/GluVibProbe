//
//  ZoomableContainer.swift
//  GluVibProbe
//

import SwiftUI

struct ZoomableContainer<Content: View>: View {

    private let content: Content

    // MARK: - Config
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 2.0          // UPDATED: max zoom reduced to 2x

    // MARK: - State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if scale > 1.0001 {
                coreView
                    .simultaneousGesture(panGesture)   // UPDATED: only pan when zoomed
            } else {
                coreView                                // UPDATED: no pan gesture => ScrollView scroll works
            }
        }
    }

    // MARK: - Core View

    private var coreView: some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.90, blendDuration: 0.12), value: scale)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.90, blendDuration: 0.12), value: offset)
            .gesture(magnificationGesture)
            .onTapGesture(count: 2, perform: handleDoubleTap)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = clamp(lastScale * value, min: minScale, max: maxScale)
                scale = next
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    reset()
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                offset = CGSize(
                    width: lastOffset.width + v.translation.width,
                    height: lastOffset.height + v.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Double Tap

    private func handleDoubleTap() {
        if scale > 1.0001 {
            reset()
        } else {
            scale = maxScale
            lastScale = scale
        }
    }

    // MARK: - Helpers

    private func reset() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Preview

#Preview("ZoomableContainer") {
    ScrollView {
        ZoomableContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Report Preview")
                    .font(.title2.weight(.bold))

                ForEach(0..<30, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 44)
                        .overlay(
                            HStack {
                                Text("Row \(i + 1)")
                                Spacer()
                                Text("Value")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                        )
                }
            }
            .padding(16)
        }
    }
    .background(Color.white)
}
