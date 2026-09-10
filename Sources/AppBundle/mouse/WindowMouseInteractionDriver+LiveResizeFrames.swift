import AppKit

extension WindowMouseInteractionDriver {
    /// Coalesce AX frame writes per window. Cancelling an in-progress AX write
    /// can leave an app with its size changed but its position unchanged.
    func enqueueLiveResizeFrame(window: Window, frame: Rect) {
        let windowId = window.windowId
        if let inFlight = liveResizeFramesInFlight[windowId],
           !resizePreviewHasVisibleChange(from: inFlight, to: frame) {
            // The newest target matches the write already in progress. Drop a
            // stale queued target instead of applying it afterward.
            pendingLiveResizeFrames.removeValue(forKey: windowId)
            return
        }
        if let pending = pendingLiveResizeFrames[windowId],
           !resizePreviewHasVisibleChange(from: pending, to: frame) {
            return
        }
        pendingLiveResizeFrames[windowId] = frame
        guard liveResizeFramesInFlight[windowId] == nil else { return }
        beginNextLiveResizeFrameWrite(windowId: windowId)
    }

    func cancelLiveResizeFrameWrites() {
        liveResizeFrameWriteGeneration &+= 1
        for task in liveResizeFrameWriteTasks.values {
            task.cancel()
        }
        liveResizeFrameWriteTasks.removeAll()
        pendingLiveResizeFrames.removeAll()
        liveResizeFramesInFlight.removeAll()
    }

    func drainLiveResizeFrameWrites() async {
        while !liveResizeFrameWriteTasks.isEmpty {
            let tasks = Array(liveResizeFrameWriteTasks.values)
            for task in tasks {
                await task.value
            }
        }
    }

    private func beginNextLiveResizeFrameWrite(windowId: UInt32) {
        guard let frame = pendingLiveResizeFrames.removeValue(forKey: windowId),
              let window = Window.get(byId: windowId)
        else {
            liveResizeFramesInFlight.removeValue(forKey: windowId)
            return
        }
        let generation = liveResizeFrameWriteGeneration
        liveResizeFramesInFlight[windowId] = frame
        if resizeSession?.windowId != windowId {
            suppressPostDragAxObserverEvents(for: [windowId])
        }

        liveResizeFrameWriteTasks[windowId] = Task { @MainActor [weak self, weak window] in
            guard let self else { return }
            guard let window else {
                liveResizeFrameWriteTasks.removeValue(forKey: windowId)
                liveResizeFramesInFlight.removeValue(forKey: windowId)
                return
            }
            let observed: Rect?
            if let macWindow = window as? MacWindow {
                try? await macWindow.setAxFrameBlocking(frame.topLeftCorner, frame.size)
                observed = try? await macWindow.getAxRect()
            } else {
                window.setAxFrame(frame.topLeftCorner, frame.size)
                observed = window.lastKnownActualRect
            }
            guard generation == liveResizeFrameWriteGeneration else { return }

            if let observed {
                window.lastKnownActualRect = observed
                if resizeSession?.windowId == windowId {
                    WindowTabStripPanelController.shared.updateResizingTabGroupChrome(
                        window: window, activeWindowRect: observed)
                } else {
                    WindowTabStripPanelController.shared.updateRelatedResizeChrome(
                        window: window, activeWindowRect: observed)
                }
                learnLiveResizeMinimumIfClamped(window: window, requested: frame, observed: observed)
            }
            liveResizeFrameWriteTasks.removeValue(forKey: windowId)
            liveResizeFramesInFlight.removeValue(forKey: windowId)
            beginNextLiveResizeFrameWrite(windowId: windowId)
        }
    }

    private func learnLiveResizeMinimumIfClamped(window: Window, requested: Rect, observed: Rect) {
        guard resizeSession?.windowId != window.windowId else { return }
        guard let minimum = learnedMinimumSizeAfterNativeClamp(
            current: window.minimumSize,
            requested: requested.size,
            observed: observed.size,
            tolerance: resizePreviewVisibleChangeThreshold
        ) else { return }
        window.minimumSize = minimum

        guard let sourceId = resizeSession?.windowId,
              let source = Window.get(byId: sourceId),
              let actualSourceRect = resizeGesture?.latestRect ?? source.lastKnownActualRect
        else { return }
        updateResizePreviewIfNeeded(window: source, rect: actualSourceRect, force: true)
    }
}
