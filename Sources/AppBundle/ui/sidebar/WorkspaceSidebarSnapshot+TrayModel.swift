import Foundation

@MainActor
func workspaceSidebarSnapshot(from model: TrayMenuModel) -> WorkspaceSidebarSnapshot {
    WorkspaceSidebarSnapshot(
        workspaces: model.workspaceSidebarWorkspaces,
        projects: model.workspaceSidebarProjects,
        activeProjectId: model.workspaceSidebarActiveProjectId,
        monitorScopes: model.workspaceSidebarMonitorScopes,
        selectedMonitorScopeId: model.workspaceSidebarSelectedMonitorScopeId,
        targetMonitorScopeId: model.workspaceSidebarTargetMonitorScopeId,
        focusedMonitorScopeId: model.workspaceSidebarFocusedMonitorScopeId,
        visibleWidth: model.workspaceSidebarVisibleWidth,
        isPinnedExpanded: model.isWorkspaceSidebarPinnedExpanded,
        hoveredWorkspaceName: model.workspaceSidebarHoveredWorkspaceName,
        dropPreview: model.workspaceSidebarDropPreview,
        configuration: workspaceSidebarConfiguration(),
    )
}
