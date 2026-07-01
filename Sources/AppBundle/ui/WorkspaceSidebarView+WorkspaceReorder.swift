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
              case .reorder(let reorderTarget) = target,
              reorderTarget.projectId == projectId,
              reorderTarget.targetWorkspaceName == workspace.name
        else { return nil }
        return reorderTarget.placement
    }

    func workspaceMergePosition(
        for workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId
    ) -> WindowStackSplitPosition? {
        guard let target = workspaceReorderDrag?.target,
              case .merge(let mergeTarget) = target,
              mergeTarget.projectId == projectId,
              mergeTarget.targetWorkspaceName == workspace.name
        else { return nil }
        return mergeTarget.position
    }

    func isWorkspaceMergeTarget(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> Bool {
        workspaceMergePosition(for: workspace, projectId: workspace.projectId) != nil
    }

    func workspaceMergePreviewTitle(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> String? {
        guard let position = workspaceMergePosition(for: workspace, projectId: workspace.projectId) else { return nil }
        return switch position {
            case .left: "Merge Left"
            case .right: "Merge Right"
            case .above: "Merge Above"
            case .below: "Merge Below"
        }
    }

    func workspaceMergePreviewSubtitle(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> String? {
        guard let position = workspaceMergePosition(for: workspace, projectId: workspace.projectId) else { return nil }
        return switch position {
            case .left: "Release to merge this Tab on the left"
            case .right: "Release to merge this Tab on the right"
            case .above: "Release to merge this Tab above"
            case .below: "Release to merge this Tab below"
        }
    }

    func workspaceMergePreviewIsPositive(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> Bool {
        workspaceMergePosition(for: workspace, projectId: workspace.projectId)?.isPositive == true
    }

    func workspaceMergePreviewAlignment(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> Alignment {
        guard let position = workspaceMergePosition(for: workspace, projectId: workspace.projectId) else {
            return .center
        }
        return switch position {
            case .left: .leading
            case .right: .trailing
            case .above: .top
            case .below: .bottom
        }
    }

    func workspaceMergePreviewTextPadding(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> EdgeInsets {
        guard let position = workspaceMergePosition(for: workspace, projectId: workspace.projectId) else {
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
        let horizontalPadding: CGFloat = 9
        let verticalPadding: CGFloat = 6
        return switch position {
            case .left:
                EdgeInsets(top: verticalPadding, leading: horizontalPadding, bottom: verticalPadding, trailing: 0)
            case .right:
                EdgeInsets(top: verticalPadding, leading: 0, bottom: verticalPadding, trailing: horizontalPadding)
            case .above:
                EdgeInsets(top: verticalPadding, leading: horizontalPadding, bottom: 0, trailing: horizontalPadding)
            case .below:
                EdgeInsets(top: 0, leading: horizontalPadding, bottom: verticalPadding, trailing: horizontalPadding)
        }
    }

    func workspaceMergePreviewText(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> some View {
        VStack(alignment: workspaceMergePreviewIsPositive(workspace) ? .trailing : .leading, spacing: 2) {
            if let title = workspaceMergePreviewTitle(workspace) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
            }
            if let subtitle = workspaceMergePreviewSubtitle(workspace) {
                Text(subtitle)
                    .font(.system(size: 8.5, weight: .medium))
                    .lineLimit(1)
                    .opacity(0.74)
            }
        }
        .padding(workspaceMergePreviewTextPadding(workspace))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: workspaceMergePreviewAlignment(workspace))
    }

    func workspaceMergePreviewOverlay(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> some View {
        ZStack(alignment: workspaceMergePreviewAlignment(workspace)) {
            RoundedRectangle(cornerRadius: workspaceSidebarSectionCornerRadius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.52), lineWidth: 1)
                .background {
                    RoundedRectangle(cornerRadius: workspaceSidebarSectionCornerRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                }
            workspaceMergePreviewText(workspace)
                .foregroundStyle(Color.accentColor.opacity(0.95))
        }
        .allowsHitTesting(false)
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
        let target = workspaceSidebarWorkspaceDragTarget(
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
        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: workspace.name,
            projectId: projectId,
            pointer: pointer,
            frames: workspaceReorderFrames
        ) ?? workspaceReorderDrag?.target
        workspaceReorderDrag = nil
        guard let target else {
            mergeWorkspaceIntoActiveViewFromSidebarIfPossible(
                sourceWorkspaceName: workspace.name,
                pointer: pointer
            )
            return
        }
        switch target {
            case .reorder(let reorderTarget):
                guard reorderTarget.projectId == projectId else { return }
                actions.send(.reorderWorkspace(
                    workspace.name,
                    projectId: projectId,
                    placement: reorderTarget.placement
                ))
            case .merge(let mergeTarget):
                guard mergeTarget.projectId == projectId,
                      mergeTarget.sourceWorkspaceName == workspace.name
                else { return }
                actions.send(.mergeWorkspace(
                    mergeTarget.sourceWorkspaceName,
                    intoWorkspace: mergeTarget.targetWorkspaceName,
                    position: mergeTarget.position
                ))
        }
    }

    func cancelWorkspaceReorderDrag() {
        workspaceReorderDrag = nil
    }
}
