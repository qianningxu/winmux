import AppKit
import SwiftUI

private let workspaceCanvasBackgroundPanelId = "WinMux.workspaceCanvasBackground"

@MainActor
final class WorkspaceCanvasBackgroundPanel: NSPanelHud {
    private static var panelsByMonitorScopeId: [String: WorkspaceCanvasBackgroundPanel] = [:]

    private let hostingView: NSHostingView<WorkspaceCanvasBackgroundView>
    private let monitorScopeId: String
    private var projectThemeFamily: WorkspaceSidebarProjectThemeFamily?
    private var theme: AppearanceTheme
    private var cornerRadius: CGFloat = 0

    private init(monitor: Monitor) {
        monitorScopeId = workspaceSidebarMonitorScopeId(for: monitor)
        let projectThemeFamily = workspaceCanvasProjectThemeFamily(
            activeProjectId: activeWorkspaceProjectId(for: monitor),
            projectColors: config.workspaceSidebar.projectColors
        )
        self.projectThemeFamily = projectThemeFamily
        let theme = AppearanceTheme.current
        self.theme = theme
        hostingView = NSHostingView(rootView: WorkspaceCanvasBackgroundView(
            projectThemeFamily: projectThemeFamily,
            reserveHeight: CGFloat(config.workspaceSidebar.menuBarReserveHeight),
            theme: theme
        ))
        super.init()
        identifier = NSUserInterfaceItemIdentifier("\(workspaceCanvasBackgroundPanelId).\(monitorScopeId)")
        hasShadow = false
        isOpaque = false
        backgroundColor = WinMuxDesignTokens.transparentNSColor
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

    static func refreshAll(themeOverride: AppearanceTheme? = nil) {
        var active = Set<String>()
        for monitor in sortedMonitors {
            let id = workspaceSidebarMonitorScopeId(for: monitor)
            active.insert(id)
            let panel = panelsByMonitorScopeId[id] ?? WorkspaceCanvasBackgroundPanel(monitor: monitor)
            panelsByMonitorScopeId[id] = panel
            panel.refresh(on: monitor, themeOverride: themeOverride)
        }
        for id in Array(panelsByMonitorScopeId.keys) where !active.contains(id) {
            panelsByMonitorScopeId.removeValue(forKey: id)?.close()
        }
    }

    static func hideAll() {
        for panel in panelsByMonitorScopeId.values {
            panel.orderOut(nil)
        }
    }

    static func removeAll() {
        let retainedPanels = Array(panelsByMonitorScopeId.values)
        panelsByMonitorScopeId = [:]
        for panel in retainedPanels {
            panel.close()
        }
    }

    private func refresh(on monitor: Monitor, themeOverride: AppearanceTheme?) {
        guard TrayMenuModel.shared.isEnabled,
              config.workspaceSidebar.enabled,
              let screen = workspaceSidebarScreen(for: monitor),
              !shouldSuppressWorkspaceSidebarForFullscreenContent()
        else {
            orderOut(nil)
            return
        }
        let projectThemeFamily = workspaceCanvasProjectThemeFamily(
            activeProjectId: activeWorkspaceProjectId(for: monitor),
            projectColors: config.workspaceSidebar.projectColors
        )
        let theme = themeOverride ?? AppearanceTheme.current
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.minY,
            width: screen.frame.width,
            height: max(screen.frame.maxY - workspaceSidebarTopBarHeight(for: screen) - screen.visibleFrame.minY, 1)
        )
        let radius = projectFrameCornerRadius(on: monitor)
        if self.projectThemeFamily != projectThemeFamily || self.theme != theme || cornerRadius != radius {
            self.projectThemeFamily = projectThemeFamily
            self.theme = theme
            cornerRadius = radius
            hostingView.rootView = WorkspaceCanvasBackgroundView(
                projectThemeFamily: projectThemeFamily,
                reserveHeight: CGFloat(config.workspaceSidebar.menuBarReserveHeight),
                theme: theme,
                cornerRadius: radius
            )
        }
        if self.frame != frame {
            setFrame(frame, display: true, animate: false)
        }
        orderFrontRegardless()
    }

}

func workspaceCanvasBackgroundFrame(
    sidebarFrame _: NSRect,
    screenFrame: NSRect
) -> NSRect {
    screenFrame
}

struct WorkspaceCanvasBackgroundView: View {
    let projectThemeFamily: WorkspaceSidebarProjectThemeFamily?
    let reserveHeight: CGFloat
    let theme: AppearanceTheme
    var cornerRadius = WinMuxBarStyle.topBarSurfaceCornerRadius

    private var frameShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        let palette = WinMuxOverlayPalette(
            theme: theme,
            projectThemeFamily: projectThemeFamily
        )
        ZStack(alignment: .topLeading) {
            frameShape
                .fill(palette.color(.gray, .color6))
            Rectangle()
                .fill(palette.color(.gray, .color3))
                .padding(.top, WinMuxBarStyle.projectBarHeight)
        }
        .clipShape(frameShape)
        .overlay {
            frameShape
                .strokeBorder(palette.color(.gray, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
        }
        .accessibilityLabel("Project frame")
        .allowsHitTesting(false)
        .background {
            WinMuxDesignTokens.transparent
        }
    }
}

func workspaceCanvasProjectThemeFamily(
    activeProjectId: WorkspaceProjectId,
    projectColors: [String: String]
) -> WorkspaceSidebarProjectThemeFamily? {
    WorkspaceSidebarProjectThemeFamily.resolve(
        configuredHex: projectColors[activeProjectId.rawValue]
    )
}

func workspaceCanvasBackground(for palette: WinMuxOverlayPalette) -> Color {
    palette.color(.gray, .color6)
}

/// Use one enclosing radius for all four corners, accommodating native windows.
@MainActor
func projectFrameCornerRadius(on monitor: Monitor) -> CGFloat {
    let fallback = WinMuxBarStyle.topBarSurfaceCornerRadius
    guard let screen = workspaceSidebarScreen(for: monitor) else { return fallback }
    let frame = screen.visibleFrame
    var result = fallback
    for window in monitor.activeWorkspace.allLeafWindowsRecursive where !window.isFloating && !window.isHiddenInCorner {
        guard let rect = window.lastKnownActualRect?.toAppKitScreenRect else { continue }
        let bottomInset = rect.minY - frame.minY
        guard bottomInset >= 0, bottomInset <= WinMuxSpacing.regular + WinMuxBarStyle.strokeWidth else { continue }
        let touchesLeft = abs(rect.minX - screen.frame.minX - bottomInset) <= WinMuxBarStyle.strokeWidth
        let touchesRight = abs(screen.frame.maxX - rect.maxX - bottomInset) <= WinMuxBarStyle.strokeWidth
        if touchesLeft || touchesRight {
            result = max(result, estimatedWindowPreviewCornerRadius(for: window.windowId) + bottomInset)
        }
    }
    return result
}
