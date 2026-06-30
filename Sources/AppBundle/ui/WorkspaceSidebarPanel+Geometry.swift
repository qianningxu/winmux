import AppKit

struct WorkspaceSidebarPanelLayout {
    let frame: NSRect
    let expandedWidth: CGFloat
    let collapsedWidth: CGFloat
    let metrics: WorkspaceSidebarSideAreaMetrics
}

extension WorkspaceSidebarPanel {
    func currentSidebarPanelLayout() -> WorkspaceSidebarPanelLayout? {
        currentSidebarPanelLayout(on: workspaceSidebarResolvedPanelMonitor())
    }

    func currentSidebarPanelLayout(on monitor: Monitor) -> WorkspaceSidebarPanelLayout? {
        guard TrayMenuModel.shared.isEnabled,
              config.workspaceSidebar.enabled,
              let screen = workspaceSidebarPanelScreen(for: monitor)
        else { return nil }
        guard !shouldSuppressWorkspaceSidebarForFullscreenContent() else { return nil }

        let sidebarConfig = config.workspaceSidebar
        let expandedWidth = CGFloat(sidebarConfig.width)
        let collapsedWidth = CGFloat(sidebarConfig.collapsedWidth)
        guard expandedWidth > 0, collapsedWidth > 0 else { return nil }

        return WorkspaceSidebarPanelLayout(
            frame: workspaceSidebarPanelFrame(
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                width: screen.visibleFrame.width,
                extraTopReserveHeight: CGFloat(sidebarConfig.menuBarReserveHeight)
            ),
            expandedWidth: expandedWidth,
            collapsedWidth: collapsedWidth,
            metrics: .standard,
        )
    }

    func workspaceSidebarPanelScreen() -> NSScreen? {
        workspaceSidebarPanelScreen(for: workspaceSidebarResolvedPanelMonitor())
    }

    func workspaceSidebarPanelScreen(for monitor: Monitor) -> NSScreen? {
        workspaceSidebarScreen(for: monitor)
    }
}

func workspaceSidebarScreen(for monitor: Monitor) -> NSScreen? {
    NSScreen.screens.getOrNil(
        atIndex: monitor.monitorAppKitNsScreenScreensId - 1
    ) ?? NSScreen.screens.first
}

func workspaceSidebarPanelFrame(
    screenFrame: NSRect,
    visibleFrame: NSRect,
    width: CGFloat,
    extraTopReserveHeight: CGFloat,
) -> NSRect {
    let visibleMinX = min(max(visibleFrame.minX, screenFrame.minX), screenFrame.maxX - 1)
    let visibleMaxX = min(max(visibleFrame.maxX, visibleMinX + 1), screenFrame.maxX)
    let clampedWidth = min(max(width, 1), max(visibleMaxX - visibleMinX, 1))
    let visibleMaxY = min(max(visibleFrame.maxY, screenFrame.minY + 1), screenFrame.maxY)
    let visibleMinY = min(max(visibleFrame.minY, screenFrame.minY), visibleMaxY - 1)
    let builtInTopInset = max(screenFrame.maxY - visibleMaxY, 0)
    let additionalTopReserve = max(extraTopReserveHeight - builtInTopInset, 0)
    let topReserve = min(max(additionalTopReserve, 0), max(visibleMaxY - visibleMinY - 1, 0))
    let maxY = max(visibleMaxY - topReserve, visibleMinY + 1)
    let height = max(maxY - visibleMinY, 1)
    return NSRect(
        x: visibleMinX,
        y: visibleMinY,
        width: clampedWidth,
        height: height,
    )
}
