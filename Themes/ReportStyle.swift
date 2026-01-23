//
//  ReportStyle.swift
//  GluVibProbe
//
//  Report V1 — Global Style Tokens
//
//  Zweck:
//  - Einheitliche Typografie & Spacing für A4/PDF-Reports
//  - Einheitliche Textfarbe: Glu Primary Blue
//  - Keine Abhängigkeit von ViewModels/HealthStore
//

import SwiftUI

enum ReportStyle {

    // ============================================================
    // MARK: - Color Tokens
    // ============================================================

    /// Primary text color for ALL report text (per project rule).
    static let textColor: Color = Color.Glu.primaryBlue

    /// Subtle divider color (still in Glu blue space, but lighter).
    /// Keep report monochrome; charts may use additional colors.
    static let dividerColor: Color = Color.Glu.primaryBlue.opacity(0.22)

    // ============================================================
    // MARK: - Font Tokens (A4/PDF tuned)
    // ============================================================

    enum FontToken {
        /// Report title in header (e.g., "GluVib Metabolic & Lifestyle Report")
        static let title = Font.system(size: 15, weight: .semibold)

        /// Section titles (e.g., "Time in Range — Global Status")
        static let section = Font.system(size: 12, weight: .semibold)

        /// Primary body copy (descriptions)
        static let body = Font.system(size: 9.5, weight: .regular)

        /// Small meta lines / captions
        static let caption = Font.system(size: 8.5, weight: .regular)

        /// Numeric/value emphasis (small but strong)
        static let value = Font.system(size: 10.5, weight: .semibold)
    }

    // ============================================================
    // MARK: - Spacing Tokens (A4/PDF tuned)
    // ============================================================

    enum Spacing {
        /// Outer page padding inside A4 frame
        static let pagePadding: CGFloat = 16

        /// Standard vertical stack spacing between sections
        static let sectionGap: CGFloat = 10

        /// Tight spacing within a section block
        static let blockTight: CGFloat = 4

        /// Normal spacing within a section block
        static let block: CGFloat = 6

        /// Row spacing in grids/tables
        static let row: CGFloat = 6
    }

    // ============================================================
    // MARK: - Sizing Tokens
    // ============================================================

    enum Size {
        /// Logo size in header (print-appropriate)
        static let headerLogo: CGFloat = 28

        /// Divider thickness
        static let dividerHeight: CGFloat = 0.6
    }
}
