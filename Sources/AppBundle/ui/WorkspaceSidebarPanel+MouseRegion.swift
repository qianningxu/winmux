import AppKit

extension WorkspaceSidebarPanel {
    func updateMousePassthrough() {
        let inside = isMouseInsideInteractiveRegion()
        let shouldIgnoreMouseEvents = !inside
        if ignoresMouseEvents != shouldIgnoreMouseEvents {
            debugWorkspaceSidebarHoverLog("mousePassthrough panel=\(monitorScopeId) ignores \(ignoresMouseEvents)->\(shouldIgnoreMouseEvents) insideVisible=\(inside) visibleWidth=\(viewModel.workspaceSidebarVisibleWidth) frame=\(frame) mouse=\(NSEvent.mouseLocation)")
            ignoresMouseEvents = shouldIgnoreMouseEvents
        }
    }

    func isMouseInsideHoverRegion() -> Bool {
        guard isVisible else { return false }
        let hoverWidth = max(
            viewModel.workspaceSidebarVisibleWidth,
            CGFloat(config.workspaceSidebar.collapsedWidth),
        ) + WorkspaceSidebarSideAreaMetrics.standard.outerInset + hoverExitTolerance
        let hoverRegion = NSRect(x: frame.minX, y: frame.minY, width: hoverWidth, height: frame.height)
        let inside = hoverRegion.contains(NSEvent.mouseLocation)
        if viewModel.workspaceSidebarVisibleWidth > CGFloat(config.workspaceSidebar.collapsedWidth) + 0.5 || pendingCollapse != nil {
            debugWorkspaceSidebarHoverLog("hoverRegion panel=\(monitorScopeId) inside=\(inside) hoverWidth=\(hoverWidth) visibleWidth=\(viewModel.workspaceSidebarVisibleWidth) frame=\(frame) mouse=\(NSEvent.mouseLocation) suppressUntil=\(splitBrowseCollapseSuppressedUntil)")
        }
        return inside
    }

    func isMouseInsideInteractiveRegion() -> Bool {
        guard isVisible else { return false }
        return isPointInsideInteractiveRegion(NSEvent.mouseLocation)
    }

    func isPointInsideInteractiveRegion(_ point: CGPoint) -> Bool {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        return metrics.edgeTriggerFrame(in: frame).contains(point) ||
            sideAreaBackgroundFrame().contains(point)
    }

    func isMouseInsideVisibleRegion() -> Bool {
        guard isVisible else { return false }
        return sideAreaBackgroundFrame().contains(NSEvent.mouseLocation)
    }

    func isMouseDeepEnoughToExpand(collapsedWidth: CGFloat) -> Bool {
        guard isVisible else { return false }
        return isWorkspaceSidebarHoverDeepEnoughToExpand(
            mouseX: NSEvent.mouseLocation.x,
            sidebarMinX: frame.minX,
            collapsedWidth: collapsedWidth + WorkspaceSidebarSideAreaMetrics.standard.outerInset,
        )
    }

    func visualSidebarFrame() -> NSRect {
        WorkspaceSidebarSideAreaMetrics.standard.visualSidebarFrame(
            in: frame,
            visibleWidth: viewModel.workspaceSidebarVisibleWidth
        )
    }

    func sideAreaBackgroundFrame() -> NSRect {
        WorkspaceSidebarSideAreaMetrics.standard.sideAreaBackgroundFrame(
            in: frame,
            visibleWidth: viewModel.workspaceSidebarVisibleWidth,
            expandedWidth: CGFloat(config.workspaceSidebar.width)
        )
    }
}
