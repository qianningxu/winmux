import AppKit
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
            isSearchFiltering: isSidebarSearchFiltering,
            isRenamingWorkspace: renamingWorkspaceName != nil || renamingProjectId != nil,
            isPinnedActiveWorkspace: isPinnedActiveWorkspace,
            isInteractive: isInteractive
        )
    }

    func isWorkspaceReorderSource(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> Bool {
        workspaceReorderDrag?.sourceWorkspaceName == workspace.name &&
            workspaceReorderDrag?.projectId == workspace.projectId
    }

    func isFolderReorderEnabled(
        projectId: WorkspaceProjectId,
        expansionProgress: CGFloat,
        isInteractive: Bool
    ) -> Bool {
        workspaceSidebarFolderReorderIsEnabled(
            projectId: projectId,
            isCompact: expansionProgress < workspaceSidebarRowsRevealProgress,
            isSearchFiltering: isSidebarSearchFiltering,
            isRenamingWorkspace: renamingWorkspaceName != nil || renamingProjectId != nil,
            isInteractive: isInteractive
        )
    }

    func isFolderReorderSource(_ projectId: WorkspaceProjectId) -> Bool {
        folderReorderDrag?.sourceProjectId == projectId
    }

    func workspaceListEntries(
        workspaces: [WorkspaceSidebarWorkspaceViewModel],
        projectId: WorkspaceProjectId
    ) -> [WorkspaceSidebarWorkspaceListEntry] {
        workspaceSidebarWorkspaceListEntries(
            workspaces: workspaces,
            projectId: projectId,
            sourceWorkspaceName: workspaceReorderDrag?.sourceWorkspaceName,
            sourceWorkspace: workspaceReorderPreviewWorkspace(),
            target: workspaceReorderDrag?.target
        )
    }

    func folderListEntries(
        sections: [WorkspaceSidebarFolderSection]
    ) -> [WorkspaceSidebarFolderListEntry] {
        workspaceSidebarFolderListEntries(
            sections: sections,
            sourceProjectId: folderReorderDrag?.sourceProjectId,
            target: folderReorderDrag?.target
        )
    }

    func isWorkspaceFolderDropTarget(_ projectId: WorkspaceProjectId) -> Bool {
        guard let target = workspaceReorderDrag?.target,
              case .moveToFolder(let folderTarget) = target
        else { return false }
        return folderTarget.projectId == projectId
    }

    func isWorkspaceFolderInteractionTarget(_ projectId: WorkspaceProjectId) -> Bool {
        guard let target = workspaceReorderDrag?.target else { return false }
        switch target {
            case .moveToFolder(let folderTarget):
                return folderTarget.projectId == projectId
            case .reorder(let reorderTarget):
                return reorderTarget.projectId == projectId
        }
    }

    func isProjectReorderDropTarget(_ projectId: WorkspaceProjectId) -> Bool {
        workspaceSidebarProjectFrameIsVisibleDropTarget(
            projectId: projectId,
            sourceProjectId: workspaceReorderDrag?.projectId
        )
    }

    func isWorkspaceProjectPreviewTarget(_ projectId: WorkspaceProjectId) -> Bool {
        workspaceSidebarIsProjectPreviewTarget(
            projectId: projectId,
            sourceWorkspaceName: workspaceReorderDrag?.sourceWorkspaceName,
            sourceWorkspace: workspaceReorderPreviewWorkspace(),
            target: workspaceReorderDrag?.target
        )
    }

    func workspaceReorderPlaceholder(
        expansionProgress: CGFloat,
        nestedContentIndent: CGFloat = 0
    ) -> some View {
        WorkspaceSidebarWorkspaceReorderPlaceholder(
            width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration),
            nestedContentIndent: nestedContentIndent,
            previewWorkspace: workspaceReorderPreviewWorkspace()
        )
    }

    func workspaceReorderPreviewWorkspace() -> WorkspaceSidebarWorkspaceViewModel? {
        guard let sourceWorkspaceName = workspaceReorderDrag?.sourceWorkspaceName else { return nil }
        return snapshot.workspaces.first { $0.name == sourceWorkspaceName }
    }

    func updateWorkspaceReorderDrag(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId,
        pointer: CGPoint,
        startsTracking: Bool = true
    ) {
        if startsTracking {
            clearFolderReorderDragImmediately()
            startWorkspaceReorderTrackingIfNeeded(workspace: workspace, projectId: projectId)
        }
        if workspaceReorderDrag == nil {
            NotificationCenter.default.post(name: workspaceSidebarDismissProjectMenusNotification, object: nil)
            isProjectMenuOpen = false
        }
        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: workspace.name,
            sourceProjectId: projectId,
            pointer: pointer,
            workspaceFrames: workspaceReorderFrames,
            folderFrames: folderReorderFrames
        )
        updateWorkspaceCanvasDropIntentOverlay(
            sourceWorkspaceName: workspace.name,
            screenPoint: MousePointerTracker.shared.currentSample.point,
            hasSidebarTarget: target != nil
        )
        WindowDragCursorProxyPanel.shared.show(
            preview: workspaceSidebarWorkspaceSourcePreview(workspace),
            mouseScreenPoint: NSEvent.mouseLocation
        )
        workspaceReorderDrag = WorkspaceSidebarWorkspaceReorderDragState(
            sourceWorkspaceName: workspace.name,
            projectId: projectId,
            pointer: pointer,
            target: target
        )
    }

    func startWorkspaceReorderTrackingIfNeeded(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId
    ) {
        guard !workspaceReorderDriver.isTracking(sourceWorkspaceName: workspace.name, projectId: projectId) else {
            return
        }
        workspaceReorderDriver.start(
            sourceWorkspaceName: workspace.name,
            projectId: projectId,
            onTick: {
                continueWorkspaceReorderDragFromMouse(
                    sourceWorkspaceName: workspace.name,
                    projectId: projectId
                )
            },
            onFinish: {
                finishWorkspaceReorderDragFromMouse(
                    sourceWorkspaceName: workspace.name,
                    projectId: projectId
                )
            }
        )
    }

    func continueWorkspaceReorderDragFromMouse(
        sourceWorkspaceName: String,
        projectId: WorkspaceProjectId
    ) {
        noteCurrentMousePointerSample()
        guard let workspace = snapshot.workspaces.first(where: { $0.name == sourceWorkspaceName }),
              let pointer = currentWorkspaceReorderContentPointer()
        else { return }
        updateWorkspaceReorderDrag(
            workspace: workspace,
            projectId: projectId,
            pointer: pointer,
            startsTracking: false
        )
    }

    func finishWorkspaceReorderDragFromMouse(
        sourceWorkspaceName: String,
        projectId: WorkspaceProjectId
    ) {
        noteCurrentMousePointerSample()
        guard let drag = workspaceReorderDrag,
              drag.sourceWorkspaceName == sourceWorkspaceName,
              drag.projectId == projectId,
              let workspace = snapshot.workspaces.first(where: { $0.name == sourceWorkspaceName })
        else {
            cancelWorkspaceReorderDrag()
            return
        }
        finishWorkspaceReorderDrag(
            workspace: workspace,
            projectId: projectId,
            pointer: currentWorkspaceReorderContentPointer() ?? drag.pointer
        )
    }

    func currentWorkspaceReorderContentPointer() -> CGPoint? {
        currentPanel()?.convertScreenPointToSidebarContentPoint(NSEvent.mouseLocation)
    }

    func finishWorkspaceReorderDrag(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId,
        pointer: CGPoint
    ) {
        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: workspace.name,
            sourceProjectId: projectId,
            pointer: pointer,
            workspaceFrames: workspaceReorderFrames,
            folderFrames: folderReorderFrames
        ) ?? workspaceReorderDrag?.target
        clearWorkspaceReorderDragImmediately()
        WindowDropIntentOverlayPanelController.shared.hide()
        guard let target else {
            let screenPoint = MousePointerTracker.shared.currentSample.point
            guard let dropIntent = workspaceCanvasDropIntent(
                sourceWorkspaceName: workspace.name,
                screenPoint: screenPoint
            ) else {
                activateWorkspaceAfterUncommittedReorderDrag(
                    workspace: workspace,
                    projectId: projectId,
                    screenPoint: screenPoint
                )
                return
            }
            mergeWorkspaceIntoActiveViewFromSidebarIfPossible(
                sourceWorkspaceName: workspace.name,
                pointer: screenPoint,
                position: dropIntent.position
            )
            return
        }
        guard let action = workspaceSidebarWorkspaceDragFinishAction(
            sourceWorkspaceName: workspace.name,
            target: target
        ) else { return }
        actions.send(action)
    }

    func activateWorkspaceAfterUncommittedReorderDrag(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        projectId: WorkspaceProjectId,
        screenPoint: CGPoint
    ) {
        guard WorkspaceSidebarPanel.panel(containing: screenPoint) != nil else { return }
        guard allowsWorkspaceActivation(projectId: projectId) else { return }
        if workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
            workspace,
            selectedScopeId: snapshot.targetMonitorScopeId
        ) {
            activeInUseOverrideWorkspaceName = workspace.name
            return
        }
        guard shouldHandleWorkspaceSidebarActivation(
            isEditing: false,
            isSidebarDragInProgress: false
        ) else { return }
        activeInUseOverrideWorkspaceName = nil
        beginPendingWorkspaceActivation(workspace.name)
        actions.send(.selectWorkspace(workspace.name))
    }

    func cancelWorkspaceReorderDrag() {
        clearWorkspaceReorderDragImmediately()
        WindowDropIntentOverlayPanelController.shared.hide()
    }

    func clearWorkspaceReorderDragImmediately() {
        let hadWorkspaceReorderDrag = workspaceReorderDrag != nil || workspaceReorderDriver.isTracking
        workspaceReorderDriver.stop()
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            workspaceReorderDrag = nil
        }
        if hadWorkspaceReorderDrag {
            WindowDragCursorProxyPanel.shared.hide()
        }
    }

    func updateFolderReorderDrag(
        section: WorkspaceSidebarFolderSection,
        pointer: CGPoint,
        startsTracking: Bool = true
    ) {
        if startsTracking {
            clearWorkspaceReorderDragImmediately()
            startFolderReorderTrackingIfNeeded(projectId: section.project.id)
        }
        if folderReorderDrag == nil {
            NotificationCenter.default.post(name: workspaceSidebarDismissProjectMenusNotification, object: nil)
            isProjectMenuOpen = false
        }
        let target = workspaceSidebarFolderReorderTarget(
            sourceProjectId: section.project.id,
            pointer: pointer,
            frames: folderReorderFrames
        )
        WindowDragCursorProxyPanel.shared.show(
            preview: workspaceSidebarFolderSourcePreview(section),
            mouseScreenPoint: NSEvent.mouseLocation
        )
        folderReorderDrag = WorkspaceSidebarFolderReorderDragState(
            sourceProjectId: section.project.id,
            pointer: pointer,
            target: target
        )
    }

    func startFolderReorderTrackingIfNeeded(projectId: WorkspaceProjectId) {
        guard !folderReorderDriver.isTracking(sourceProjectId: projectId) else { return }
        folderReorderDriver.start(
            sourceProjectId: projectId,
            onTick: {
                continueFolderReorderDragFromMouse(sourceProjectId: projectId)
            },
            onFinish: {
                finishFolderReorderDragFromMouse(sourceProjectId: projectId)
            }
        )
    }

    func continueFolderReorderDragFromMouse(sourceProjectId: WorkspaceProjectId) {
        noteCurrentMousePointerSample()
        guard let section = folderReorderSection(projectId: sourceProjectId),
              let pointer = currentWorkspaceReorderContentPointer()
        else { return }
        updateFolderReorderDrag(section: section, pointer: pointer, startsTracking: false)
    }

    func finishFolderReorderDragFromMouse(sourceProjectId: WorkspaceProjectId) {
        noteCurrentMousePointerSample()
        guard let drag = folderReorderDrag,
              drag.sourceProjectId == sourceProjectId,
              let section = folderReorderSection(projectId: sourceProjectId)
        else {
            cancelFolderReorderDrag()
            return
        }
        finishFolderReorderDrag(
            section: section,
            pointer: currentWorkspaceReorderContentPointer() ?? drag.pointer
        )
    }

    func finishFolderReorderDrag(
        section: WorkspaceSidebarFolderSection,
        pointer: CGPoint
    ) {
        let target = workspaceSidebarFolderReorderTarget(
            sourceProjectId: section.project.id,
            pointer: pointer,
            frames: folderReorderFrames
        ) ?? folderReorderDrag?.target
        clearFolderReorderDragImmediately()
        guard let target else { return }
        actions.send(.reorderFolder(section.project.id, placement: target.placement))
    }

    func cancelFolderReorderDrag() {
        clearFolderReorderDragImmediately()
    }

    func clearFolderReorderDragImmediately() {
        let hadFolderReorderDrag = folderReorderDrag != nil || folderReorderDriver.isTracking
        folderReorderDriver.stop()
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            folderReorderDrag = nil
        }
        if hadFolderReorderDrag {
            WindowDragCursorProxyPanel.shared.hide()
        }
    }

    func folderReorderSection(projectId: WorkspaceProjectId) -> WorkspaceSidebarFolderSection? {
        guard projectId != workspaceProjectDefaultId,
              let project = snapshot.projects.first(where: { $0.id == projectId })
        else { return nil }
        let workspaces = workspaceSidebarNonEmptyFolderWorkspaces(
            snapshot.workspaces.filter { $0.projectId == projectId }
        )
        guard !workspaces.isEmpty else { return nil }
        return WorkspaceSidebarFolderSection(project: project, workspaces: workspaces)
    }

    func updateWorkspaceCanvasDropIntentOverlay(
        sourceWorkspaceName: String,
        screenPoint: CGPoint,
        hasSidebarTarget: Bool
    ) {
        guard !hasSidebarTarget,
              let dropIntent = workspaceCanvasDropIntent(
                sourceWorkspaceName: sourceWorkspaceName,
                screenPoint: screenPoint
              )
        else {
            WindowDropIntentOverlayPanelController.shared.hide()
            return
        }
        WindowDropIntentOverlayPanelController.shared.show(dropIntent.overlay)
    }

    func workspaceCanvasDropIntent(
        sourceWorkspaceName: String,
        screenPoint: CGPoint
    ) -> (position: WindowStackSplitPosition, overlay: WindowDropIntentOverlayModel)? {
        guard WorkspaceSidebarPanel.panel(containing: screenPoint) == nil,
              let sourceWorkspace = Workspace.existing(byName: sourceWorkspaceName)
        else { return nil }
        let targetWorkspace = screenPoint.monitorApproximation.activeWorkspace
        guard targetWorkspace != sourceWorkspace else { return nil }
        let workspaceRect = targetWorkspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        guard let zone = WindowIntentZoneBuilder.zone(at: screenPoint, in: workspaceRect),
              let position = zone.stackSplitPosition
        else { return nil }
        return (
            position,
            WindowDropIntentOverlayModel(
                targetFrame: workspaceRect,
                activeZone: zone,
                cornerRadius: nil
            )
        )
    }
}
