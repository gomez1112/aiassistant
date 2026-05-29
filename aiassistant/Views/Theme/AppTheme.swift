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
    // MARK: - Brand Colors

    static let accent = Color(red: 0.06, green: 0.48, blue: 0.43)
    static let accentLight = Color(red: 0.16, green: 0.66, blue: 0.59)
    static let accentDeep = Color(red: 0.03, green: 0.25, blue: 0.24)
    static let highlight = Color(red: 0.72, green: 0.39, blue: 0.20)
    static let highlightSoft = Color(red: 0.96, green: 0.88, blue: 0.79)
    static let paywallTint = accent
    static let deep = Color(red: 0.08, green: 0.09, blue: 0.09)
    static let midground = Color(red: 0.19, green: 0.22, blue: 0.22)
    static let petal = Color(red: 0.98, green: 0.98, blue: 0.96)
    static let surface = Color.primary.opacity(0.035)
    static let surfaceElevated = Color.primary.opacity(0.055)
    static let surfaceStroke = Color.primary.opacity(0.10)
    static let surfaceStrokeStrong = Color.primary.opacity(0.16)
    static let destructive = Color(red: 0.89, green: 0.26, blue: 0.33)

    // MARK: - Gradients

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accentDeep, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var brandWash: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.14), highlight.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var backgroundWash: LinearGradient {
        LinearGradient(
            colors: [
                groupedBackground,
                accent.opacity(0.045),
                highlight.opacity(0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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
        Color(nsColor: .windowBackgroundColor)
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

    static var macSidebarBackground: Color {
        #if canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        groupedBackground
        #endif
    }

    // Semantic colors
    static let success = Color(red: 0.20, green: 0.78, blue: 0.55)
    static let warning = Color(red: 0.98, green: 0.68, blue: 0.22)

    // MARK: - Corner Radii

    static let radiusBubble: CGFloat = 20
    static let radiusCard: CGFloat = 14
    static let radiusSmall: CGFloat = 10
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
            .fill(AppTheme.backgroundWash)
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
            .shadow(color: Color.primary.opacity(0.035), radius: 14, y: 6)
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
