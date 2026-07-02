import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    var headerButton: some View {
        Button(action: handleSectionClick) {
            header
                .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, headerButtonLeadingIndent)
        .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var header: some View {
        Group {
            if isCompact {
                compactTabBadge
            } else {
                expandedHeader
            }
        }
    }

    var headerButtonLeadingIndent: CGFloat {
        isCompact || nestedContentIndent <= 0 ? 0 : nestedContentIndent
    }

    var expandedHeader: some View {
        HStack(spacing: workspaceSidebarAppIconTextSpacing) {
            expandedTabIcon
            if isRenamingWorkspace {
                WorkspaceSidebarWorkspaceRenameField(
                    text: $renamingWorkspaceText,
                    workspaceName: workspace.name,
                    onCommit: onCommitRenameWorkspace,
                    onCancel: onCancelRenameWorkspace,
                )
                .layoutPriority(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.displayName)
                        .font(.system(size: 13.5, weight: isVisuallyActiveOnTargetMonitor ? .semibold : .medium))
                        .foregroundStyle(isVisuallyActiveOnTargetMonitor ? palette.foreground(1) : palette.foreground(0.86))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle = workspace.tabSummary.subtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(palette.foreground(0.50))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .contentShape(Rectangle())
                .layoutPriority(1)
            }
            if let projectContextLabel, let projectContextColor {
                Text(projectContextLabel)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(projectContextColor.opacity(0.86))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 15)
                    .background {
                        Capsule(style: .continuous)
                            .fill(projectContextColor.opacity(0.13))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(projectContextColor.opacity(0.24), lineWidth: 0.5)
                    }
            }
            Spacer(minLength: 0)
            if headerCloseTargetWindow != nil {
                Color.clear
                    .frame(width: workspaceSidebarWindowCloseButtonReservedWidth)
            }
        }
        .padding(.leading, workspaceSidebarRowHorizontalPadding)
        .padding(.trailing, workspaceSidebarRowHorizontalPadding)
        .frame(height: workspaceSidebarTabRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            headerRowShape
                .fill(headerRowBackgroundFill)
            if isHovered && !isHeaderRowSelected {
                headerRowShape
                    .fill(palette.contrastingFill(darkOpacity: 0.035, lightOpacity: 0.03))
            }
        }
        .overlay {
            if isHeaderRowSelected {
                headerRowShape
                    .strokeBorder(palette.border(palette.isDark ? 0.76 : 0.90), lineWidth: 0.8)
            }
        }
        .shadow(
            color: palette.shadow(0.14, lightOpacity: 0.08),
            radius: isHeaderRowSelected ? 1.5 : 0,
            x: 0,
            y: isHeaderRowSelected ? 0.5 : 0
        )
    }

    @ViewBuilder
    var expandedTabIcon: some View {
        if let icon = appIconImage(
            bundleIdentifier: workspace.tabSummary.appBundleId,
            bundlePath: workspace.tabSummary.appBundlePath
        ) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                .cornerRadius(4)
                .opacity(isVisuallyActiveOnTargetMonitor ? 1 : 0.88)
        }
    }

    var isHeaderRowSelected: Bool {
        !showsWindowRows && !isSearchFiltering && (isVisuallyActiveOnTargetMonitor || isPinnedActiveWorkspace)
    }

    var headerRowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    var headerRowBackgroundFill: Color {
        isHeaderRowSelected ? palette.selectedSurface() : Color.clear
    }

    var headerCloseTargetWindow: WorkspaceSidebarWindowViewModel? {
        guard workspace.tabSummary.windowCount == 1 else { return nil }
        for item in workspace.items {
            switch item.kind {
                case .window(let window):
                    return window
                case .tabGroup(let group):
                    if group.tabs.count == 1 {
                        return group.tabs[0]
                    }
            }
        }
        return nil
    }

    var isHeaderCloseButtonVisible: Bool {
        !isCompact &&
            !isRenamingWorkspace &&
            isHovered &&
            headerCloseTargetWindow != nil
    }

    var compactTabBadge: some View {
        Group {
            if workspace.tabSummary.isEmpty {
                workspaceBadge
            } else {
                tabIcon
            }
        }
        .frame(width: workspaceSidebarBadgeWidth, height: workspaceSidebarBadgeWidth)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    var tabIcon: some View {
        if let icon = appIconImage(
            bundleIdentifier: workspace.tabSummary.appBundleId,
            bundlePath: workspace.tabSummary.appBundlePath
        ) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                .cornerRadius(4)
                .opacity(isVisuallyActiveOnTargetMonitor ? 1 : 0.88)
        } else {
            workspaceBadge
                .font(.system(size: 12, weight: isVisuallyActiveOnTargetMonitor ? .bold : .semibold))
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
        }
    }
}
