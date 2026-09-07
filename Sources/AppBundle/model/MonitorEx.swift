import AppKit

extension Monitor {
    @MainActor
    var workspaceSidebarInset: CGFloat {
        // The sidebar is hosted in the menu-bar safe region and no longer
        // consumes horizontal canvas space.
        0
    }

    @MainActor
    var visibleRectPaddedByOuterGaps: Rect {
        let topLeft = visibleRect.topLeftCorner
        let gaps = ResolvedGaps(gaps: config.gaps, monitor: self)
        let topBarOverlap = workspaceSidebarTopBarVisibleOverlap(for: self)
        let leftInset = max(gaps.outer.left.toDouble(), 0)
        // `visibleRect` already starts at the native menu-bar boundary. The
        // floating surface begins `topBarOverlap` below that boundary and
        // extends another `menuBarFloatingSurfaceOutset` below its configured
        // bar, so reserve both portions before laying out app windows.
        // Otherwise the tab strip can sit underneath the last few points of
        // the top bar and its upper edge is clipped.
        let topBarReservation = topBarOverlap + menuBarFloatingSurfaceOutset
        let topInset = max(gaps.outer.top.toDouble(), topBarReservation)
        let rightInset = max(gaps.outer.right.toDouble(), 0)
        let bottomInset = max(gaps.outer.bottom.toDouble(), 0)
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
