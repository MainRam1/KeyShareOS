import SwiftUI

/// Design tokens for spacing, sizing, colors, and typography.
enum UIConstants {

    // MARK: - Spacing

    static let sidebarPadding: CGFloat = 12
    static let contentPadding: CGFloat = 24
    static let itemSpacing: CGFloat = 6
    static let sectionSpacing: CGFloat = 16
    static let gridSpacing: CGFloat = 12

    // MARK: - Sizing

    static let sidebarWidth: CGFloat = 220
    static let keyMinSize: CGFloat = 80
    static let keyMaxSize: CGFloat = 140
    static let keyDefaultSize: CGFloat = 80
    static let keyCornerRadius: CGFloat = 12
    static let sidebarItemCornerRadius: CGFloat = 8
    static let sidebarItemHeight: CGFloat = 36
    static let keyIconSize: CGFloat = 36

    static let windowDefaultWidth: CGFloat = 720
    static let windowDefaultHeight: CGFloat = 500
    static let windowMinWidth: CGFloat = 620
    static let windowMinHeight: CGFloat = 420

    /// Keys stay at 80px until window exceeds default, then scale up to 140px.
    static func computedKeySize(for availableWidth: CGFloat) -> CGFloat {
        let totalPadding = contentPadding * 2
        let totalSpacing = gridSpacing * 2
        let usableWidth = availableWidth - totalPadding - totalSpacing
        let rawSize = usableWidth / 3
        return min(keyMaxSize, max(keyMinSize, rawSize))
    }

    /// Scales linearly from keyMinSize to keyMaxSize.
    static func scaled(_ baseValue: CGFloat, for keySize: CGFloat) -> CGFloat {
        let ratio = keySize / keyMinSize
        return baseValue * ratio
    }

    // MARK: - Colors

    static let sidebarBackground = Color.primary.opacity(0.06)
    static let sidebarActiveBackground = Color.accentColor.opacity(0.15)
    static let sidebarHoverBackground = Color.primary.opacity(0.08)
    static let keyBackground = Color.secondary.opacity(0.08)
    static let keyActiveBackground = Color.secondary.opacity(0.15)
    static let separatorColor = Color.primary.opacity(0.08)

    // MARK: - Fonts

    static let sidebarItemFont: Font = .system(.body, design: .default).weight(.medium)
    static let sidebarTabFont: Font = .system(.callout, design: .default).weight(.medium)
    static let keyNumberFont: Font = .system(.caption2, design: .default).weight(.semibold)
    static let keyActionFont: Font = .system(.callout, design: .default).weight(.medium)
    static let keyAppNameFont: Font = .system(.caption2, design: .default)
    static let sectionHeaderFont: Font = .system(.title3, design: .default).weight(.semibold)
}
