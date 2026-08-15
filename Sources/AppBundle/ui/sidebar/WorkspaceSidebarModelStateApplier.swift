import AppKit

@MainActor
func clearWorkspaceSidebarModelState() {
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarWorkspaces, to: [])
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarMonitorScopes, to: [])
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarProjects, to: [])
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarShowsMonitorSelector, to: false)
    WorkspaceSidebarPanel.refreshAll()
}

@MainActor
func applyWorkspaceSidebarModelState(_ state: WorkspaceSidebarModelState, previousTopPadding: CGFloat) {
    let didMonitorScopeChange =
        TrayMenuModel.shared.workspaceSidebarMonitorScopes != state.monitorScopes ||
        TrayMenuModel.shared.workspaceSidebarFocusedMonitorScopeId != state.focusedMonitorScopeId ||
        TrayMenuModel.shared.workspaceSidebarShowsMonitorSelector != state.showsMonitorSelector
    let didProjectChange =
        TrayMenuModel.shared.workspaceSidebarProjects != state.projects ||
        TrayMenuModel.shared.workspaceSidebarActiveProjectId != state.activeProjectId

    updateWorkspaceSidebarTrayModel(with: state)
    WorkspaceSidebarPanel.syncVisiblePanelModelsFromShared()
    let didWorkspaceChange = TrayMenuModel.shared.setIfChanged(\.workspaceSidebarWorkspaces, to: state.workspaces)
    if didWorkspaceChange {
        WorkspaceSidebarPanel.syncVisiblePanelModelsFromShared()
    }
    if didWorkspaceChange ||
        state.topPadding != previousTopPadding ||
        didMonitorScopeChange ||
        didProjectChange ||
        WorkspaceSidebarPanel.visiblePanels.isEmpty
    {
        WorkspaceSidebarPanel.refreshAll()
    }
}

@MainActor
private func updateWorkspaceSidebarTrayModel(with state: WorkspaceSidebarModelState) {
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarTopPadding, to: state.topPadding)
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarHoveredWorkspaceName, to: state.hoveredWorkspaceName)
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarProjects, to: state.projects)
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarActiveProjectId, to: state.activeProjectId)
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarMonitorScopes, to: state.monitorScopes)
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarFocusedMonitorScopeId, to: state.focusedMonitorScopeId)
    TrayMenuModel.shared.setIfChanged(\.workspaceSidebarShowsMonitorSelector, to: state.showsMonitorSelector)
}
