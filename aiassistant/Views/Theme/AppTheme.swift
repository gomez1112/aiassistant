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

    static let accent = Color(red: 0.11, green: 0.43, blue: 0.82)
    static let accentLight = Color(red: 0.28, green: 0.66, blue: 0.96)
    static let highlight = Color(red: 0.08, green: 0.64, blue: 0.50)
    static let highlightSoft = Color(red: 0.54, green: 0.86, blue: 0.76)
    static let deep = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let midground = Color(red: 0.17, green: 0.20, blue: 0.25)
    static let petal = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let surface = Color.primary.opacity(0.06)
    static let surfaceElevated = Color.primary.opacity(0.08)
    static let surfaceStroke = Color.primary.opacity(0.10)
    static let surfaceStrokeStrong = Color.primary.opacity(0.16)

    // Semantic colors
    static let success = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let warning = Color(red: 1.0, green: 0.76, blue: 0.30)

    // MARK: - Gradients

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var userBubbleGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent,
                Color(red: 0.18, green: 0.55, blue: 0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var warmGradient: LinearGradient {
        LinearGradient(
            colors: [highlight, highlightSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Corner Radii

    static let radiusBubble: CGFloat = 18
    static let radiusCard: CGFloat = 14
    static let radiusSmall: CGFloat = 12
    static let radiusChip: CGFloat = 24

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
    private var baseColor: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    var body: some View {
        Rectangle()
            .fill(baseColor)
            .overlay {
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.07),
                        Color.clear,
                        AppTheme.highlight.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
    }
}

// MARK: - Surface Modifier

struct AppSurface: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.radiusCard

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(surfaceStroke)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                )
                .overlay(surfaceStroke)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 5)
        }
    }

    private var surfaceStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
    }
}

extension View {
    func appSurface(cornerRadius: CGFloat = AppTheme.radiusCard) -> some View {
        modifier(AppSurface(cornerRadius: cornerRadius))
    }
}
