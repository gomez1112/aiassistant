// Views/Theme/AppTheme.swift
// ai.assistant
//
// Shared visual styling for the app.

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum AppTheme {
    // MARK: - Colors

    static let accent = Color(red: 0.10, green: 0.36, blue: 0.72)
    static let accentLight = Color(red: 0.32, green: 0.58, blue: 0.86)
    static let highlight = Color(red: 0.12, green: 0.56, blue: 0.48)
    static let highlightSoft = Color(red: 0.68, green: 0.86, blue: 0.82)
    static let deep = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let midground = Color(red: 0.17, green: 0.20, blue: 0.25)
    static let petal = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let surface = Color.primary.opacity(0.045)
    static let surfaceElevated = Color.primary.opacity(0.065)
    static let surfaceStroke = Color.primary.opacity(0.095)
    static let surfaceStrokeStrong = Color.primary.opacity(0.14)
    static let destructive = Color(red: 0.72, green: 0.16, blue: 0.14)

    static var appBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color.primary.opacity(0.03)
        #endif
    }

    static var surfaceFill: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.white
        #endif
    }

    // Semantic colors
    static let success = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.30)

    // MARK: - Corner Radii

    static let radiusBubble: CGFloat = 16
    static let radiusCard: CGFloat = 8
    static let radiusSmall: CGFloat = 8
    static let radiusChip: CGFloat = 18

    // MARK: - Layout

    static let readableContentWidth: CGFloat = 760
    static let minimumTapTarget: CGFloat = 44

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
}

// MARK: - App Background

struct AppBackground: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.groupedBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Surface Modifier

struct AppSurface: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.radiusCard

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.surfaceFill)
            )
            .overlay(surfaceStroke)
    }

    private var surfaceStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
    }
}

extension View {
    func appSurface(cornerRadius: CGFloat = AppTheme.radiusCard) -> some View {
        modifier(AppSurface(cornerRadius: cornerRadius))
    }
}
