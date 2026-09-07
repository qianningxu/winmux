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
        isOpaque = true
        backgroundColor = WinMuxOverlayPalette(
            theme: theme,
            projectThemeFamily: projectThemeFamily
        ).colorNSColor(.gray, .color8)
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

    static func refreshAll(themeOverride _: AppearanceTheme? = nil) {
        // Keep the desktop visible behind the bars and window stacks.
        removeAll()
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
        if self.projectThemeFamily != projectThemeFamily || self.theme != theme {
            self.projectThemeFamily = projectThemeFamily
            self.theme = theme
            let palette = WinMuxOverlayPalette(
                theme: theme,
                projectThemeFamily: projectThemeFamily
            )
            backgroundColor = palette.colorNSColor(.gray, .color8)
            hostingView.rootView = WorkspaceCanvasBackgroundView(
                projectThemeFamily: projectThemeFamily,
                reserveHeight: CGFloat(config.workspaceSidebar.menuBarReserveHeight),
                theme: theme
            )
        }
        let frame = workspaceCanvasBackgroundFrame(
            sidebarFrame: .zero,
            screenFrame: screen.frame
        )
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

    var body: some View {
        let palette = WinMuxOverlayPalette(
            theme: theme,
            projectThemeFamily: projectThemeFamily
        )
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(workspaceCanvasBackground(for: palette))
                .ignoresSafeArea()
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
    palette.color(.gray, .color8)
}
