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
        return HStack(spacing: 6) {
            Text("Tabs")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.foreground(0.82))
                .lineLimit(1)
            Spacer(minLength: 0)
            sidebarNewTabGroupButton(isCompact: false)
            sidebarPinButton(expansionProgress: expansionProgress, isCompact: false)
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration), height: workspaceSidebarControlHeight)
    }

    func compactSidebarPinButton(expansionProgress: CGFloat) -> some View {
        sidebarPinButton(expansionProgress: expansionProgress, isCompact: true)
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
                .foregroundStyle(isPinned ? Color.accentColor.opacity(0.95) : palette.foreground(0.68))
                .frame(width: isCompact ? workspaceSidebarBadgeWidth : 26, height: isCompact ? workspaceSidebarBadgeWidth : 26)
                .background {
                    if isPinned {
                        RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.13))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Unpin sidebar" : "Keep sidebar expanded")
        .accessibilityLabel(isPinned ? "Unpin sidebar" : "Keep sidebar expanded")
    }

    func sidebarNewTabGroupButton(isCompact: Bool) -> some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        return Button {
            actions.send(.createTabGroup)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: isCompact ? 11 : 12.5, weight: .semibold))
                .foregroundStyle(palette.foreground(0.68))
                .frame(width: isCompact ? workspaceSidebarBadgeWidth : 26, height: isCompact ? workspaceSidebarBadgeWidth : 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New tab group")
        .accessibilityLabel("New tab group")
    }
}
