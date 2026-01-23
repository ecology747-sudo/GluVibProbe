//
//  ReportPDFExporter.swift
//  GluVibProbe
//

import SwiftUI
import UIKit

enum ReportPDFExporter {

    // ============================================================
    // MARK: - Multi-Page (Manual Page Breaks)
    // ============================================================

    // Render explicit pages (manual page breaks) + repeat Header/Footer per page.
    // - Each element in `pages` becomes exactly ONE PDF page (no slicing).
    // - Optional `header` and `footer` are rendered once and drawn on EVERY page.
    // - Page number is drawn in a dedicated slot BELOW the footer text (no overlap).
    @MainActor
    static func renderPDFPages(
        pageSize: CGSize = CGSize(width: 595, height: 842),   // A4 @ 72dpi
        pageMargin: CGFloat = 28,                             // ~10mm
        scale: CGFloat = 2.0,                                 // crisp charts
        header: (() -> AnyView?)? = nil,
        footer: (() -> AnyView?)? = nil,
        showsPageNumber: Bool = true,
        pages: [AnyView]
    ) throws -> Data {

        guard !pages.isEmpty else { throw ExportError.renderFailed }

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let contentRect = pageRect.insetBy(dx: pageMargin, dy: pageMargin)

        // Render header/footer once (optional)
        let headerImage: CGImage?
        if let makeHeader = header, let headerView = makeHeader() {
            headerImage = renderImage(
                view: headerView,
                width: contentRect.width,
                scale: scale
            )
        } else {
            headerImage = nil
        }

        let footerImage: CGImage?
        if let makeFooter = footer, let footerView = makeFooter() {
            footerImage = renderImage(
                view: footerView,
                width: contentRect.width,
                scale: scale
            )
        } else {
            footerImage = nil
        }

        let headerHeightPt: CGFloat = headerImage.map { CGFloat($0.height) / scale } ?? 0
        let footerHeightPt: CGFloat = footerImage.map { CGFloat($0.height) / scale } ?? 0

        // Reserve a dedicated slot BELOW the footer for page number (so it never overlaps disclaimer text)
        let pageNumberReservePt: CGFloat = (showsPageNumber && footerHeightPt > 0)
            ? (pageNumberSlotPaddingTopPt + pageNumberSlotHeightPt)
            : 0

        let availableBodyHeightPt = max(
            contentRect.height - headerHeightPt - footerHeightPt - pageNumberReservePt,
            1
        )

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = pdfRenderer.pdfData { ctx in
            let totalPages = pages.count

            for (index, pageView) in pages.enumerated() {
                ctx.beginPage()

                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fill(pageRect)

                // Header (repeat)
                if let hi = headerImage {
                    let ui = UIImage(cgImage: hi)
                    let drawRect = CGRect(
                        x: contentRect.minX,
                        y: contentRect.minY,
                        width: contentRect.width,
                        height: headerHeightPt
                    )
                    ui.draw(in: drawRect)
                }

                // Footer (repeat) — draw higher if we reserve a page-number slot below
                if let fi = footerImage {
                    let ui = UIImage(cgImage: fi)
                    let drawRect = CGRect(
                        x: contentRect.minX,
                        y: pageRect.maxY - pageMargin - footerHeightPt - pageNumberReservePt,
                        width: contentRect.width,
                        height: footerHeightPt
                    )
                    ui.draw(in: drawRect)
                }

                // Body (ONE page)
                if let bodyImage = renderImage(view: pageView, width: contentRect.width, scale: scale) {
                    let ui = UIImage(cgImage: bodyImage)

                    let bodyDrawRect = CGRect(
                        x: contentRect.minX,
                        y: contentRect.minY + headerHeightPt,
                        width: contentRect.width,
                        height: availableBodyHeightPt
                    )

                    ctx.cgContext.saveGState()
                    ctx.cgContext.addRect(bodyDrawRect)
                    ctx.cgContext.clip()

                    ui.draw(in: CGRect(
                        x: bodyDrawRect.minX,
                        y: bodyDrawRect.minY,
                        width: bodyDrawRect.width,
                        height: CGFloat(bodyImage.height) / scale
                    ))

                    ctx.cgContext.restoreGState()
                }

                // Page number — dedicated slot BELOW footer (or bottom margin if no footer)
                if showsPageNumber {
                    drawPageNumber(
                        current: index + 1,
                        total: totalPages,
                        in: ctx.cgContext,
                        pageRect: pageRect,
                        pageMargin: pageMargin,
                        footerHeightPt: footerHeightPt,
                        pageNumberReservePt: pageNumberReservePt
                    )
                }
            }
        }

        if pdfData.isEmpty { throw ExportError.renderFailed }
        return pdfData
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    enum ExportError: Error {
        case renderFailed
    }

    // Dedicated slot geometry (used when footer exists)
    private static let pageNumberSlotHeightPt: CGFloat = 14
    private static let pageNumberSlotPaddingTopPt: CGFloat = 4

    @MainActor
    private static func renderImage(view: AnyView, width: CGFloat, scale: CGFloat) -> CGImage? {

        let root = view
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.white)

        let renderer = ImageRenderer(content: root)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.cgImage
    }

    private static func drawPageNumber(
        current: Int,
        total: Int,
        in context: CGContext,
        pageRect: CGRect,
        pageMargin: CGFloat,
        footerHeightPt: CGFloat,
        pageNumberReservePt: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let text = "\(current) / \(total)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.black.withAlphaComponent(0.55),
            .paragraphStyle: paragraph
        ]

        let frame: CGRect

        if footerHeightPt > 0, pageNumberReservePt > 0 {
            // Draw inside the reserved slot BELOW footer text
            let y = pageRect.maxY - pageMargin - pageNumberReservePt
            frame = CGRect(
                x: pageMargin,
                y: y,
                width: pageRect.width - (pageMargin * 2),
                height: pageNumberReservePt
            )
        } else {
            // Fallback: no footer -> use a minimal baseline area in bottom margin
            let footerAreaHeight = max(footerHeightPt, pageNumberSlotHeightPt)
            let y = pageRect.maxY - pageMargin - footerAreaHeight
            frame = CGRect(
                x: pageMargin,
                y: y,
                width: pageRect.width - (pageMargin * 2),
                height: footerAreaHeight
            )
        }

        let textRect = frame.insetBy(dx: 0, dy: max((frame.height - 12) / 2, 0))
        text.draw(in: textRect, withAttributes: attrs)
    }
}
