import AppKit

private let windowTabGroupShellHorizontalInsetValue = WinMuxSpacing.compact
private let windowTabGroupShellTopInsetValue = WinMuxSpacing.none
private let windowTabGroupShellBottomInsetValue = WinMuxSpacing.compact
// Match the visible height of the menu-bar surfaces.
private let windowTabBarMinimumHeightValue = workspaceSidebarTabRowHeight - standardGap * 0.5

func windowTabGroupShellHorizontalInset() -> CGFloat {
    windowTabGroupShellHorizontalInsetValue
}

func windowTabGroupShellTopInset() -> CGFloat {
    windowTabGroupShellTopInsetValue
}

func windowTabGroupShellBottomInset() -> CGFloat {
    windowTabGroupShellBottomInsetValue
}

@MainActor
func resolvedWindowTabBarHeight() -> CGFloat {
    guard NSScreen.main != nil else { return WinMuxBarStyle.workspaceBarHeight }
    return WinMuxBarStyle.workspaceBarHeight
}
