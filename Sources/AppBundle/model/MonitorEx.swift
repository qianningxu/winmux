import AppKit

extension Monitor {
    @MainActor
    var workspaceSidebarInset: CGFloat {
        guard config.workspaceSidebar.enabled else { return 0 }
        guard workspaceSidebarResolvedPanelMonitors().contains(where: { $0.rect.topLeftCorner == rect.topLeftCorner }) else {
            return 0
        }
        let scopeId = workspaceSidebarMonitorScopeId(for: self)
        let visibleWidth = WorkspaceSidebarPanel.panel(for: scopeId)?.viewModel.workspaceSidebarVisibleWidth
        let reservedWidth = max(
            visibleWidth ?? CGFloat(config.workspaceSidebar.collapsedWidth),
            CGFloat(config.workspaceSidebar.collapsedWidth)
        )
        return reservedWidth
    }

    @MainActor
    var visibleRectPaddedByOuterGaps: Rect {
        let topLeft = visibleRect.topLeftCorner
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: self)
        let sidebarInset = workspaceSidebarInset
        let minimumOuterGap = sidebarInset > 0
            ? WorkspaceSidebarSideAreaMetrics.standard.minimumWindowCanvasOuterGap
            : 0
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        let leftInset = sidebarInset > 0
            ? metrics.windowCanvasLeftInset(visibleWidth: sidebarInset, userOuterLeftGap: gaps.outer.left.toDouble())
            : max(gaps.outer.left.toDouble(), minimumOuterGap)
        let topInset = max(gaps.outer.top.toDouble(), minimumOuterGap)
        let rightInset = max(gaps.outer.right.toDouble(), minimumOuterGap)
        let bottomInset = max(gaps.outer.bottom.toDouble(), minimumOuterGap)
        return Rect(
            topLeftX: topLeft.x + leftInset,
            topLeftY: topLeft.y + topInset,
            width: visibleRect.width - leftInset - rightInset,
            height: visibleRect.height - topInset - bottomInset,
        )
    }

    @MainActor
    var monitorId_oneBased: Int? {
        sortedMonitors.firstIndex { $0.rect.topLeftCorner == rect.topLeftCorner }.map { $0 + 1 }
    }
}
