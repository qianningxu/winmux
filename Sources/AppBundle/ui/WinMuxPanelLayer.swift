import AppKit

enum WinMuxPanelLayer: CaseIterable {
    case workspaceBackground
    case windowChrome
    case windowIntentPreview
    case overlay
    case dragCursorProxy
    case menuBarSurface
    case workspaceSidebar
    case workspaceSidebarActionMenu

    var level: NSWindow.Level {
        switch self {
            case .workspaceBackground:
                NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
            case .windowChrome:
                .normal
            case .windowIntentPreview:
                .statusBar
            case .overlay:
                .statusBar
            case .dragCursorProxy:
                NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            case .menuBarSurface:
                // Keep both bars below Notification Center banners (level 21).
                NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
            case .workspaceSidebar:
                NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
            case .workspaceSidebarActionMenu:
                .screenSaver
        }
    }
}

extension NSPanelHud {
    func applyWinMuxLayer(_ layer: WinMuxPanelLayer) {
        level = layer.level
    }
}
