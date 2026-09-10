import AppKit

extension WindowMouseInteractionDriver {
    func startResize(windowId: UInt32) {
        let session = ResizeSession(windowId: windowId)
        let isNewSession = resizeSession != session
        logWindowDragLive("resize.start window=\(windowId) isNewSession=\(isNewSession) existingSession=\(String(describing: resizeSession)) mouseDown=\(isLeftMouseButtonDown) kind=\(getCurrentMouseManipulationKind())")
        if isNewSession, let window = Window.get(byId: windowId), window.lastAppliedLayoutPhysicalRect == nil {
            if let candidate = pendingResizeCandidate, candidate.windowId == windowId {
                window.lastAppliedLayoutPhysicalRect = candidate.baseRect
            } else if let anchor = draggedWindowAnchorRect(for: windowId) {
                window.lastAppliedLayoutPhysicalRect = liveResizeWindowContentRect(
                    groupRect: anchor, isTabGroup: getCurrentMouseDragSubject() == .group)
            }
        }
        if isNewSession {
            cancelLiveResizeFrameWrites()
            clearResizePointerConstraints()
        }
        setCurrentMouseManipulationKind(.resize)
        WindowTabStripPanelController.shared.setIgnoresMouseEvents(true)
        moveSession = nil
        dragSourcePreviewState = nil
        if isNewSession {
            resetResizeTrackingState()
            clearPendingWindowDragIntent()
            WindowResizePreviewPanel.shared.hide(reason: "native-live-resize")
            WindowMouseInteractionOpacityController.shared.restore()
        }
        resizeSession = session
        currentlyManipulatedWithMouseWindowId = windowId
        configureResizeChrome(windowId: windowId)
        startDisplayLoop()
        sampleResizeFrame(force: true)
    }

    func configureResizeChrome(windowId: UInt32) {
        guard let window = Window.get(byId: windowId) else {
            logWindowDragLive("resize.configureChrome missing-window window=\(windowId)")
            WindowTabStripPanelController.shared.hideChromeDuringMouseInteraction()
            return
        }
        WindowTabStripPanelController.shared.showChromeDuringMouseInteraction()
        if resizeGesture == nil {
            let sample = MousePointerTracker.shared.currentSample
            resizeGesture = makeResizeGesture(window: window, observedRect: window.lastKnownActualRect, sample: sample)
        }
        refreshResizePointerConstraints(window: window)
        guard let rect = window.lastKnownActualRect ??
            window.lastAppliedLayoutPhysicalRect
        else { return }
        beginStableResizePreviewFrame(for: window)
        updateResizePreviewIfNeeded(window: window, rect: rect, force: true)
    }

    func resetResizeTrackingState() {
        resizeGesture = nil
        isResizeSampleInFlight = false
        isMouseUpResetScheduled = false
        lastRenderedResizePreviewRect = nil
    }
}
