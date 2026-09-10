import AppKit

private let liveResizeVerificationDelayNanoseconds: UInt64 = 24_000_000
private let liveResizeObservationPollNanoseconds: UInt64 = 8_000_000
private let liveResizeObservationPollLimit = 12

private struct LiveResizeFrameWriteResult {
    let observed: Rect?
    let confirmedClamp: Bool
}

extension WindowMouseInteractionDriver {
    /// Submit the latest native frame without waiting for the target app to
    /// acknowledge an older one. AX work is coalesced by MacApp; a quiet-time
    /// verification corrects unexpected native clamping.
    func enqueueLiveResizeFrame(window: Window, frame: Rect) {
        let windowId = window.windowId
        if let submitted = liveResizeFramesInFlight[windowId],
           !resizePreviewHasVisibleChange(from: submitted, to: frame) {
            return
        }

        let current = liveResizeFramesInFlight[windowId] ?? window.lastKnownActualRect
        if liveResizeInitialFrames[windowId] == nil, let current {
            liveResizeInitialFrames[windowId] = current
        }
        pendingLiveResizeFrames[windowId] = frame
        liveResizeFramesInFlight[windowId] = frame
        if resizeSession?.windowId != windowId {
            suppressPostDragAxObserverEvents(for: [windowId])
        }

        if let macWindow = window as? MacWindow {
            macWindow.setLiveResizeFrame(from: current, to: frame)
        } else {
            window.setAxFrame(frame.topLeftCorner, frame.size)
        }
        publishLiveResizeFrame(window: window, frame: frame)
        scheduleLiveResizeVerification(windowId: windowId, requested: frame)
    }

    func cancelLiveResizeFrameWrites() {
        liveResizeFrameWriteGeneration &+= 1
        for task in liveResizeFrameWriteTasks.values {
            task.cancel()
        }
        liveResizeFrameWriteTasks.removeAll()
        pendingLiveResizeFrames.removeAll()
        liveResizeFramesInFlight.removeAll()
        liveResizeInitialFrames.removeAll()
    }

    func drainLiveResizeFrameWrites() async {
        for task in liveResizeFrameWriteTasks.values {
            task.cancel()
        }
        let verificationTasks = Array(liveResizeFrameWriteTasks.values)
        liveResizeFrameWriteTasks.removeAll()
        for task in verificationTasks {
            await task.value
        }

        var remainingPasses = 3
        while !pendingLiveResizeFrames.isEmpty, remainingPasses > 0 {
            remainingPasses -= 1
            let targets = pendingLiveResizeFrames
            pendingLiveResizeFrames.removeAll()
            for (windowId, requested) in targets {
                guard let window = Window.get(byId: windowId) else {
                    clearLiveResizeState(windowId: windowId, requested: requested)
                    continue
                }
                let initial = liveResizeInitialFrames[windowId] ?? window.lastKnownActualRect
                let result: LiveResizeFrameWriteResult
                if let macWindow = window as? MacWindow {
                    try? await macWindow.setAxFrameBlocking(requested.topLeftCorner, requested.size)
                    result = await observeSettledLiveResizeFrame(
                        window: macWindow,
                        initial: initial,
                        requested: requested,
                        requireCurrentTarget: false)
                } else {
                    window.setAxFrame(requested.topLeftCorner, requested.size)
                    result = LiveResizeFrameWriteResult(observed: requested, confirmedClamp: false)
                }
                if let observed = result.observed {
                    publishLiveResizeFrame(window: window, frame: observed)
                    if result.confirmedClamp {
                        learnLiveResizeMinimumIfClamped(window: window, requested: requested, observed: observed)
                    }
                }
                clearLiveResizeState(windowId: windowId, requested: requested)
            }
        }
    }

    private func scheduleLiveResizeVerification(windowId: UInt32, requested: Rect) {
        liveResizeFrameWriteTasks.removeValue(forKey: windowId)?.cancel()
        let generation = liveResizeFrameWriteGeneration
        liveResizeFrameWriteTasks[windowId] = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: liveResizeVerificationDelayNanoseconds)
            } catch {
                return
            }
            guard generation == liveResizeFrameWriteGeneration,
                  liveResizeTargetIsCurrent(windowId: windowId, requested: requested),
                  let window = Window.get(byId: windowId)
            else { return }

            let result: LiveResizeFrameWriteResult
            if let macWindow = window as? MacWindow {
                result = await observeSettledLiveResizeFrame(
                    window: macWindow,
                    initial: liveResizeInitialFrames[windowId],
                    requested: requested,
                    requireCurrentTarget: true)
            } else {
                result = LiveResizeFrameWriteResult(observed: window.lastKnownActualRect, confirmedClamp: false)
            }
            guard generation == liveResizeFrameWriteGeneration,
                  liveResizeTargetIsCurrent(windowId: windowId, requested: requested)
            else { return }
            if let observed = result.observed {
                publishLiveResizeFrame(window: window, frame: observed)
                if result.confirmedClamp {
                    learnLiveResizeMinimumIfClamped(window: window, requested: requested, observed: observed)
                }
            }
            clearLiveResizeState(windowId: windowId, requested: requested)
        }
    }

    private func observeSettledLiveResizeFrame(
        window: MacWindow,
        initial: Rect?,
        requested: Rect,
        requireCurrentTarget: Bool
    ) async -> LiveResizeFrameWriteResult {
        var previous: Rect?
        var latest: Rect?
        for attempt in 0 ..< liveResizeObservationPollLimit {
            if Task.isCancelled { return LiveResizeFrameWriteResult(observed: latest, confirmedClamp: false) }
            if requireCurrentTarget,
               !liveResizeTargetIsCurrent(windowId: window.windowId, requested: requested) {
                return LiveResizeFrameWriteResult(observed: latest, confirmedClamp: false)
            }
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: liveResizeObservationPollNanoseconds)
            }
            guard !Task.isCancelled, let observed = try? await window.getAxRect() else { continue }
            if requireCurrentTarget,
               !liveResizeTargetIsCurrent(windowId: window.windowId, requested: requested) {
                return LiveResizeFrameWriteResult(observed: latest, confirmedClamp: false)
            }
            latest = observed
            if nativeLiveResizeFramesMatch(
                requested, observed, tolerance: resizePreviewVisibleChangeThreshold)
            {
                return LiveResizeFrameWriteResult(observed: observed, confirmedClamp: false)
            }
            if nativeLiveResizeClampIsConfirmed(
                initial: initial,
                requested: requested,
                previous: previous,
                observed: observed,
                tolerance: resizePreviewVisibleChangeThreshold)
            {
                return LiveResizeFrameWriteResult(observed: observed, confirmedClamp: true)
            }
            previous = observed
        }
        return LiveResizeFrameWriteResult(observed: latest, confirmedClamp: false)
    }

    private func liveResizeTargetIsCurrent(windowId: UInt32, requested: Rect) -> Bool {
        guard let current = liveResizeFramesInFlight[windowId] else { return false }
        return !resizePreviewHasVisibleChange(from: current, to: requested)
    }

    private func clearLiveResizeState(windowId: UInt32, requested: Rect) {
        guard liveResizeTargetIsCurrent(windowId: windowId, requested: requested) else { return }
        pendingLiveResizeFrames.removeValue(forKey: windowId)
        liveResizeFramesInFlight.removeValue(forKey: windowId)
        liveResizeInitialFrames.removeValue(forKey: windowId)
        liveResizeFrameWriteTasks.removeValue(forKey: windowId)
    }

    private func publishLiveResizeFrame(window: Window, frame: Rect) {
        window.lastKnownActualRect = frame
        if resizeSession?.windowId == window.windowId {
            WindowTabStripPanelController.shared.updateResizingTabGroupChrome(
                window: window, activeWindowRect: frame)
        } else {
            WindowTabStripPanelController.shared.updateRelatedResizeChrome(
                window: window, activeWindowRect: frame)
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
