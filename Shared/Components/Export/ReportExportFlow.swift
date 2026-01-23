//
//  ReportExportFlow.swift
//  GluVibProbe
//

import SwiftUI
import PDFKit
import UIKit

struct ReportExportFlow: View {

    // ============================================================
    // MARK: - Inputs
    // ============================================================

    let fileName: String

    // EITHER one long content (legacy) OR multiple pages (manual breaks)
    let pdfContent: (() -> AnyView)?
    let pdfPages: (() -> [AnyView])?

    // Optional per-page header/footer (repeated on every PDF page)
    let pageHeader: (() -> AnyView)?
    let pageFooter: (() -> AnyView)?

    let onClose: () -> Void

    // ============================================================
    // MARK: - Init (keeps old call sites working)
    // ============================================================

    init(
        fileName: String,
        pdfContent: @escaping () -> AnyView,
        pageHeader: (() -> AnyView)? = nil,
        pageFooter: (() -> AnyView)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.fileName = fileName
        self.pdfContent = pdfContent
        self.pdfPages = nil
        self.pageHeader = pageHeader
        self.pageFooter = pageFooter
        self.onClose = onClose
    }

    // Manual pages
    init(
        fileName: String,
        pdfPages: @escaping () -> [AnyView],
        pageHeader: (() -> AnyView)? = nil,
        pageFooter: (() -> AnyView)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.fileName = fileName
        self.pdfContent = nil
        self.pdfPages = pdfPages
        self.pageHeader = pageHeader
        self.pageFooter = pageFooter
        self.onClose = onClose
    }

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var settings: SettingsModel

    // ============================================================
    // MARK: - State
    // ============================================================

    @State private var pdfData: Data? = nil
    @State private var isRendering: Bool = false
    @State private var exportError: String? = nil

    @State private var showShareSheet: Bool = false

    // UPDATED: Consent gate is now an in-place overlay (bubble only, no .sheet)
    @State private var showExportConsentSheet: Bool = false
    @State private var hasAcceptedExportConsent: Bool = false

    private var pdfFileName: String {
        fileName.lowercased().hasSuffix(".pdf") ? fileName : "\(fileName).pdf"
    }

    // ============================================================
    // MARK: - Consent Copy (Final)
    // ============================================================

    private let exportConsentTitle: String = "Confirmation"
    private let exportConsentText: String =
        "You are about to export health-related data. "
        + "This information may be sensitive. "
        + "You are responsible for protecting it and for any use in accordance with applicable data protection and privacy regulations."

    // ============================================================
    // MARK: - Body
    // ============================================================

    var body: some View {
        NavigationStack {
            ZStack {

                content
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color.white, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { onClose() }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                        }

                        ToolbarItem(placement: .principal) {
                            Text("Export")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.Glu.primaryBlue)
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                // Require explicit consent before opening share sheet
                                guard pdfData != nil, !isRendering else { return }

                                if hasAcceptedExportConsent {
                                    showShareSheet = true
                                } else {
                                    // UPDATED
                                    showExportConsentSheet = true
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.Glu.primaryBlue)
                            }
                            .buttonStyle(.plain)
                            .disabled(pdfData == nil || isRendering)
                        }
                    }
                    .task { await renderIfNeeded() }

                    // Share Sheet
                    .sheet(isPresented: $showShareSheet) {
                        if let data = pdfData {
                            ActivityView(activityItems: [ExportPDFItem(data: data, fileName: pdfFileName)])
                        }
                    }

                // UPDATED: Bubble-only consent overlay (GlassyBubbleCard component)
                if showExportConsentSheet {
                    GlassyBubbleCard(
                        title: exportConsentTitle,
                        message: exportConsentText,
                        primaryTitle: "Accept",
                        secondaryTitle: "Cancel",
                        onPrimary: {
                            hasAcceptedExportConsent = true
                            showExportConsentSheet = false
                            showShareSheet = true
                        },
                        onSecondary: {
                            showExportConsentSheet = false
                        },
                        onBackgroundTap: {
                            showExportConsentSheet = false
                        }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showExportConsentSheet)
        }
    }

    // ============================================================
    // MARK: - UI
    // ============================================================

    @ViewBuilder
    private var content: some View {
        Group {
            if isRendering {
                stateCard(title: "Preparing PDF…", subtitle: "Rendering report content to a printable PDF.")
            } else if let error = exportError {
                stateCard(title: "Export failed", subtitle: error)
            } else if let data = pdfData, let document = PDFDocument(data: data) {
                PDFKitPreview(document: document)
                    .background(Color.white)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                stateCard(title: "No PDF available", subtitle: "The PDF could not be generated.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }

    private func stateCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if isRendering { ProgressView() }
                else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // ============================================================
    // MARK: - Rendering
    // ============================================================

    @MainActor
    private func renderIfNeeded() async {
        guard pdfData == nil, !isRendering else { return }

        isRendering = true
        exportError = nil

        do {
            let headerView: AnyView? = {
                guard let makeHeader = pageHeader else { return nil }
                return AnyView(
                    makeHeader()
                        .environmentObject(healthStore)
                        .environmentObject(settings)
                        .background(Color.white)
                )
            }()

            let footerView: AnyView? = {
                guard let makeFooter = pageFooter else { return nil }
                return AnyView(
                    makeFooter()
                        .environmentObject(healthStore)
                        .environmentObject(settings)
                        .background(Color.white)
                )
            }()

            // Manual pages
            if let makePages = pdfPages {
                let pages = makePages().map {
                    AnyView(
                        $0
                            .environmentObject(healthStore)
                            .environmentObject(settings)
                            .background(Color.white)
                    )
                }

                let data = try ReportPDFPagesExporter.renderPDF(
                    pageSize: CGSize(width: 595, height: 842),
                    pageMargin: 28,
                    scale: 2.0,
                    header: headerView,
                    footer: footerView,
                    pages: pages,
                    drawPageNumber: true
                )

                pdfData = data
            }
            // Legacy: one long view (kept for backward compatibility)
            else if let makeContent = pdfContent {
                let data = try ReportPDFLongContentExporter.renderPDF(
                    pageSize: CGSize(width: 595, height: 842),
                    pageMargin: 28,
                    scale: 2.0,
                    header: headerView,
                    footer: footerView,
                    content: AnyView(
                        makeContent()
                            .environmentObject(healthStore)
                            .environmentObject(settings)
                            .background(Color.white)
                    ),
                    drawPageNumber: true
                )

                pdfData = data
            } else {
                throw ReportPDFPagesExporter.ExportError.renderFailed
            }

        } catch {
            exportError = "PDF rendering failed. Please try again."
        }

        isRendering = false
    }
}

// ============================================================
// MARK: - PDF Preview (PDFKit)
// ============================================================

private struct PDFKitPreview: UIViewRepresentable {

    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document

        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageBreakMargins = .zero

        view.backgroundColor = .white
        view.documentView?.backgroundColor = .white
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// ============================================================
// MARK: - Share Sheet
// ============================================================

private struct ActivityView: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class ExportPDFItem: NSObject, UIActivityItemSource {

    private let data: Data
    private let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        data
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        data
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        fileName
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        "com.adobe.pdf"
    }
}

// ============================================================
// MARK: - PDF Exporter: Manual Pages (stable)
// ============================================================

private enum ReportPDFPagesExporter {

    enum ExportError: Error { case renderFailed }

    private static let pageNumberSlotHeightPt: CGFloat = 14
    private static let pageNumberSlotPaddingTopPt: CGFloat = 4

    @MainActor
    static func renderPDF(
        pageSize: CGSize,
        pageMargin: CGFloat,
        scale: CGFloat,
        header: AnyView?,
        footer: AnyView?,
        pages: [AnyView],
        drawPageNumber: Bool
    ) throws -> Data {

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let contentRect = pageRect.insetBy(dx: pageMargin, dy: pageMargin)

        let headerImage = header.flatMap { renderImage(view: $0, width: contentRect.width, scale: scale) }
        let footerImage = footer.flatMap { renderImage(view: $0, width: contentRect.width, scale: scale) }

        let headerHeightPt: CGFloat = headerImage.map { CGFloat($0.height) / scale } ?? 0
        let footerHeightPt: CGFloat = footerImage.map { CGFloat($0.height) / scale } ?? 0

        let pageNumberReservePt: CGFloat = {
            guard drawPageNumber else { return 0 }
            guard footerHeightPt > 0 else { return 0 }
            return pageNumberSlotPaddingTopPt + pageNumberSlotHeightPt
        }()

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let pageCount = max(pages.count, 1)

        let pdfData = pdfRenderer.pdfData { ctx in
            for (idx, pageView) in pages.enumerated() {
                ctx.beginPage()

                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fill(pageRect)

                if let hi = headerImage {
                    UIImage(cgImage: hi).draw(in: CGRect(
                        x: contentRect.minX,
                        y: contentRect.minY,
                        width: contentRect.width,
                        height: headerHeightPt
                    ))
                }

                if let fi = footerImage {
                    UIImage(cgImage: fi).draw(in: CGRect(
                        x: contentRect.minX,
                        y: pageRect.maxY - pageMargin - footerHeightPt - pageNumberReservePt,
                        width: contentRect.width,
                        height: footerHeightPt
                    ))
                }

                if drawPageNumber {
                    drawPageNumberText(
                        context: ctx.cgContext,
                        pageIndex: idx + 1,
                        pageCount: pageCount,
                        pageRect: pageRect,
                        pageMargin: pageMargin,
                        footerHeight: footerHeightPt,
                        pageNumberReservePt: pageNumberReservePt
                    )
                }

                let availableBodyHeightPt = max(contentRect.height - headerHeightPt - footerHeightPt - pageNumberReservePt, 1)

                let bodyImage = renderImage(
                    view: pageView,
                    width: contentRect.width,
                    scale: scale
                )

                guard let bi = bodyImage else { continue }

                let ui = UIImage(cgImage: bi)

                let drawRect = CGRect(
                    x: contentRect.minX,
                    y: contentRect.minY + headerHeightPt,
                    width: contentRect.width,
                    height: min(availableBodyHeightPt, CGFloat(bi.height) / scale)
                )

                ui.draw(in: drawRect)
            }
        }

        if pdfData.isEmpty { throw ExportError.renderFailed }
        return pdfData
    }

    static func drawPageNumberText(
        context: CGContext,
        pageIndex: Int,
        pageCount: Int,
        pageRect: CGRect,
        pageMargin: CGFloat,
        footerHeight: CGFloat,
        pageNumberReservePt: CGFloat
    ) {
        let text = "Page \(pageIndex) / \(pageCount)"
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let color = UIColor.black.withAlphaComponent(0.55)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let size = (text as NSString).size(withAttributes: attrs)
        let x = (pageRect.width - size.width) / 2

        let y: CGFloat
        if footerHeight > 0, pageNumberReservePt > 0 {
            let slotTopY = pageRect.maxY - pageMargin - pageNumberReservePt
            let slotHeight = pageNumberReservePt
            y = slotTopY + (slotHeight - size.height) / 2
        } else {
            let baselineHeight: CGFloat = max(14, size.height)
            let slotTopY = pageRect.maxY - pageMargin - baselineHeight
            y = slotTopY + (baselineHeight - size.height) / 2
        }

        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
    }

    @MainActor
    static func renderImage(view: AnyView, width: CGFloat, scale: CGFloat) -> CGImage? {
        let root = view
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.white)

        let renderer = ImageRenderer(content: root)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.cgImage
    }
}

// ============================================================
// MARK: - PDF Exporter: Long Content (legacy slicing; kept for compatibility)
// ============================================================

private enum ReportPDFLongContentExporter {

    enum ExportError: Error { case renderFailed }

    private static let pageNumberSlotHeightPt: CGFloat = 14
    private static let pageNumberSlotPaddingTopPt: CGFloat = 4

    @MainActor
    static func renderPDF(
        pageSize: CGSize,
        pageMargin: CGFloat,
        scale: CGFloat,
        header: AnyView?,
        footer: AnyView?,
        content: AnyView,
        drawPageNumber: Bool
    ) throws -> Data {

        let pageRect = CGRect(origin: .zero, size: pageSize)
        let contentRect = pageRect.insetBy(dx: pageMargin, dy: pageMargin)

        let headerImage = header.flatMap { ReportPDFPagesExporter.renderImage(view: $0, width: contentRect.width, scale: scale) }
        let footerImage = footer.flatMap { ReportPDFPagesExporter.renderImage(view: $0, width: contentRect.width, scale: scale) }

        let headerHeightPt: CGFloat = headerImage.map { CGFloat($0.height) / scale } ?? 0
        let footerHeightPt: CGFloat = footerImage.map { CGFloat($0.height) / scale } ?? 0

        let pageNumberReservePt: CGFloat = {
            guard drawPageNumber else { return 0 }
            guard footerHeightPt > 0 else { return 0 }
            return pageNumberSlotPaddingTopPt + pageNumberSlotHeightPt
        }()

        guard let bodyImage = ReportPDFPagesExporter.renderImage(view: content, width: contentRect.width, scale: scale) else {
            throw ExportError.renderFailed
        }

        let availableBodyHeightPt = max(contentRect.height - headerHeightPt - footerHeightPt - pageNumberReservePt, 1)
        let pageBodyHeightPx = Int((availableBodyHeightPt * scale).rounded())

        let imageHeightPx = bodyImage.height
        let pageCount = max(1, Int(ceil(Double(imageHeightPx) / Double(pageBodyHeightPx))))

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let pdfData = pdfRenderer.pdfData { ctx in
            for pageIndex in 0..<pageCount {
                ctx.beginPage()

                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fill(pageRect)

                if let hi = headerImage {
                    UIImage(cgImage: hi).draw(in: CGRect(
                        x: contentRect.minX,
                        y: contentRect.minY,
                        width: contentRect.width,
                        height: headerHeightPt
                    ))
                }

                if let fi = footerImage {
                    UIImage(cgImage: fi).draw(in: CGRect(
                        x: contentRect.minX,
                        y: pageRect.maxY - pageMargin - footerHeightPt - pageNumberReservePt,
                        width: contentRect.width,
                        height: footerHeightPt
                    ))
                }

                if drawPageNumber {
                    ReportPDFPagesExporter.drawPageNumberText(
                        context: ctx.cgContext,
                        pageIndex: pageIndex + 1,
                        pageCount: pageCount,
                        pageRect: pageRect,
                        pageMargin: pageMargin,
                        footerHeight: footerHeightPt,
                        pageNumberReservePt: pageNumberReservePt
                    )
                }

                let yPx = pageIndex * pageBodyHeightPx
                let sliceHeightPx = min(pageBodyHeightPx, imageHeightPx - yPx)
                if sliceHeightPx <= 0 { continue }

                let cropRect = CGRect(x: 0, y: yPx, width: bodyImage.width, height: sliceHeightPx)
                guard let slice = bodyImage.cropping(to: cropRect) else { continue }

                let sliceHeightPt = CGFloat(sliceHeightPx) / scale
                let bodyDrawRect = CGRect(
                    x: contentRect.minX,
                    y: contentRect.minY + headerHeightPt,
                    width: contentRect.width,
                    height: sliceHeightPt
                )

                UIImage(cgImage: slice).draw(in: bodyDrawRect)
            }
        }

        if pdfData.isEmpty { throw ExportError.renderFailed }
        return pdfData
    }
}

// MARK: - Preview
#Preview {
    ReportExportFlow(
        fileName: "Test",
        pdfPages: {
            [
                AnyView(Text("Page 1").padding(.top, 200)),
                AnyView(Text("Page 2").padding(.top, 200))
            ]
        },
        pageHeader: { AnyView(Text("Header").font(.headline).padding(.bottom, 8)) },
        pageFooter: { AnyView(Text("Footer / Disclaimer").font(.caption).padding(.top, 8)) },
        onClose: {}
    )
    .environmentObject(HealthStore.preview())
    .environmentObject(SettingsModel.shared)
}
