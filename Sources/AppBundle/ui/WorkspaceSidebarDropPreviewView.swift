import AppKit
import SwiftUI

struct WorkspaceSidebarDropPreviewView: View {
    let preview: WorkspaceSidebarDropPreviewViewModel
    let rowHeight: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    private var sectionShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarSectionCornerRadius, style: .continuous)
    }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    var body: some View {
        if preview.targetsNewWorkspace {
            newWorkspacePreview
        } else {
            previewRows
                .padding(.leading, workspaceSidebarWindowRowsLeadingIndent)
                .allowsHitTesting(false)
        }
    }

    private var newWorkspacePreview: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: workspaceSidebarHeaderSpacing) {
                Text("New Tab")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.leading, workspaceSidebarHeaderRowLeadingPadding)
            .padding(.trailing, workspaceSidebarRowHorizontalPadding)
            .frame(height: rowHeight + 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            previewRows
                .padding(.leading, workspaceSidebarWindowRowsLeadingIndent)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, workspaceSidebarSectionInnerHorizontalInset)
        .background(sectionShape.fill(palette.gray100(palette.isDark ? 0.90 : 1)))
        .overlay {
            sectionShape.strokeBorder(
                palette.tabStroke(active: true),
                lineWidth: 0.9
            )
        }
        .shadow(color: palette.shadow(0.10, lightOpacity: 0.035), radius: 4, x: 0, y: 1)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var previewRows: some View {
        if preview.isTabGroup {
            VStack(alignment: .leading, spacing: 1) {
                tabGroupHeaderRow
                ForEach(Array(preview.tabItems.enumerated()), id: \.offset) { _, tab in
                    singleWindowRow(
                        title: tab.title,
                        appBundleIdentifier: tab.appBundleIdentifier,
                        appBundlePath: tab.appBundlePath
                    )
                    .padding(.leading, workspaceSidebarTabGroupChildLeadingIndent)
                }
            }
        } else {
            singleWindowRow(
                title: preview.label,
                appBundleIdentifier: preview.appBundleIdentifier,
                appBundlePath: preview.appBundlePath
            )
        }
    }

    private var tabGroupHeaderRow: some View {
        let icons = preview.tabItems.map { ($0.appBundleIdentifier, $0.appBundlePath) }
        return HStack(spacing: 6) {
            if !icons.isEmpty {
                HStack(spacing: -3) {
                    ForEach(Array(icons.prefix(4).enumerated()), id: \.offset) { _, icon in
                        if let image = appIconImage(bundleIdentifier: icon.0, bundlePath: icon.1) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .cornerRadius(3)
                                .workspaceSidebarIconStroke(palette, cornerRadius: 3, isActive: true)
                        }
                    }
                }
            }
            Text(preview.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.foreground(0.82))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, workspaceSidebarRowHorizontalPadding)
        .padding(.vertical, 1)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowShape.fill(palette.gray200(palette.isDark ? 0.84 : 0.92)))
        .overlay {
            rowShape.strokeBorder(palette.tabStroke(active: true), lineWidth: 0.8)
        }
    }

    private func singleWindowRow(
        title: String,
        appBundleIdentifier: String?,
        appBundlePath: String?
    ) -> some View {
        HStack(spacing: 6) {
            if let icon = appIconImage(bundleIdentifier: appBundleIdentifier, bundlePath: appBundlePath) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .cornerRadius(3)
                    .workspaceSidebarIconStroke(palette, cornerRadius: 3)
            }
            Text(title)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(palette.foreground(0.78))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, workspaceSidebarRowHorizontalPadding)
        .padding(.vertical, 1)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowShape.fill(palette.gray100(palette.isDark ? 0.72 : 0.84)))
        .overlay {
            rowShape.strokeBorder(palette.tabStroke(), lineWidth: 0.75)
        }
    }
}
