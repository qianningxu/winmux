import AppKit
import SwiftUI

private let workspaceCanvasBackgroundPanelId = "WinMux.workspaceCanvasBackground"

@MainActor
final class WorkspaceCanvasBackgroundPanel: NSPanelHud {
    private static var panelsByMonitorScopeId: [String: WorkspaceCanvasBackgroundPanel] = [:]

    private let hostingView: NSHostingView<WorkspaceCanvasBackgroundView>
    private let monitorScopeId: String

    private init(monitor: Monitor) {
        monitorScopeId = workspaceSidebarMonitorScopeId(for: monitor)
        hostingView = NSHostingView(rootView: WorkspaceCanvasBackgroundView())
        super.init()
        identifier = NSUserInterfaceItemIdentifier("\(workspaceCanvasBackgroundPanelId).\(monitorScopeId)")
        hasShadow = false
        ignoresMouseEvents = true
        isFloatingPanel = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        applyWinMuxLayer(.workspaceBackground)
        contentView = hostingView
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }

    static func refreshAll() {
        let monitors = workspaceSidebarResolvedPanelMonitors()
        let activeMonitorScopeIds = Set(monitors.map { workspaceSidebarMonitorScopeId(for: $0) })
        for monitor in monitors {
            let scopeId = workspaceSidebarMonitorScopeId(for: monitor)
            let panel = panelsByMonitorScopeId[scopeId] ?? WorkspaceCanvasBackgroundPanel(monitor: monitor)
            panelsByMonitorScopeId[scopeId] = panel
            panel.refresh(on: monitor)
        }
        for (scopeId, panel) in panelsByMonitorScopeId where !activeMonitorScopeIds.contains(scopeId) {
            panel.orderOut(nil)
        }
    }

    static func hideAll() {
        for panel in panelsByMonitorScopeId.values {
            panel.orderOut(nil)
        }
    }

    private func refresh(on monitor: Monitor) {
        guard TrayMenuModel.shared.isEnabled,
              config.workspaceSidebar.enabled,
              let screen = workspaceSidebarScreen(for: monitor),
              !shouldSuppressWorkspaceSidebarForFullscreenContent()
        else {
            orderOut(nil)
            return
        }
        let sidebarFrame = workspaceSidebarPanelFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            width: screen.visibleFrame.width,
            extraTopReserveHeight: CGFloat(config.workspaceSidebar.menuBarReserveHeight),
        )
        let frame = workspaceCanvasBackgroundFrame(
            sidebarFrame: sidebarFrame,
            screenFrame: screen.frame
        )
        if self.frame != frame {
            setFrame(frame, display: true, animate: false)
        }
        orderFrontRegardless()
        if let windowId = lowestNormalManagedWindowId() {
            order(.below, relativeTo: windowId)
        }
    }
}

func workspaceCanvasBackgroundFrame(
    sidebarFrame: NSRect,
    screenFrame: NSRect
) -> NSRect {
    let maxY = max(screenFrame.maxY, sidebarFrame.maxY)
    return NSRect(
        x: sidebarFrame.minX,
        y: sidebarFrame.minY,
        width: sidebarFrame.width,
        height: max(maxY - sidebarFrame.minY, 1),
    )
}

struct WorkspaceCanvasBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = WinMuxOverlayPalette(colorScheme: colorScheme)
        Rectangle()
            .fill(workspaceCanvasBackground(for: palette))
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: palette.foreground(palette.isDark ? 0.035 : 0.055), location: 0),
                        .init(color: .clear, location: 0.24),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}

func workspaceCanvasBackground(for palette: WinMuxOverlayPalette) -> Color {
    palette.canvasBackground()
}

@MainActor
private func lowestNormalManagedWindowId() -> Int? {
    let visibleWindowIds = Set(MacWindow.allWindows
        .filter { getWindowLevel(for: $0.windowId) == .normalWindow }
        .map(\.windowId))
    guard !visibleWindowIds.isEmpty else { return nil }

    let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
    guard let windowInfos = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
        return visibleWindowIds.map(Int.init).min()
    }

    return windowInfos
        .compactMap { info -> UInt32? in
            guard let rawWindowId = info[kCGWindowNumber as String] as? NSNumber,
                  let rawLayer = info[kCGWindowLayer as String] as? NSNumber,
                  MacOsWindowLevel.new(windowLevel: rawLayer.intValue) == .normalWindow
            else { return nil }
            let windowId = rawWindowId.uint32Value
            return visibleWindowIds.contains(windowId) ? windowId : nil
        }
        .last
        .map(Int.init)
}
