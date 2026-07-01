import Foundation
import AppKit

@MainActor
func openWorkspaceSidebarFromCommand() {
    guard TrayMenuModel.shared.isEnabled, config.workspaceSidebar.enabled else { return }
    WorkspaceSidebarPanel.refreshAll()
    let focusedScopeId = TrayMenuModel.shared.workspaceSidebarFocusedMonitorScopeId
    let panel = WorkspaceSidebarPanel.panel(for: focusedScopeId)
        ?? WorkspaceSidebarPanel.visiblePanels.first
        ?? WorkspaceSidebarPanel.shared
    if panel.viewModel.isWorkspaceSidebarExpanded || panel.inlineTextEditingActive {
        if panel.viewModel.isWorkspaceSidebarPinnedExpanded {
            panel.commandExpansionLocksCollapse = false
            panel.shouldLockNextSidebarSearchExpansion = false
            panel.bufferedCommandSidebarSearchKeys = []
            removeWorkspaceSidebarCommandMouseUnlockMonitor(panel)
            return
        }
        closeWorkspaceSidebarFromCommand(panel)
        return
    }
    panel.commandExpansionLocksCollapse = true
    panel.shouldLockNextSidebarSearchExpansion = false
    panel.bufferedCommandSidebarSearchKeys = []
    installWorkspaceSidebarCommandMouseUnlockMonitor(panel)
    panel.expandSidebar(to: CGFloat(config.workspaceSidebar.width))
}

@MainActor
func closeWorkspaceSidebarFromCommand(_ panel: WorkspaceSidebarPanel) {
    panel.endInlineTextEditing()
    panel.pendingExpand?.cancel()
    panel.pendingExpand = nil
    panel.pendingCollapse?.cancel()
    panel.pendingCollapse = nil
    panel.pendingCollapseFinalize?.cancel()
    panel.pendingCollapseFinalize = nil
    NotificationCenter.default.post(name: workspaceSidebarWillCollapseNotification, object: panel)
    panel.commandExpansionLocksCollapse = false
    panel.shouldLockNextSidebarSearchExpansion = false
    panel.bufferedCommandSidebarSearchKeys = []
    removeWorkspaceSidebarCommandMouseUnlockMonitor(panel)
    guard !panel.viewModel.isWorkspaceSidebarPinnedExpanded else {
        panel.expandSidebar(to: CGFloat(config.workspaceSidebar.width))
        return
    }
    panel.animateVisibleSidebarWidth(CGFloat(config.workspaceSidebar.collapsedWidth), animation: .easeInOut(duration: panel.animationDuration))
    panel.viewModel.isWorkspaceSidebarExpanded = false
    panel.updateMousePassthrough()
}

@MainActor
private func installWorkspaceSidebarCommandMouseUnlockMonitor(_ panel: WorkspaceSidebarPanel) {
    removeWorkspaceSidebarCommandMouseUnlockMonitor(panel)
    panel.commandMouseUnlockPoint = mouseLocation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak panel] in
        guard let panel, panel.commandExpansionLocksCollapse else { return }
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak panel] event in
            Task { @MainActor in
                panel?.unlockCommandSidebarExpansionIfMouseMoved()
            }
            return event
        }
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak panel] _ in
            Task { @MainActor in
                panel?.unlockCommandSidebarExpansionIfMouseMoved()
            }
        }
        panel.commandMouseUnlockMonitors = [localMonitor, globalMonitor].compactMap { $0 }
    }
}

@MainActor
private func removeWorkspaceSidebarCommandMouseUnlockMonitor(_ panel: WorkspaceSidebarPanel) {
    for monitor in panel.commandMouseUnlockMonitors {
        NSEvent.removeMonitor(monitor)
    }
    panel.commandMouseUnlockMonitors = []
    panel.commandMouseUnlockPoint = nil
}

private let workspaceSidebarCommandMouseUnlockDistance: CGFloat = 1

extension WorkspaceSidebarPanel {
    @MainActor
    func unlockCommandSidebarExpansionIfMouseMoved() {
        guard commandExpansionLocksCollapse,
              let origin = commandMouseUnlockPoint
        else { return }
        let current = mouseLocation
        guard hypot(current.x - origin.x, current.y - origin.y) > workspaceSidebarCommandMouseUnlockDistance else { return }
        commandExpansionLocksCollapse = false
        shouldLockNextSidebarSearchExpansion = false
        inlineTextEditingLocksExpansion = false
        removeWorkspaceSidebarCommandMouseUnlockMonitor(self)
        updateHoverStateFromMousePosition()
    }
}
