import AppKit

extension WindowMouseInteractionDriver {
    func beginStableResizePreviewFrame(for window: Window) {
        guard let workspace = window.nodeWorkspace else { return }
        WindowResizePreviewPanel.shared.beginStableFrame(workspace.workspaceMonitor.rect.toAppKitScreenRect)
    }

    func updateResizePreviewIfNeeded(window: Window, rect: Rect, force: Bool = false) {
        guard force || resizePreviewHasVisibleChange(from: lastRenderedResizePreviewRect, to: rect) else { return }
        lastRenderedResizePreviewRect = rect
        updateCompositedResizePreview(window, rect: rect)
    }

    func constrainResizePointerIfNeeded(from proposed: Rect, to bounded: Rect) {
        guard resizePreviewHasVisibleChange(from: proposed, to: bounded),
              let session = resizeSession,
              let gesture = resizeGesture,
              gesture.windowId == session.windowId
        else { return }
        let sample = MousePointerTracker.shared.currentSample
        let point = gesture.pointerPoint(constrainingTo: bounded, current: sample.point)
        guard abs(point.x - sample.point.x) >= resizePreviewVisibleChangeThreshold ||
            abs(point.y - sample.point.y) >= resizePreviewVisibleChangeThreshold
        else { return }
        CGWarpMouseCursorPosition(point)
        MousePointerTracker.shared.note(point: point, timestamp: sample.timestamp)
    }
}

func resizePreviewHasVisibleChange(from previous: Rect?, to next: Rect) -> Bool {
    guard let previous else { return true }
    return abs(previous.topLeftX - next.topLeftX) >= resizePreviewVisibleChangeThreshold ||
        abs(previous.topLeftY - next.topLeftY) >= resizePreviewVisibleChangeThreshold ||
        abs(previous.width - next.width) >= resizePreviewVisibleChangeThreshold ||
        abs(previous.height - next.height) >= resizePreviewVisibleChangeThreshold
}
