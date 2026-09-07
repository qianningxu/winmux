import AppKit

private let windowTabGroupShellHorizontalInsetValue = WinMuxBarStyle.containerInset
private let windowTabGroupShellTopInsetValue = WinMuxBarStyle.containerInset * 2
private let windowTabGroupShellBottomInsetValue = WinMuxBarStyle.containerInset
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
    guard let screen = NSScreen.main else { return windowTabBarMinimumHeightValue }
    return max(workspaceSidebarTopBarHeight(for: screen) - menuBarContentTopInset, 1)
}
