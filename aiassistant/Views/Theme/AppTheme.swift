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

    static let accent = Color(red: 0.91, green: 0.47, blue: 0.45)
    static let accentLight = Color(red: 0.97, green: 0.63, blue: 0.58)
    static let highlight = Color(red: 0.96, green: 0.69, blue: 0.35)
    static let highlightSoft = Color(red: 1.0, green: 0.84, blue: 0.60)
    static let deep = Color(red: 0.14, green: 0.11, blue: 0.14)
    static let midground = Color(red: 0.22, green: 0.18, blue: 0.22)
    static let petal = Color(red: 0.98, green: 0.95, blue: 0.96)
    static let surface = Color.primary.opacity(0.06)
    static let surfaceElevated = Color.primary.opacity(0.10)
    static let surfaceStroke = Color.primary.opacity(0.12)
    static let surfaceStrokeStrong = Color.primary.opacity(0.20)

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
                Color(red: 0.84, green: 0.37, blue: 0.44),
                Color(red: 0.94, green: 0.52, blue: 0.50)
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

    static let radiusBubble: CGFloat = 20
    static let radiusCard: CGFloat = 16
    static let radiusSmall: CGFloat = 12
    static let radiusChip: CGFloat = 24

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
                        AppTheme.accent.opacity(0.14),
                        Color.clear,
                        AppTheme.highlight.opacity(0.11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay {
                RadialGradient(
                    colors: [AppTheme.accent.opacity(0.20), .clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .overlay {
                RadialGradient(
                    colors: [AppTheme.highlight.opacity(0.15), .clear],
                    center: .bottomTrailing,
                    startRadius: 40,
                    endRadius: 500
                )
            }
            .overlay(alignment: .top) {
                // Soft concentric ring echoing the app icon motif.
                Circle()
                    .stroke(AppTheme.accent.opacity(0.07), lineWidth: 56)
                    .frame(width: 520, height: 520)
                    .blur(radius: 20)
                    .offset(y: -260)
            }
            .ignoresSafeArea()
    }
}

// MARK: - Surface Modifier

struct AppSurface: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.radiusCard

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.surfaceStroke, lineWidth: 0.6)
            )
            .shadow(color: AppTheme.accent.opacity(0.10), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func appSurface(cornerRadius: CGFloat = AppTheme.radiusCard) -> some View {
        modifier(AppSurface(cornerRadius: cornerRadius))
    }
}
