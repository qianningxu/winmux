import SwiftUI

extension WorkspaceSidebarPanel {
    func animateVisibleSidebarWidth(_ width: CGFloat, animation: Animation) {
        debugWorkspaceSidebarHoverLog("animateWidth panel=\(monitorScopeId) from=\(viewModel.workspaceSidebarVisibleWidth) to=\(width) frame=\(frame) mouse=\(NSEvent.mouseLocation) ignores=\(ignoresMouseEvents) expanded=\(viewModel.isWorkspaceSidebarExpanded)")
        withAnimation(animation) {
            viewModel.workspaceSidebarVisibleWidth = width
        }
        updateMousePassthrough()
        scheduleRefreshSession(.globalObserver("workspaceSidebarWidthChanged"), optimisticallyPreLayoutWorkspaces: true)
    }

    func expandSidebar(to expandedWidth: CGFloat) {
        debugWorkspaceSidebarHoverLog("expandSidebar panel=\(monitorScopeId) target=\(expandedWidth) visible=\(viewModel.workspaceSidebarVisibleWidth) frame=\(frame) mouse=\(NSEvent.mouseLocation)")
        pendingExpand?.cancel()
        pendingExpand = nil
        guard !viewModel.isWorkspaceSidebarExpanded ||
              viewModel.workspaceSidebarVisibleWidth != expandedWidth
        else {
            updateMousePassthrough()
            return
        }
        NotificationCenter.default.post(name: workspaceSidebarWillExpandNotification, object: self)
        viewModel.setIfChanged(\.isWorkspaceSidebarExpanded, to: true)
        if !isVisible {
            refresh()
        }
        guard viewModel.workspaceSidebarVisibleWidth != expandedWidth else {
            updateMousePassthrough()
            return
        }
        animateVisibleSidebarWidth(expandedWidth, animation: .easeInOut(duration: animationDuration))
    }

    func cancelExpansionWork() {
        debugWorkspaceSidebarHoverLog("cancelExpansionWork panel=\(monitorScopeId) pendingExpand=\(pendingExpand != nil) pendingCollapse=\(pendingCollapse != nil) pendingFinalize=\(pendingCollapseFinalize != nil)")
        pendingExpand?.cancel()
        pendingExpand = nil
        pendingCollapse?.cancel()
        pendingCollapse = nil
        pendingCollapseFinalize?.cancel()
        pendingCollapseFinalize = nil
    }
}
