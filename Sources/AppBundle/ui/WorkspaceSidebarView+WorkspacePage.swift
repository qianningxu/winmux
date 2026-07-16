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
        let allSections = folderSections(projectId: projectId, workspaces: workspaces)
        let sections = workspaceSidebarIsCompact(expansionProgress: expansionProgress)
            ? workspaceSidebarCompactFolderSections(
                allSections,
                currentProjectId: workspaceSidebarCurrentFolderProjectId(
                    workspaces: workspaces,
                    targetMonitorScopeId: snapshot.targetMonitorScopeId
                )
            )
            : allSections
        return ScrollView {
            VStack(alignment: .leading, spacing: workspaceSidebarListItemSpacing) {
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
                ForEach(folderListEntries(sections: sections)) { entry in
                    switch entry {
                        case .folder(let section, _):
                            if expansionProgress >= workspaceSidebarRowsRevealProgress {
                                WorkspaceSidebarFolder(
                                    section: section,
                                    expansionProgress: expansionProgress,
                                    layout: snapshot.configuration,
                                    monitorScopeId: snapshot.targetMonitorScopeId,
                                    isExpanded: isFolderExpanded(section.project.id),
                                    onToggle: {
                                        setFolderExpanded(section.project.id, !isFolderExpanded(section.project.id))
                                    },
                                    onDropPayload: { payload in
                                        handleFolderPayloadDrop(payload, projectId: section.project.id)
                                    },
                                    actions: actions,
                                    emitsDropTarget: true,
                                    dropPreview: folderDropPreview(section.project.id),
                                    isWorkspaceDragTargeted: isWorkspaceFolderInteractionTarget(section.project.id),
                                    isShowingProjectedContent: isWorkspaceProjectPreviewTarget(section.project.id) || folderDropPreview(section.project.id) != nil,
                                    isFolderReorderEnabled: isFolderReorderEnabled(
                                        projectId: section.project.id,
                                        expansionProgress: expansionProgress,
                                        isInteractive: isInteractive
                                    ),
                                    isFolderReorderSource: isFolderReorderSource(section.project.id),
                                    renamingProjectId: $renamingProjectId,
                                    renamingProjectText: $renamingProjectText,
                                    onBeginRenameProject: { project in
                                        beginProjectRename(project, browseIfNeeded: false)
                                    },
                                    onCommitRenameProject: {
                                        finishProjectRename()
                                    },
                                    onCancelRenameProject: {
                                        finishProjectRename(cancelled: true)
                                    },
                                    onFolderReorderDragChanged: { pointer in
                                        updateFolderReorderDrag(section: section, pointer: pointer)
                                    },
                                    onFolderReorderDragEnded: { pointer in
                                        finishFolderReorderDrag(section: section, pointer: pointer)
                                    },
                                    content: {
                                        workspaceList(
                                            workspaces: section.workspaces,
                                            projectId: section.project.id,
                                            expansionProgress: expansionProgress,
                                            isInteractive: isInteractive,
                                            allowsActivation: allowsActivation,
                                            nestedContentIndent: workspaceSidebarTabGroupChildLeadingIndent,
                                        )
                                    }
                                )
                            } else {
                                workspaceList(
                                    workspaces: section.workspaces,
                                    projectId: section.project.id,
                                    expansionProgress: expansionProgress,
                                    isInteractive: isInteractive,
                                    allowsActivation: allowsActivation,
                                    nestedContentIndent: 0,
                                )
                            }
                        case .placeholder(let section):
                            WorkspaceSidebarFolderReorderPlaceholder(
                                width: workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration),
                                section: section
                            )
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
                            actions.send(.createFolder)
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
            // Structural changes in a VStack do not reliably inherit a
            // transaction through every nested folder on every SwiftUI frame.
            // Bind the reorder animation at the list container so each stable
            // tab ID visibly moves into the source gap / around the insertion
            // slot instead of jumping after a dragged tab.
            // Exact pointer/drop state changes at native event frequency. Only
            // the paced visual slot should retarget the structural list spring.
            .animation(workspaceSidebarWorkspaceReorderAnimation, value: workspaceReorderDrag?.target)
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.top, topPadding)
            .padding(.bottom, workspaceSidebarMinimumTopPadding)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: snapshot.dropPreview)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func workspaceList(
        workspaces: [WorkspaceSidebarWorkspaceViewModel],
        projectId: WorkspaceProjectId,
        expansionProgress: CGFloat,
        isInteractive: Bool,
        allowsActivation: Bool?,
        nestedContentIndent: CGFloat = 0,
    ) -> some View {
        ForEach(workspaceListEntries(workspaces: workspaces, projectId: projectId)) { entry in
            switch entry {
                case .workspace(let workspace, let isDragAnchor):
                    workspaceSection(
                        workspace: workspace,
                        expansionProgress: expansionProgress,
                        emitsDropTarget: true,
                        allowsWorkspaceActivation: allowsActivation ?? allowsWorkspaceActivation(projectId: projectId),
                        isPinnedActiveWorkspace: false,
                        isInteractive: isInteractive,
                        projectContextLabel: browsedProjectId != nil && projectId != snapshot.activeProjectId ? projectName(projectId) : nil,
                        projectContextColor: browsedProjectId != nil && projectId != snapshot.activeProjectId ? projectColor(projectId) : nil,
                        nestedContentIndent: nestedContentIndent,
                    )
                    .modifier(WorkspaceSidebarProjectedDragAnchorModifier(isActive: isDragAnchor))
                case .placeholder:
                    workspaceReorderPlaceholder(
                        expansionProgress: expansionProgress,
                        nestedContentIndent: nestedContentIndent
                    )
            }
        }
    }

    private func folderDropPreview(_ projectId: WorkspaceProjectId) -> WorkspaceSidebarDropPreviewViewModel? {
        guard let dropPreview = snapshot.dropPreview,
              dropPreview.targetProjectId == projectId,
              dropPreview.targetWorkspaceName == nil,
              dropPreview.targetMonitorScopeId == nil || dropPreview.targetMonitorScopeId == snapshot.targetMonitorScopeId
        else { return nil }
        return dropPreview
    }

    @MainActor
    private func handleFolderPayloadDrop(
        _ payload: WorkspaceSidebarDragPayload,
        projectId: WorkspaceProjectId
    ) {
        switch payload {
            case .window(let windowId):
                actions.send(.moveWindowToNewWorkspace(
                    windowId,
                    projectId: projectId,
                    monitorScopeId: snapshot.targetMonitorScopeId,
                ))
            case .tabGroup(let representativeWindowId):
                if let workspaceName = workspaceSidebarPayloadSourceWorkspaceName(payload) {
                    actions.send(.moveWorkspaceToFolder(workspaceName, projectId: projectId))
                } else {
                    actions.send(.moveTabGroupToNewWorkspace(
                        representativeWindowId,
                        projectId: projectId,
                        monitorScopeId: snapshot.targetMonitorScopeId,
                    ))
                }
        }
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
        projectContextColor: Color? = nil,
        nestedContentIndent: CGFloat = 0,
    ) -> some View {
        let isFromOtherDisplay = false
        let isInUseOnOtherDisplay = allowsWorkspaceActivation &&
            !isPinnedActiveWorkspace &&
            workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
                workspace,
                selectedScopeId: snapshot.targetMonitorScopeId
            )
        let isActiveOnTargetMonitor = workspace.monitorScopeId == snapshot.targetMonitorScopeId && workspace.isVisible
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
            isActiveOnTargetMonitor: isActiveOnTargetMonitor,
            isPendingActivationOnTargetMonitor: workspaceSidebarPendingActivationMatches(
                pendingWorkspaceActivation,
                workspace: workspace,
                targetMonitorScopeId: snapshot.targetMonitorScopeId,
                isActiveOnTargetMonitor: isActiveOnTargetMonitor
            ),
            projectContextLabel: projectContextLabel,
            projectContextColor: projectContextColor,
            nestedContentIndent: nestedContentIndent,
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
            selectedSearchTarget: isSidebarSearchFiltering ? selectedSearchTarget : nil,
            isSearchFiltering: isSidebarSearchFiltering,
            isWorkspaceReorderEnabled: isWorkspaceReorderEnabled(
                workspace: workspace,
                expansionProgress: expansionProgress,
                isPinnedActiveWorkspace: isPinnedActiveWorkspace,
                isInteractive: isInteractive
            ),
            isWorkspaceReorderSource: isWorkspaceReorderSource(workspace),
            isWorkspaceReorderInProgress: workspaceReorderDrag != nil,
            onWorkspaceReorderDragChanged: { pointer in
                updateWorkspaceReorderDrag(workspace: workspace, projectId: workspace.projectId, pointer: pointer)
            },
            onWorkspaceReorderDragEnded: { pointer in
                finishWorkspaceReorderDrag(workspace: workspace, projectId: workspace.projectId, pointer: pointer)
            },
            activeInUseOverrideWorkspaceName: $activeInUseOverrideWorkspaceName,
            onBeginWorkspaceActivation: beginPendingWorkspaceActivation,
            actions: actions,
        )
    }

    @MainActor
    func beginPendingWorkspaceActivation(_ workspaceName: String) {
        let pendingActivation = WorkspaceSidebarPendingActivation(
            workspaceName: workspaceName,
            targetMonitorScopeId: snapshot.targetMonitorScopeId
        )
        pendingWorkspaceActivation = pendingActivation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: workspaceSidebarPendingActivationTimeoutNanoseconds)
            if pendingWorkspaceActivation == pendingActivation {
                pendingWorkspaceActivation = nil
            }
        }
    }

    @MainActor
    func reconcilePendingWorkspaceActivation() {
        guard let pendingWorkspaceActivation else { return }
        guard pendingWorkspaceActivation.targetMonitorScopeId == snapshot.targetMonitorScopeId else {
            self.pendingWorkspaceActivation = nil
            return
        }
        guard snapshot.workspaces.contains(where: { $0.name == pendingWorkspaceActivation.workspaceName }) else {
            self.pendingWorkspaceActivation = nil
            return
        }
        if workspaceSidebarPendingActivationHasResolved(
            pendingWorkspaceActivation,
            workspaces: snapshot.workspaces
        ) {
            self.pendingWorkspaceActivation = nil
        }
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
        snapshot.projects.first { $0.id == projectId }?.displayName ?? "Folder"
    }

    private func projectColor(_ projectId: WorkspaceProjectId) -> Color {
        workspaceSidebarProjectColor(projectId: projectId, configuredHex: projectColorHex(projectId))
    }

    private func folderSections(
        projectId: WorkspaceProjectId,
        workspaces: [WorkspaceSidebarWorkspaceViewModel]
    ) -> [WorkspaceSidebarFolderSection] {
        workspaceSidebarFolderSections(
            projectId: projectId,
            workspaces: workspaces,
            projects: snapshot.projects,
        )
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
