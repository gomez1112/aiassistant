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
    //
    // A single cohesive indigo→violet brand family. Everything tinted in the
    // app derives from these, so accents read as one consistent identity.

    static let accent = Color(red: 0.39, green: 0.34, blue: 0.92)        // indigo-violet
    static let accentLight = Color(red: 0.56, green: 0.51, blue: 0.97)   // lighter violet
    static let accentDeep = Color(red: 0.26, green: 0.21, blue: 0.62)    // deep violet for gradient depth
    static let highlight = Color(red: 0.78, green: 0.36, blue: 0.86)     // violet-magenta companion
    static let highlightSoft = Color(red: 0.93, green: 0.82, blue: 0.98) // soft violet wash
    static let paywallTint = accent
    static let deep = Color(red: 0.07, green: 0.06, blue: 0.15)
    static let midground = Color(red: 0.17, green: 0.16, blue: 0.27)
    static let petal = Color(red: 0.97, green: 0.97, blue: 1.0)
    static let surface = Color.primary.opacity(0.045)
    static let surfaceElevated = Color.primary.opacity(0.065)
    static let surfaceStroke = Color.primary.opacity(0.09)
    static let surfaceStrokeStrong = Color.primary.opacity(0.14)
    static let destructive = Color(red: 0.89, green: 0.26, blue: 0.33)

    // MARK: - Gradients

    /// Primary brand gradient (indigo → violet-magenta). Used for primary
    /// actions, the send button, selected chips, and user message bubbles.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, highlight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft tinted wash used behind hero icons and feature art.
    static var brandWash: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.16), highlight.opacity(0.12)],
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
