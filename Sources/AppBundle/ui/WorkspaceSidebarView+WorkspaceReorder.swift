import SwiftUI

extension WorkspaceSidebarView {
    func isWorkspaceReorderEnabled(
        workspace _: WorkspaceSidebarWorkspaceViewModel,
        expansionProgress: CGFloat,
        isPinnedActiveWorkspace: Bool,
        isInteractive: Bool
    ) -> Bool {
        workspaceSidebarWorkspaceReorderIsEnabled(
            isCompact: expansionProgress < workspaceSidebarRowsRevealProgress,
            isSearchFiltering: !searchText.isEmpty,
            isRenamingWorkspace: renamingWorkspaceName != nil || renamingProjectId != nil,
            isPinnedActiveWorkspace: isPinnedActiveWorkspace,
            isInteractive: isInteractive
        )
    }

    func isWorkspaceReorderSource(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> Bool {
        workspaceReorderDrag?.sourceWorkspaceName == workspace.name &&
            workspaceReorderDrag?.projectId == workspace.projectId
    }

    func workspaceReorderInsertionPlacement(
        for workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId
    ) -> WorkspaceReorderPlacement? {
        guard let target = workspaceReorderDrag?.target,
              target.projectId == projectId,
              target.targetWorkspaceName == workspace.name
        else { return nil }
        return target.placement
    }

    func showsWorkspaceReorderIndicator(
        before workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId
    ) -> Bool {
        guard let placement = workspaceReorderInsertionPlacement(for: workspace, projectId: projectId) else { return false }
        if case .before(let targetName) = placement {
            return targetName == workspace.name
        }
        return false
    }

    func showsWorkspaceReorderIndicator(
        after workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId
    ) -> Bool {
        guard let placement = workspaceReorderInsertionPlacement(for: workspace, projectId: projectId) else { return false }
        if case .after(let targetName) = placement {
            return targetName == workspace.name
        }
        return false
    }

    func workspaceReorderIndicator(expansionProgress: CGFloat) -> some View {
        WorkspaceSidebarWorkspaceReorderIndicator(
            width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration)
        )
    }

    func updateWorkspaceReorderDrag(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId,
        pointer: CGPoint
    ) {
        if workspaceReorderDrag == nil {
            NotificationCenter.default.post(name: workspaceSidebarDismissProjectMenusNotification, object: nil)
            isProjectMenuOpen = false
        }
        let target = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: workspace.name,
            projectId: projectId,
            pointer: pointer,
            frames: workspaceReorderFrames
        )
        workspaceReorderDrag = WorkspaceSidebarWorkspaceReorderDragState(
            sourceWorkspaceName: workspace.name,
            projectId: projectId,
            pointer: pointer,
            target: target
        )
    }

    func finishWorkspaceReorderDrag(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId,
        pointer: CGPoint
    ) {
        let target = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: workspace.name,
            projectId: projectId,
            pointer: pointer,
            frames: workspaceReorderFrames
        ) ?? workspaceReorderDrag?.target
        workspaceReorderDrag = nil
        guard let target, target.projectId == projectId else { return }
        actions.send(.reorderWorkspace(
            workspace.name,
            projectId: projectId,
            placement: target.placement
        ))
    }

    func cancelWorkspaceReorderDrag() {
        workspaceReorderDrag = nil
    }
}
