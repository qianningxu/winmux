import Common

@MainActor
@discardableResult
func normalizeSystemOverlayWindow(_ window: Window, level: MacOsWindowLevel?) -> Bool {
    guard level?.isSystemOverlay == true else { return false }
    // Also repair helpers restored from layouts saved before overlay filtering.
    let emptiedWorkspace = workspaceToCloseAfterClosingLastWindow(window)
    window.layoutReason = .standard
    window.bind(to: macosPopupWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    closeWorkspaceIfEmptiedByLastWindowClosure(emptiedWorkspace)
    return true
}
