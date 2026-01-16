//
//  TipInlineButton.swift
//  GluVibProbe
//
//  Apple-conform inline info button using system presentation.
//  - Tap info.circle -> presents a popover (iPad) or adapts to sheet (iPhone)
//  - No custom overlay/callout layout fighting the parent ScrollView/Card
//  - Styling (background + typography) lives ONLY here
//

import SwiftUI
import TipKit

struct TipInlineButton<T: Tip>: View {

    // MARK: - Inputs

    let tip: T
    let learnMoreTitle: String
    let onLearnMore: () -> Void
    let frameColor: Color

    // MARK: - UI State

    @State private var isPresented: Bool = false

    // MARK: - Init

    init(
        tip: T,
        learnMoreTitle: String = "Learn more in Settings",
        frameColor: Color = Color.Glu.primaryBlue,
        onLearnMore: @escaping () -> Void
    ) {
        self.tip = tip
        self.learnMoreTitle = learnMoreTitle
        self.frameColor = frameColor
        self.onLearnMore = onLearnMore
    }

    // MARK: - Body

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // ✅ Apple-conform system presentation:
        // - iPad: popover anchored to the icon
        // - iPhone: automatically adapts to sheet
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.center), arrowEdge: .top) {
            TipPresentedCard(
                tip: tip,
                learnMoreTitle: learnMoreTitle,
                frameColor: frameColor,
                onClose: { isPresented = false },
                onLearnMore: {
                    isPresented = false
                    onLearnMore()
                }
            )
            .padding(16)
            .presentationCompactAdaptation(.sheet) // ✅ key for iPhone: "over everything"
        }
        .accessibilityLabel("Info")
    }
}

// MARK: - Presented Content (styled here only)

private struct TipPresentedCard<T: Tip>: View {

    let tip: T
    let learnMoreTitle: String
    let frameColor: Color
    let onClose: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .firstTextBaseline, spacing: 10) {

                if let img = tip.image {
                    img
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.Glu.primaryBlue)
                } else {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.Glu.primaryBlue)
                }

                tip.title
                    .font(.system(size: 16, weight: .bold))   // ✅ bigger
                    .foregroundStyle(Color.Glu.primaryBlue)

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold)) // ✅ bigger
                        .foregroundStyle(Color.Glu.primaryBlue.opacity(0.85))
                        .accessibilityLabel("Close")
                }
                .buttonStyle(.plain)
            }

            if let msg = tip.message {
                msg
                    .font(.system(size: 16, weight: .semibold))     // ✅ bigger
                    .foregroundStyle(Color.Glu.primaryBlue.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onLearnMore) {
                HStack(spacing: 6) {
                    Text(learnMoreTitle)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.system(size: 15, weight: .semibold))         // ✅ bigger
                .foregroundStyle(Color.Glu.primaryBlue)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 520, alignment: .leading) // ✅ not "320 narrow"; iPhone sheet uses safe width

        // ✅ slightly grayer background (less transparent)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.Glu.backgroundSurface.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.06))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(frameColor.opacity(0.85), lineWidth: 1.6)
        )
    }
}

// MARK: - Preview

private struct PreviewTip: Tip {
    var title: Text { Text("Last 24 Hours (24h)") }
    var message: Text? {
        Text("For accuracy, CGM metrics labeled (24h) are based on the latest fully available readings from Apple Health. Newer readings may appear with a short delay.")
    }
    var image: Image? { Image(systemName: "waveform.path.ecg") }
}

#Preview("TipInlineButton") {
    VStack(spacing: 16) {
        HStack {
            Spacer()
            TipInlineButton(
                tip: PreviewTip(),
                learnMoreTitle: "Learn more in Settings",
                frameColor: Color.Glu.primaryBlue,
                onLearnMore: { print("Learn more tapped") }
            )
        }
        .padding()

        Text("Tap the info icon. On iPhone this adapts to a sheet, on iPad it is a popover.")
            .font(.caption)
            .foregroundStyle(Color.Glu.primaryBlue.opacity(0.7))
            .padding(.horizontal)
    }
    .background(Color.Glu.backgroundNavy)
}
