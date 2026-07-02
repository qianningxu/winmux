import AppKit
import Common
import SwiftUI

// MARK: - Window Row

struct WorkspaceSidebarWindowRow: View {
    enum Style {
        case window
        case tabGroupHeader
        case tabGroupChild
    }

    let title: String
    let badge: String?
    let isFocused: Bool
    let suppressFocusedStyle: Bool
    let rowHeight: CGFloat
    let isHovered: Bool
    let style: Style
    let appBundleIds: [String?]
    let appBundlePaths: [String?]
    let reservesCloseButtonSpace: Bool
    let leadingContentInset: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var isTabGroupHeader: Bool { style == .tabGroupHeader }
    private var isTabGroupChild: Bool { style == .tabGroupChild }
    private var isActiveRow: Bool { isFocused && !suppressFocusedStyle }
    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: workspaceSidebarAppIconTextSpacing) {
            if leadingContentInset > 0 {
                Color.clear
                    .frame(width: leadingContentInset)
            }
            appIconStack
            Text(title)
                .font(.system(size: rowTitleFontSize, weight: rowTitleWeight))
                .foregroundStyle(rowTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.foreground(isTabGroupHeader ? 0.50 : 0.38))
            }
            if reservesCloseButtonSpace {
                Color.clear
                    .frame(width: workspaceSidebarWindowCloseButtonReservedWidth)
            }
        }
        .padding(.horizontal, workspaceSidebarRowHorizontalPadding)
        .padding(.vertical, 1)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            rowShape
                .fill(rowBackgroundFill)
            if isHovered && !isActiveRow {
                rowShape
                    .fill(rowHoverOverlayFill)
            }
        }
        .overlay {
            if showsRowStroke {
                rowShape
                    .strokeBorder(rowBorderColor, lineWidth: isActiveRow ? 0.95 : 0.75)
            }
        }
        .shadow(
            color: activeRowShadowColor,
            radius: isActiveRow && !isTabGroupHeader ? 1.5 : 0,
            x: 0,
            y: isActiveRow && !isTabGroupHeader ? 0.5 : 0
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var appIconStack: some View {
        if isTabGroupHeader {
            HStack(spacing: -3) {
                ForEach(Array(appIconInputs.prefix(4).enumerated()), id: \.offset) { _, input in
                    appIcon(input)
                }
            }
        } else if let input = appIconInputs.first {
            appIcon(input)
        }
    }

    private var appIconInputs: [(String?, String?)] {
        Array(zip(appBundleIds, appBundlePaths)).filter { $0.0 != nil || $0.1 != nil }
    }

    private func appIcon(_ input: (String?, String?)) -> some View {
        Group {
            if let icon = appIconImage(bundleIdentifier: input.0, bundlePath: input.1) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: rowIconSize, height: rowIconSize)
                    .cornerRadius(isTabGroupChild ? 4 : 3)
                    .opacity(rowIconOpacity)
                    .workspaceSidebarIconStroke(
                        palette,
                        cornerRadius: isTabGroupChild ? 4 : 3,
                        isActive: isActiveRow
                    )
            }
        }
    }

    private var rowTitleFontSize: CGFloat {
        13.5
    }

    private var rowTitleWeight: Font.Weight {
        if isActiveRow {
            return .semibold
        }
        return .medium
    }

    private var rowIconSize: CGFloat {
        workspaceSidebarAppIconSize + 2
    }

    private var rowTextColor: Color {
        if isActiveRow {
            return palette.foreground(isTabGroupHeader ? 0.96 : 1)
        }
        if isTabGroupChild {
            return palette.foreground(0.86)
        }
        return palette.foreground(0.78)
    }

    private var rowIconOpacity: Double {
        1
    }

    private var rowBackgroundFill: Color {
        if isActiveRow, !isTabGroupHeader {
            return palette.selectedSurface()
        }
        return Color.clear
    }

    private var rowHoverOverlayFill: Color {
        palette.tabHoverSurface()
    }

    private var showsRowStroke: Bool {
        isHovered || (isActiveRow && !isTabGroupHeader)
    }

    private var rowBorderColor: Color {
        palette.tabStroke(active: isActiveRow && !isTabGroupHeader)
    }

    private var activeRowShadowColor: Color {
        palette.shadow(0.14, lightOpacity: 0.08)
    }
}

// MARK: - Drop Preview Row

struct WorkspaceSidebarPreviewRow: View {
    let preview: WorkspaceSidebarDropPreviewViewModel
    let expansionProgress: CGFloat
    let rowHeight: CGFloat
    let expandedContentWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(palette.gray200(palette.isDark ? 0.86 : 0.94))
                Image(systemName: preview.isTabGroup ? "square.stack.3d.up.fill" : "macwindow")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(palette.foreground(0.68))
            }
            .frame(width: 18, height: 18)
            .opacity(0.92)

            Text(preview.label)
                .font(.system(size: 11.2, weight: .semibold))
                .foregroundStyle(palette.foreground(0.82))
                .lineLimit(1)
                .opacity(max(expansionProgress, 0.12))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, workspaceSidebarRowHorizontalPadding)
        .padding(.vertical, 1.5)
        .frame(height: rowHeight + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                .fill(palette.selectedSurface(palette.isDark ? 0.86 : 0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                        .strokeBorder(
                            palette.tabStroke(active: true),
                            lineWidth: 0.9
                        )
                }
        )
        .shadow(color: palette.shadow(0.10, lightOpacity: 0.035), radius: 4, y: 1)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }
}
