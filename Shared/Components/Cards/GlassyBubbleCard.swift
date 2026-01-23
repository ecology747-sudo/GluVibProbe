//
//  GlassyBubbleCard.swift
//  GluVibProbe
//
//  Reusable “glassy” confirmation bubble (single file component)
//

import SwiftUI
import UIKit

// ============================================================
// MARK: - GlassyBubbleCard
// ============================================================

struct GlassyBubbleCard: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let title: String
    let message: String

    let primaryTitle: String
    let secondaryTitle: String

    let onPrimary: () -> Void
    let onSecondary: () -> Void

    // Optional: tap outside to dismiss (nil = disabled)
    var onBackgroundTap: (() -> Void)? = nil

    // Layout tuning (safe defaults)
    var maxCardWidth: CGFloat = 560
    var cardCornerRadius: CGFloat = 28

    // ============================================================
    // MARK: - Style Tokens
    // ============================================================

    private let blue = Color.Glu.primaryBlue

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        ZStack {
            // Background overlay (keeps the underlying UI visible; no dim/wash)
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onBackgroundTap?() }

            // Bubble (content-driven height)
            VStack(spacing: 14) {

                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(blue)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                NoHyphenationText(
                    text: message,
                    font: UIFont.systemFont(ofSize: 17, weight: .regular),
                    color: UIColor(Color.Glu.primaryBlue.opacity(0.78))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

                Button {
                    onPrimary()
                } label: {
                    Text(primaryTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.30))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Button {
                    onSecondary()
                } label: {
                    Text(secondaryTitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(blue.opacity(0.80))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)

            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 18)
            .frame(maxWidth: maxCardWidth)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 18)
        }
    }
}

// ============================================================
// MARK: - NoHyphenationText (UIKit-backed; no word splitting)
// ============================================================

private struct NoHyphenationText: UIViewRepresentable {

    let text: String
    let font: UIFont
    let color: UIColor

    func makeUIView(context: Context) -> WrappingLabel {
        let label = WrappingLabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ uiView: WrappingLabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.hyphenationFactor = 0.0

        uiView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

/// UILabel that continuously updates preferredMaxLayoutWidth,
/// so multi-line intrinsic height is always correct inside SwiftUI.
private final class WrappingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        if preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    ZStack {
        Color.gray.opacity(0.15).ignoresSafeArea()

        GlassyBubbleCard(
            title: "Confirm export",
            message: "You are about to export health-related data. This information may be sensitive. You are responsible for protecting it and for any use in accordance with applicable data protection and privacy regulations.",
            primaryTitle: "Accept",
            secondaryTitle: "Cancel",
            onPrimary: {},
            onSecondary: {},
            onBackgroundTap: {}
        )
        .padding(.horizontal, 16)
    }
}
