import AppKit

func nativeWindowSizeChangedForResize(from before: Rect, to after: Rect) -> Bool {
    abs(before.width - after.width) >= 1 || abs(before.height - after.height) >= 1
}

@MainActor
func liveResizeWindowContentRect(groupRect: Rect, isTabGroup: Bool) -> Rect {
    guard isTabGroup else { return groupRect }
    let side = windowTabGroupShellHorizontalInset()
    let top = resolvedWindowTabBarHeight() + windowTabGroupShellTopInset()
    return Rect(
        topLeftX: groupRect.topLeftX + side,
        topLeftY: groupRect.topLeftY + top,
        width: max(groupRect.width - side * 2, 0),
        height: max(groupRect.height - top - windowTabGroupShellBottomInset(), 0))
}
