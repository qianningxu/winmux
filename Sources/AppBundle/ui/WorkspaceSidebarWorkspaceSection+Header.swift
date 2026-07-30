import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    @ViewBuilder
    var headerButton: some View {
        Group {
            if !isCompact, !isRenamingWorkspace, !composedHeaderTabs.isEmpty {
                header
            } else {
                Button(action: handleSectionClick) {
                    header
                        .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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
        Group {
            if !isRenamingWorkspace, !composedHeaderTabs.isEmpty {
                composedExpandedHeader
            } else {
                standardExpandedHeader
            }
        }
    }

    var standardExpandedHeader: some View {
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
            if workspace.tabSummary.windowCount > 0 {
                Color.clear
                    .frame(width: isHeaderCloseButtonVisible ? workspaceSidebarWindowCloseButtonReservedWidth : 4)
            }
        }
        .padding(.leading, workspaceSidebarRowHorizontalPadding)
        .padding(.trailing, workspaceSidebarRowHorizontalPadding)
        .frame(height: workspaceSidebarTabRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            headerRowShape
                .fill(headerRowBackgroundFill)
        }
        .overlay {
            if isHeaderRowHighlighted || isPointerHoverVisible {
                headerRowShape
                    .strokeBorder(
                        palette.tabStroke(active: isHeaderRowHighlighted),
                        lineWidth: isHeaderRowHighlighted ? 1.0 : 0.5
                    )
            }
        }
        .shadow(
            color: .clear,
            radius: 0,
            x: 0,
            y: 0
        )
    }

    var composedExpandedHeader: some View {
        HStack(spacing: 4) {
            ForEach(composedHeaderTabs) { tab in
                composedHeaderTab(tab, showsTitle: composedHeaderShowsTitles)
            }
        }
        .frame(height: workspaceSidebarTabRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var composedHeaderTabs: [WorkspaceSidebarWindowViewModel] {
        guard workspace.tabSummary.windowCount > 1 else { return [] }
        return workspace.items.flatMap { item -> [WorkspaceSidebarWindowViewModel] in
            switch item.kind {
                case .window(let window):
                    return [window]
                case .tabGroup(let group):
                    return group.tabs
            }
        }
    }

    var composedHeaderShowsTitles: Bool {
        composedHeaderTabs.count <= 2
    }

    func composedHeaderTab(_ tab: WorkspaceSidebarWindowViewModel, showsTitle: Bool) -> some View {
        Button {
            handleComposedHeaderTabClick(tab)
        } label: {
            HStack(spacing: showsTitle ? 5 : 0) {
                composedHeaderTabIcon(tab)
                if showsTitle {
                    Text(composedHeaderTabTitle(tab))
                        .font(.system(size: 13.5, weight: tab.isFocused ? .semibold : .medium))
                        .foregroundStyle(tab.isFocused ? palette.foreground(1) : palette.foreground(0.86))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.72)
                }
            }
            .padding(.horizontal, showsTitle ? workspaceSidebarRowHorizontalPadding : 0)
            .frame(height: workspaceSidebarTabRowHeight)
            .frame(maxWidth: .infinity, alignment: showsTitle ? .leading : .center)
            .background {
                headerRowShape
                    .fill(composedHeaderTabFill(tab))
            }
            .overlay {
                if isPointerHoverVisible || tab.isFocused {
                    headerRowShape
                        .strokeBorder(composedHeaderTabStroke(tab), lineWidth: tab.isFocused ? 1.0 : 0.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(composedHeaderTabTitle(tab))
    }

    @ViewBuilder
    func composedHeaderTabIcon(_ tab: WorkspaceSidebarWindowViewModel) -> some View {
        if let icon = appIconImage(
            bundleIdentifier: tab.appBundleId,
            bundlePath: tab.appBundlePath
        ) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                .cornerRadius(4)
                .workspaceSidebarIconStroke(palette, cornerRadius: 4, isActive: tab.isFocused)
        } else {
            Image(systemName: "macwindow")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.foreground(0.70))
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
        }
    }

    func composedHeaderTabTitle(_ tab: WorkspaceSidebarWindowViewModel) -> String {
        if !tab.appName.isEmpty {
            return tab.appName
        }
        return tab.title?.takeIf { !$0.isEmpty } ?? "Window"
    }

    func composedHeaderTabFill(_ tab: WorkspaceSidebarWindowViewModel) -> Color {
        if tab.isFocused {
            return palette.selectedSurface()
        }
        if isPointerHoverVisible {
            return palette.tabHoverSurface()
        }
        if isPinnedActiveWorkspace {
            return palette.gray100(palette.isDark ? 0.54 : 0.78)
        }
        return Color.clear
    }

    func composedHeaderTabStroke(_ tab: WorkspaceSidebarWindowViewModel) -> Color {
        if tab.isFocused || isHeaderRowHighlighted {
            return palette.tabStroke(active: true)
        }
        return palette.tabStroke(active: false).opacity(0.72)
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
                .workspaceSidebarIconStroke(palette, isActive: isVisuallyActiveOnTargetMonitor)
        }
    }

    var isHeaderRowSelected: Bool {
        !showsWindowRows && !isSearchFiltering && (isVisuallyActiveOnTargetMonitor || isPinnedActiveWorkspace)
    }

    var isHeaderRowHighlighted: Bool {
        workspaceSidebarHeaderRowIsHighlighted(
            isSelected: isHeaderRowSelected,
            isReorderSource: isWorkspaceReorderSource
        )
    }

    var headerRowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    var headerRowBackgroundFill: Color {
        if isHeaderRowHighlighted {
            return palette.selectedSurface()
        }
        if isPointerHoverVisible {
            return palette.tabHoverSurface()
        }
        return Color.clear
    }

    var isHeaderCloseButtonVisible: Bool {
        workspaceSidebarTabCloseButtonIsVisible(
            isCompact: isCompact,
            isRenamingWorkspace: isRenamingWorkspace,
            isPointerHoverVisible: isPointerHoverVisible,
            windowCount: workspace.tabSummary.windowCount
        )
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
                .workspaceSidebarIconStroke(palette, isActive: isVisuallyActiveOnTargetMonitor)
        } else {
            workspaceBadge
                .font(.system(size: 12, weight: isVisuallyActiveOnTargetMonitor ? .bold : .semibold))
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
        }
    }
}

func workspaceSidebarTabCloseButtonIsVisible(
    isCompact: Bool,
    isRenamingWorkspace: Bool,
    isPointerHoverVisible: Bool,
    windowCount: Int
) -> Bool {
    !isCompact && !isRenamingWorkspace && isPointerHoverVisible && windowCount > 0
}
