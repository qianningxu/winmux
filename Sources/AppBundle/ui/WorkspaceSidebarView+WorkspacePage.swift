import Common
import SwiftUI

extension WorkspaceSidebarView {
    @ViewBuilder
    func projectPageSlot(
        index: Int,
        project: WorkspaceSidebarProjectViewModel,
        displayIndex: Int,
        pageWidth: CGFloat,
        expansionProgress: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        topPadding: CGFloat,
        visibleWorkspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]],
        swipeDirection: Int?,
    ) -> some View {
        if shouldRenderWorkspaceSidebarProjectPage(
            index: index,
            displayIndex: displayIndex,
            swipeDirection: swipeDirection,
            projectCount: snapshot.projects.count,
        ) {
            workspacePage(
                projectId: project.id,
                workspaces: visibleWorkspacesByProject[project.id] ?? [],
                expansionProgress: expansionProgress,
                leadingInset: leadingInset,
                trailingInset: trailingInset,
                topPadding: topPadding,
                isInteractive: index == displayIndex,
                showsPinnedActiveWorkspace: showsPinnedActiveWorkspaceForBrowsedProject,
                showsCreateWorkspace: browsedProjectId == nil,
                allowsActivation: allowsWorkspaceActivation(projectId: project.id),
            )
                    .frame(width: pageWidth, alignment: .topLeading)
                    .allowsHitTesting(index == displayIndex)
        } else {
            Color.clear
                .frame(width: pageWidth, alignment: .topLeading)
                .allowsHitTesting(false)
        }
    }

    func workspacePage(
        projectId: WorkspaceProjectId,
        workspaces: [WorkspaceSidebarWorkspaceViewModel],
        expansionProgress: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        topPadding: CGFloat,
        isInteractive: Bool,
        showsPinnedActiveWorkspace: Bool = true,
        showsCreateWorkspace: Bool = true,
        allowsActivation: Bool? = nil,
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if showsPinnedActiveWorkspace,
                   let pinnedActiveWorkspace = pinnedActiveWorkspace(
                    displayedProjectId: projectId,
                    pageWorkspaces: workspaces
                ) {
                    workspaceSection(
                        workspace: pinnedActiveWorkspace,
                        expansionProgress: expansionProgress,
                        emitsDropTarget: true,
                        allowsWorkspaceActivation: false,
                        isPinnedActiveWorkspace: true,
                        isInteractive: isInteractive,
                        projectContextLabel: projectName(snapshot.activeProjectId),
                        projectContextColor: projectColor(snapshot.activeProjectId)
                    )
                }
                ForEach(workspaces) { workspace in
                    if showsWorkspaceReorderIndicator(before: workspace, projectId: projectId) {
                        workspaceReorderIndicator(expansionProgress: expansionProgress)
                    }
                    workspaceSection(
                        workspace: workspace,
                        expansionProgress: expansionProgress,
                        emitsDropTarget: true,
                        allowsWorkspaceActivation: allowsActivation ?? allowsWorkspaceActivation(projectId: projectId),
                        isPinnedActiveWorkspace: false,
                        isInteractive: isInteractive,
                        projectContextLabel: browsedProjectId != nil && projectId != snapshot.activeProjectId ? projectName(projectId) : nil,
                        projectContextColor: browsedProjectId != nil && projectId != snapshot.activeProjectId ? projectColor(projectId) : nil
                    )
                    if showsWorkspaceReorderIndicator(after: workspace, projectId: projectId) {
                        workspaceReorderIndicator(expansionProgress: expansionProgress)
                    }
                }
                if showsCreateWorkspace && workspaceSidebarShowsCreateWorkspace(selectedScopeId: snapshot.selectedMonitorScopeId) {
                    let createMonitorScopeId = workspaceSidebarWorkspaceCreateScope(
                        selectedScopeId: snapshot.selectedMonitorScopeId,
                        targetMonitorScopeId: snapshot.targetMonitorScopeId,
                        focusedScopeId: snapshot.focusedMonitorScopeId,
                    )
                    WorkspaceSidebarCreateWorkspaceSection(
                        projectId: projectId,
                        monitorScopeId: createMonitorScopeId,
                        dragPreview: snapshot.dropPreview,
                        expansionProgress: expansionProgress,
                        layout: snapshot.configuration,
                        emitsDropTarget: true,
                        onCreateWorkspace: {
                            actions.send(.createWorkspace(
                                projectId: projectId,
                                monitorScopeId: createMonitorScopeId
                            ))
                        },
                        onDropPayload: { payload in
                            switch payload {
                                case .window(let windowId):
                                    actions.send(.moveWindowToNewWorkspace(
                                        windowId,
                                        projectId: projectId,
                                        monitorScopeId: createMonitorScopeId,
                                    ))
                                case .tabGroup(let representativeWindowId):
                                    actions.send(.moveTabGroupToNewWorkspace(
                                        representativeWindowId,
                                        projectId: projectId,
                                        monitorScopeId: createMonitorScopeId,
                                    ))
                            }
                        },
                        actions: actions,
                    )
                }
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.top, topPadding)
            .padding(.bottom, workspaceSidebarMinimumTopPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func splitWorkspacePage(
        activeProjectId: WorkspaceProjectId,
        browsedProjectId: WorkspaceProjectId,
        expansionProgress: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        topPadding: CGFloat,
        visibleWorkspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]],
    ) -> some View {
        let sectionWidth = workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration)
        return HStack(alignment: .top, spacing: workspaceSidebarSplitPaneGap) {
            workspacePage(
                projectId: activeProjectId,
                workspaces: visibleWorkspacesByProject[activeProjectId] ?? [],
                expansionProgress: expansionProgress,
                leadingInset: leadingInset,
                trailingInset: 0,
                topPadding: topPadding,
                isInteractive: true,
                showsPinnedActiveWorkspace: false,
                showsCreateWorkspace: true,
                allowsActivation: true,
            )
            .frame(width: sectionWidth + leadingInset, alignment: .topLeading)

            workspacePage(
                projectId: browsedProjectId,
                workspaces: visibleWorkspacesByProject[browsedProjectId] ?? [],
                expansionProgress: expansionProgress,
                leadingInset: 0,
                trailingInset: trailingInset,
                topPadding: topPadding,
                isInteractive: true,
                showsPinnedActiveWorkspace: false,
                showsCreateWorkspace: true,
                allowsActivation: false,
            )
            .frame(width: sectionWidth + trailingInset, alignment: .topLeading)
        }
        .frame(
            width: workspaceSidebarSplitSectionWidth(expansionProgress: expansionProgress) + leadingInset + trailingInset,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func workspaceSection(
        workspace: WorkspaceSidebarWorkspaceViewModel,
        expansionProgress: CGFloat,
        emitsDropTarget: Bool,
        allowsWorkspaceActivation: Bool,
        isPinnedActiveWorkspace: Bool,
        isInteractive: Bool,
        projectContextLabel: String? = nil,
        projectContextColor: Color? = nil
    ) -> some View {
        let isFromOtherDisplay = false
        let isInUseOnOtherDisplay = allowsWorkspaceActivation &&
            !isPinnedActiveWorkspace &&
            workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
                workspace,
                selectedScopeId: snapshot.targetMonitorScopeId
            )
        WorkspaceSidebarWorkspaceSection(
            workspace: workspace,
            dragPreview: snapshot.dropPreview,
            expansionProgress: expansionProgress,
            layout: snapshot.configuration,
            emitsDropTarget: emitsDropTarget,
            isFromOtherDisplay: isFromOtherDisplay,
            isInUseOnOtherDisplay: isInUseOnOtherDisplay,
            isOnFocusedMonitor: workspace.monitorScopeId == snapshot.focusedMonitorScopeId,
            allowsWorkspaceActivation: allowsWorkspaceActivation,
            isPinnedActiveWorkspace: isPinnedActiveWorkspace,
            isActiveOnTargetMonitor: workspace.monitorScopeId == snapshot.targetMonitorScopeId && workspace.isVisible,
            projectContextLabel: projectContextLabel,
            projectContextColor: projectContextColor,
            renamingWorkspaceName: $renamingWorkspaceName,
            renamingWorkspaceText: $renamingWorkspaceText,
            onBeginRenameWorkspace: {
                beginWorkspaceRename(workspace)
            },
            onCommitRenameWorkspace: {
                finishWorkspaceRename()
            },
            onCancelRenameWorkspace: {
                finishWorkspaceRename(cancelled: true)
            },
            selectedSearchTarget: searchText.isEmpty ? nil : selectedSearchTarget,
            isSearchFiltering: !searchText.isEmpty,
            isWorkspaceReorderEnabled: isWorkspaceReorderEnabled(
                workspace: workspace,
                expansionProgress: expansionProgress,
                isPinnedActiveWorkspace: isPinnedActiveWorkspace,
                isInteractive: isInteractive
            ),
            isWorkspaceReorderSource: isWorkspaceReorderSource(workspace),
            onWorkspaceReorderDragChanged: { pointer in
                updateWorkspaceReorderDrag(workspace: workspace, projectId: workspace.projectId, pointer: pointer)
            },
            onWorkspaceReorderDragEnded: { pointer in
                finishWorkspaceReorderDrag(workspace: workspace, projectId: workspace.projectId, pointer: pointer)
            },
            activeInUseOverrideWorkspaceName: $activeInUseOverrideWorkspaceName,
            actions: actions,
        )
    }

    func allowsWorkspaceActivation(projectId: WorkspaceProjectId) -> Bool {
        snapshot.selectedMonitorScopeId == workspaceSidebarDefaultScopeId &&
            browsedProjectId == nil &&
            projectId == snapshot.activeProjectId
    }

    private func projectColorHex(_ projectId: WorkspaceProjectId) -> String? {
        snapshot.projects.first { $0.id == projectId }?.colorHex
    }

    private func projectName(_ projectId: WorkspaceProjectId) -> String {
        snapshot.projects.first { $0.id == projectId }?.displayName ?? "Project"
    }

    private func projectColor(_ projectId: WorkspaceProjectId) -> Color {
        workspaceSidebarProjectColor(projectId: projectId, configuredHex: projectColorHex(projectId))
    }

    private func pinnedActiveWorkspace(
        displayedProjectId: WorkspaceProjectId,
        pageWorkspaces: [WorkspaceSidebarWorkspaceViewModel]
    ) -> WorkspaceSidebarWorkspaceViewModel? {
        guard browsedProjectId != nil,
              displayedProjectId != snapshot.activeProjectId,
              !pageWorkspaces.contains(where: { workspaceIsActiveOnTargetMonitor($0) }),
              let focusedWorkspace = snapshot.workspaces.first(where: { workspaceIsActiveOnTargetMonitor($0) }),
              workspaceSidebarWorkspaceMatchesScope(
                focusedWorkspace,
                selectedScopeId: snapshot.selectedMonitorScopeId,
                focusedMonitorScopeId: snapshot.focusedMonitorScopeId
              )
        else {
            return nil
        }
        return focusedWorkspace
    }

    private func workspaceIsActiveOnTargetMonitor(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> Bool {
        workspace.isVisible && workspace.monitorScopeId == snapshot.targetMonitorScopeId
    }
}
