import AppKit

struct WorkspaceSidebarPanelLayout {
    let frame: NSRect
    let expandedWidth: CGFloat
    let collapsedWidth: CGFloat
    let metrics: WorkspaceSidebarSideAreaMetrics
    let topBarRegion: NSRect
    let barHeight: CGFloat
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

        let barHeight = workspaceSidebarTopBarHeight(for: screen)
        let topBarRegion = workspaceSidebarTopBarRegion(for: screen, barHeight: barHeight)
        guard topBarRegion.width > 0, barHeight > 0 else { return nil }
        let frame = workspaceSidebarTopBarPanelFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
            barHeight: barHeight,
            extraWidth: projectActionMenuPresentationExtraWidth,
            extraHeight: projectMenuPresentationExtraHeight,
        )

        return WorkspaceSidebarPanelLayout(
            frame: frame,
            expandedWidth: frame.width,
            collapsedWidth: frame.width,
            metrics: .standard,
            topBarRegion: topBarRegion,
            barHeight: WinMuxBarStyle.projectBarHeight,
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

@MainActor
func workspaceSidebarTopBarHeight(for screen: NSScreen) -> CGFloat {
    let nativeMenuBarHeight = max(
        screen.frame.maxY - screen.visibleFrame.maxY,
        NSStatusBar.system.thickness,
    )
    return max(nativeMenuBarHeight, screen.safeAreaInsets.top)
}

@MainActor
func workspaceSidebarTopBarRegion(for screen: NSScreen, barHeight: CGFloat? = nil) -> NSRect {
    let resolvedBarHeight = max(barHeight ?? workspaceSidebarTopBarHeight(for: screen), 1)
    return workspaceSidebarTopBarRegionFrame(
        screenFrame: screen.frame,
        auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
        barHeight: resolvedBarHeight,
    )
}

@MainActor
func menuBarStatusWidgetRegion(for screen: NSScreen, barHeight: CGFloat? = nil) -> NSRect {
    let resolvedBarHeight = max(barHeight ?? workspaceSidebarTopBarHeight(for: screen), 1)
    return menuBarStatusWidgetRegionFrame(
        screenFrame: screen.frame,
        auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
        barHeight: resolvedBarHeight,
    )
}

@MainActor
func workspaceSidebarTopBarVisibleOverlap(for monitor: Monitor) -> CGFloat {
    guard let screen = workspaceSidebarScreen(for: monitor) else { return 0 }
    let barHeight = workspaceSidebarTopBarHeight(for: screen)
    guard TrayMenuModel.shared.isEnabled, config.workspaceSidebar.enabled,
          !shouldSuppressWorkspaceSidebarForFullscreenContent() else { return 0 }
    let visualSurfaceBottom = screen.frame.maxY - barHeight - WinMuxBarStyle.projectBarHeight
    return max(screen.visibleFrame.maxY - visualSurfaceBottom, 0)
}

func workspaceSidebarTopBarRegionFrame(
    screenFrame: NSRect,
    auxiliaryTopLeftArea _: NSRect?,
    barHeight: CGFloat,
) -> NSRect {
    let resolvedBarHeight = max(barHeight, 1)
    // The workspace tabs span the screen immediately below the widget row,
    // where the camera notch no longer constrains their width.
    return NSRect(
        x: screenFrame.minX,
        y: screenFrame.maxY - resolvedBarHeight - WinMuxBarStyle.projectBarHeight,
        width: screenFrame.width,
        height: WinMuxBarStyle.projectBarHeight,
    )
}

func menuBarStatusWidgetRegionFrame(
    screenFrame: NSRect,
    auxiliaryTopRightArea: NSRect?,
    barHeight: CGFloat,
) -> NSRect {
    let resolvedBarHeight = max(barHeight, 1)
    if let auxiliaryTopRightArea,
       auxiliaryTopRightArea.width > 0,
       auxiliaryTopRightArea.height > 0
    {
        return NSRect(
            x: auxiliaryTopRightArea.minX,
            y: screenFrame.maxY - resolvedBarHeight,
            width: auxiliaryTopRightArea.width,
            height: resolvedBarHeight,
        )
    }

    return NSRect(
        x: screenFrame.minX,
        y: screenFrame.maxY - resolvedBarHeight,
        width: screenFrame.width,
        height: resolvedBarHeight,
    )
}

func workspaceSidebarTopBarPanelFrame(
    screenFrame: NSRect,
    visibleFrame _: NSRect,
    auxiliaryTopLeftArea: NSRect?,
    auxiliaryTopRightArea: NSRect? = nil,
    barHeight: CGFloat,
    extraWidth: CGFloat = 0,
    extraHeight: CGFloat = 0,
) -> NSRect {
    let resolvedBarHeight = max(barHeight, 1)
    let baseRegion = workspaceSidebarTopBarRegionFrame(
        screenFrame: screenFrame,
        auxiliaryTopLeftArea: auxiliaryTopLeftArea,
        barHeight: resolvedBarHeight,
    )

    let top = min(max(baseRegion.maxY, screenFrame.minY + 1), screenFrame.maxY)
    let barBottom = min(max(baseRegion.minY, screenFrame.minY), top - 1)
    let bottom = max(screenFrame.minY, barBottom - max(extraHeight, 0))
    let maxWidth = max(screenFrame.maxX - baseRegion.minX, 1)
    let width = min(max(baseRegion.width + max(extraWidth, 0), 1), maxWidth)
    return NSRect(
        x: baseRegion.minX,
        y: bottom,
        width: width,
        height: max(top - bottom, 1),
    )
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
