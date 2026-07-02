import SwiftUI

extension WorkspaceSidebarView {
    @ViewBuilder
    func sidebarTopBar(
        expansionProgress: CGFloat,
        isCompact: Bool,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
    ) -> some View {
        if isCompact {
            compactSidebarPinButton(expansionProgress: expansionProgress)
                .padding(.leading, leadingInset)
                .padding(.trailing, trailingInset)
                .padding(.top, snapshot.configuration.topPadding)
                .padding(.bottom, 6)
        } else {
            expandedSidebarTopBar(expansionProgress: expansionProgress)
                .padding(.leading, leadingInset)
                .padding(.trailing, trailingInset)
                .padding(.top, snapshot.configuration.topPadding)
                .padding(.bottom, workspaceSidebarSectionGap)
        }
    }

    func expandedSidebarTopBar(expansionProgress: CGFloat) -> some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        return HStack(alignment: .top, spacing: 6) {
            Text("WinMux")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.foreground(0.82))
                .lineLimit(1)
                .frame(height: 26, alignment: .center)
            Spacer(minLength: 0)
            sidebarNewFolderButton(isCompact: false)
            sidebarPinButton(expansionProgress: expansionProgress, isCompact: false)
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration), height: workspaceSidebarControlHeight)
    }

    func compactSidebarPinButton(expansionProgress: CGFloat) -> some View {
        HStack(spacing: 0) {
            sidebarNewFolderButton(isCompact: true)
            sidebarPinButton(expansionProgress: expansionProgress, isCompact: true)
        }
            .frame(width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration), height: workspaceSidebarWorkspaceSectionHeightCompact)
    }

    func sidebarPinButton(expansionProgress _: CGFloat, isCompact: Bool) -> some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        let isPinned = snapshot.isPinnedExpanded
        return Button {
            actions.send(.setPinnedExpanded(!isPinned))
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                .foregroundStyle(isPinned ? palette.foreground(0.88) : palette.foreground(0.68))
                .frame(width: isCompact ? workspaceSidebarBadgeWidth : 26, height: isCompact ? workspaceSidebarBadgeWidth : 26)
                .background {
                    if isPinned {
                        RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                            .fill(palette.gray100(palette.isDark ? 0.20 : 0.95))
                            .overlay {
                                RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                                    .strokeBorder(palette.border(palette.isDark ? 0.55 : 0.78), lineWidth: 0.8)
                            }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Unpin sidebar" : "Keep sidebar expanded")
        .accessibilityLabel(isPinned ? "Unpin sidebar" : "Keep sidebar expanded")
    }

    func sidebarNewFolderButton(isCompact: Bool) -> some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        return Button {
            actions.send(.createFolder)
        } label: {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                .foregroundStyle(palette.foreground(0.70))
                .frame(width: isCompact ? workspaceSidebarBadgeWidth : 26, height: isCompact ? workspaceSidebarBadgeWidth : 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New Folder")
        .accessibilityLabel("New Folder")
    }

    func sidebarNewTabButton(isCompact: Bool) -> some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        return Button {
            actions.send(sidebarNewTabAction())
        } label: {
            Image(systemName: "plus")
                .font(.system(size: isCompact ? 11 : 12.5, weight: .semibold))
                .foregroundStyle(palette.foreground(0.68))
                .frame(width: isCompact ? workspaceSidebarBadgeWidth : 26, height: isCompact ? workspaceSidebarBadgeWidth : 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New Tab")
        .accessibilityLabel("New Tab")
    }

    func sidebarNewTabAction() -> WorkspaceSidebarAction {
        .createWorkspace(
            projectId: snapshot.activeProjectId,
            monitorScopeId: workspaceSidebarWorkspaceCreateScope(
                selectedScopeId: snapshot.selectedMonitorScopeId,
                targetMonitorScopeId: snapshot.targetMonitorScopeId,
                focusedScopeId: snapshot.focusedMonitorScopeId,
            )
        )
    }
}
