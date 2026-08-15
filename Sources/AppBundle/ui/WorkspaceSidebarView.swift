import AppKit
import Common
import SwiftUI

struct WorkspaceSidebarView: View {
    @Environment(\.colorScheme) var colorScheme

    let snapshot: WorkspaceSidebarSnapshot
    let actions: WorkspaceSidebarActions
    let showsNotePad: Bool
    let onToggleNotePad: () -> Void
    let showsTasks: Bool
    let onToggleTasks: () -> Void
    @State var projectSwipeTranslation: CGFloat = 0
    @State var projectSwipeStartProjectId: WorkspaceProjectId? = nil
    @State var projectSwipeDidCrossBreakPoint = false
    @State var projectPagerWidth: CGFloat = 0
    @State var browseMode: WorkspaceSidebarBrowseMode = .activeProject
    @State var activeInUseOverrideWorkspaceName: String? = nil
    @State var isProjectMenuOpen = false
    @State var isSidebarCollapsing = false
    @State var isSidebarExpanding = false
    @State var renamingProjectId: WorkspaceProjectId? = nil
    @State var renamingProjectText = ""
    @State var renamingWorkspaceName: String? = nil
    @State var renamingWorkspaceText = ""
    @State var committedWorkspaceRenameName: String? = nil
    @State var searchText = ""
    @State var isSearchEditing = false
    @State var searchEditingPanel: WorkspaceSidebarPanel? = nil
    @State var selectedSearchTarget: WorkspaceSidebarSearchSelection? = nil
    @State var lastProjectEdgeDragDirection: Int? = nil
    @State var lastProjectEdgeDragSwitchAt: Date = .distantPast
    @State var showsPinnedActiveWorkspaceForBrowsedProject = true
    @State var workspaceReorderFrames: [WorkspaceSidebarWorkspaceReorderFrame] = []
    @State var workspaceReorderHitTestFrames: [WorkspaceSidebarWorkspaceReorderFrame] = []
    @State var workspaceReorderHitTestFolderFrames: [WorkspaceSidebarFolderReorderFrame] = []
    @State var folderReorderFrames: [WorkspaceSidebarFolderReorderFrame] = []
    @State var folderReorderHitTestFrames: [WorkspaceSidebarFolderReorderFrame] = []
    @State var workspaceReorderDrag: WorkspaceSidebarWorkspaceReorderDragState? = nil
    @StateObject var workspaceReorderDriver = WorkspaceSidebarWorkspaceReorderDriver()
    @State var folderReorderDrag: WorkspaceSidebarFolderReorderDragState? = nil
    @StateObject var folderReorderDriver = WorkspaceSidebarFolderReorderDriver()
    @State var folderExpansionOverrides: [WorkspaceProjectId: Bool] = [:]
    @State var pendingWorkspaceActivation: WorkspaceSidebarPendingActivation? = nil

    init(
        snapshot: WorkspaceSidebarSnapshot,
        actions: WorkspaceSidebarActions = WorkspaceSidebarActions(),
        showsNotePad: Bool = true,
        onToggleNotePad: @escaping () -> Void = {},
        showsTasks: Bool = true,
        onToggleTasks: @escaping () -> Void = {},
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.showsNotePad = showsNotePad
        self.onToggleNotePad = onToggleNotePad
        self.showsTasks = showsTasks
        self.onToggleTasks = onToggleTasks
    }

    var body: some View {
        let collapsedWidth = snapshot.configuration.collapsedWidth
        let expandedWidth = snapshot.configuration.expandedWidth
        let expansionProgress = max(
            0,
            min(1, (snapshot.visibleWidth - collapsedWidth) / max(expandedWidth - collapsedWidth, 1)),
        )
        
        sidebarBody(expansionProgress: expansionProgress, expandedWidth: expandedWidth)
        .onAppear {
            syncFolderExpansionOverrides()
            normalizeActiveSidebarWidthIfNeeded(expandedWidth: expandedWidth)
        }
        .onChange(of: snapshot.visibleWidth) { visibleWidth in
            if visibleWidth <= collapsedWidth + 0.5 {
                resetTransientSidebarState()
                finishSidebarSearch(clearText: true)
            } else if visibleWidth >= collapsedWidth + 8 {
                isSidebarCollapsing = false
            }
            if visibleWidth >= expandedWidth - 0.5 {
                isSidebarExpanding = false
            }
            normalizeActiveSidebarWidthIfNeeded(visibleWidth: visibleWidth, expandedWidth: expandedWidth)
        }
        .onChange(of: snapshot.activeProjectId) { projectId in
            debugWorkspaceSidebarProjectLog(
                "snapshotActiveProjectChanged active=\(projectId.rawValue) visibleWidth=\(snapshot.visibleWidth) projects=\(snapshot.projects.map(\.id.rawValue))"
            )
            browseMode = .activeProject
            showsPinnedActiveWorkspaceForBrowsedProject = true
            activeInUseOverrideWorkspaceName = nil
            pendingWorkspaceActivation = nil
            cancelWorkspaceReorderDrag()
            finishProjectRename(cancelled: true)
            finishSidebarSearch(clearText: true)
            resetProjectSwipeWithoutAnimation()
        }
        .onChange(of: snapshot.targetMonitorScopeId) { _ in
            pendingWorkspaceActivation = nil
        }
        .onChange(of: snapshot.workspaces) { _ in
            syncFolderExpansionOverrides()
            reconcilePendingWorkspaceActivation()
        }
        .onChange(of: browseMode) { mode in
            cancelWorkspaceReorderDrag()
            guard snapshot.visibleWidth > collapsedWidth + 0.5,
                  let panel = WorkspaceSidebarPanel.panel(for: snapshot.targetMonitorScopeId)
            else { return }
            let expandedContentWidth = workspaceSidebarExpandedContentFrameWidth(layout: snapshot.configuration)
            let targetWidth = mode.isSplit ? expandedContentWidth : expandedWidth
            debugWorkspaceSidebarHoverLog("browseProjectWidthChange panel=\(snapshot.targetMonitorScopeId) project=\(mode.otherProjectId?.rawValue ?? "nil") snapshotWidth=\(snapshot.visibleWidth) target=\(targetWidth) frame=\(panel.frame) mouse=\(NSEvent.mouseLocation)")
            panel.cancelExpansionWork()
            panel.viewModel.isWorkspaceSidebarExpanded = true
            panel.splitBrowseCollapseSuppressedUntil = mode.isSplit ? Date().addingTimeInterval(0.65) : .distantPast
            isSidebarCollapsing = false
            isSidebarExpanding = false
            panel.animateVisibleSidebarWidth(targetWidth, animation: .easeInOut(duration: panel.animationDuration))
        }
        .onChange(of: snapshot.projects) { _ in
            syncFolderExpansionOverrides()
            if (!projectsAreEnabled() && browseMode != .activeProject) ||
                (browsedProjectId != nil && !snapshot.projects.contains(where: { $0.id == browsedProjectId.orDie() }))
            {
                browseMode = .activeProject
            }
            if let renamingProjectId, !snapshot.projects.contains(where: { $0.id == renamingProjectId }) {
                finishProjectRename(cancelled: true)
            }
            reconcileWorkspaceRenameState()
            cancelWorkspaceReorderDrag()
            isProjectMenuOpen = false
            resetProjectSwipeWithoutAnimation()
        }
        .onChange(of: snapshot.workspaces) { _ in
            reconcileWorkspaceRenameState()
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarWillCollapseNotification)) { notification in
            guard notificationPanel(from: notification)?.monitorScopeId == snapshot.targetMonitorScopeId else { return }
            guard snapshot.visibleWidth > collapsedWidth + 0.5 else {
                isSidebarCollapsing = false
                return
            }
            finishSidebarSearch(clearText: true)
            withAnimation(.easeOut(duration: 0.08)) {
                isProjectMenuOpen = false
                isSidebarCollapsing = true
                isSidebarExpanding = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarWillExpandNotification)) { notification in
            guard notificationPanel(from: notification)?.monitorScopeId == snapshot.targetMonitorScopeId else { return }
            isSidebarCollapsing = false
            isSidebarExpanding = true
            finishSidebarSearch(clearText: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarCommandSearchKeyNotification)) { notification in
            guard let panel = notificationPanel(from: notification),
                  panel.monitorScopeId == snapshot.targetMonitorScopeId
            else { return }
            adoptCommandSidebarSearchIfNeeded(panel: panel)
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarDismissProjectMenusNotification)) { _ in
            if isProjectMenuOpen {
                withAnimation(.easeOut(duration: 0.10)) {
                    isProjectMenuOpen = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarDragPointerChangedNotification)) { notification in
            guard let pointer = workspaceSidebarDragPointer(from: notification) else { return }
            handleProjectEdgeDrag(pointer: pointer, expansionProgress: expansionProgress)
        }
        .onReceive(NotificationCenter.default.publisher(for: workspaceSidebarDragPointerEndedNotification)) { notification in
            resetProjectEdgeDrag()
            // The global mouse-up monitor can arrive before SwiftUI delivers
            // the gesture's final `onChanged`/`onEnded` pair.  Cancelling
            // synchronously in that gap is exactly why a quick release could
            // return a tab to its origin.  Let that event turn finish first,
            // then use this exact mouse-up point as the fallback commit.
            let screenPoint = workspaceSidebarDragPointer(from: notification) ??
                MousePointerTracker.shared.currentSample.point
            Task { @MainActor in
                await Task.yield()
                guard let drag = workspaceReorderDrag,
                      !drag.isCommitting,
                      let workspace = snapshot.workspaces.first(where: { $0.name == drag.sourceWorkspaceName })
                else { return }
                finishWorkspaceReorderDrag(
                    workspace: workspace,
                    projectId: drag.projectId,
                    pointer: workspaceReorderContentPointer(screenPoint: screenPoint) ??
                        workspaceReorderDriver.latestPointer ??
                        .zero,
                    screenPoint: screenPoint
                )
            }
            resetWorkspaceSidebarItemDrag()
        }
    }

    func sidebarBody(expansionProgress: CGFloat, expandedWidth: CGFloat) -> some View {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        let visibleWidth = max(snapshot.visibleWidth, 0)

        return ZStack(alignment: .topLeading) {
            sidebarContent(expansionProgress: expansionProgress)
                .frame(width: visibleWidth, alignment: .leading)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: visibleWidth)
                }
                .padding(.leading, metrics.outerInset)
                .padding(.vertical, metrics.outerInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.clear)
    }

    func normalizeActiveSidebarWidthIfNeeded(
        visibleWidth: CGFloat? = nil,
        expandedWidth: CGFloat
    ) {
        guard !browseMode.isSplit else { return }
        let currentWidth = visibleWidth ?? snapshot.visibleWidth
        guard currentWidth > expandedWidth + 0.5 else { return }
        guard let panel = currentPanel() else { return }
        panel.cancelExpansionWork()
        panel.viewModel.isWorkspaceSidebarExpanded = true
        panel.animateVisibleSidebarWidth(
            expandedWidth,
            animation: .easeInOut(duration: panel.animationDuration)
        )
    }

    func isFolderExpanded(_ projectId: WorkspaceProjectId) -> Bool {
        folderExpansionOverrides[projectId] ?? workspaceSidebarFolderIsExpanded(projectId)
    }

    func setFolderExpanded(_ projectId: WorkspaceProjectId, _ isExpanded: Bool) {
        if isExpanded {
            folderExpansionOverrides = Dictionary(uniqueKeysWithValues: snapshot.projects.map {
                ($0.id, $0.id == projectId)
            })
            folderExpansionOverrides[projectId] = true
        } else {
            folderExpansionOverrides[projectId] = false
        }
        setWorkspaceSidebarFolderExpanded(projectId, isExpanded: isExpanded)
    }

    func syncFolderExpansionOverrides() {
        folderExpansionOverrides = Dictionary(uniqueKeysWithValues: snapshot.projects.map {
            ($0.id, workspaceSidebarFolderIsExpanded($0.id))
        })
    }

    func beginProjectRename(_ project: WorkspaceSidebarProjectViewModel, browseIfNeeded: Bool = true) {
        debugWorkspaceSidebarRenameLog("beginProjectRename project=\(project.id.rawValue) displayName=\(project.displayName) active=\(snapshot.activeProjectId.rawValue) visibleWidth=\(snapshot.visibleWidth)")
        finishSidebarSearch(clearText: false)
        if browseIfNeeded && project.id != snapshot.activeProjectId {
            browseMode = .split(otherProjectId: project.id)
        }
        renamingProjectId = project.id
        renamingProjectText = project.displayName
        isProjectMenuOpen = false
        currentPanel()?.prepareForInlineTextEditing()
    }

    func finishProjectRename(cancelled: Bool = false) {
        guard let projectId = renamingProjectId else { return }
        let displayName = renamingProjectText.trimmingCharacters(in: .whitespacesAndNewlines)
        debugWorkspaceSidebarRenameLog("finishProjectRename project=\(projectId.rawValue) cancelled=\(cancelled) raw=\(renamingProjectText) trimmed=\(displayName)")
        renamingProjectId = nil
        renamingProjectText = ""
        currentPanel()?.endInlineTextEditing()
        guard !cancelled, !displayName.isEmpty else { return }
        actions.send(.renameProject(projectId, displayName: displayName))
    }

    func beginWorkspaceRename(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
        debugWorkspaceSidebarRenameLog("beginWorkspaceRename workspace=\(workspace.name) displayName=\(workspace.displayName) targetScope=\(snapshot.targetMonitorScopeId) activeProject=\(snapshot.activeProjectId.rawValue) visibleWidth=\(snapshot.visibleWidth)")
        finishSidebarSearch(clearText: false)
        finishProjectRename(cancelled: true)
        committedWorkspaceRenameName = nil
        renamingWorkspaceName = workspace.name
        renamingWorkspaceText = workspace.displayName
        currentPanel()?.prepareForInlineTextEditing()
    }

    func finishWorkspaceRename(cancelled: Bool = false) {
        guard let workspaceName = renamingWorkspaceName else { return }
        let displayName = renamingWorkspaceText.trimmingCharacters(in: .whitespacesAndNewlines)
        debugWorkspaceSidebarRenameLog("finishWorkspaceRename workspace=\(workspaceName) cancelled=\(cancelled) raw=\(renamingWorkspaceText) trimmed=\(displayName) targetScope=\(snapshot.targetMonitorScopeId)")
        currentPanel()?.endInlineTextEditing()
        guard !cancelled, !displayName.isEmpty else {
            clearWorkspaceRenameState()
            return
        }
        committedWorkspaceRenameName = workspaceName
        renamingWorkspaceText = displayName
        actions.send(.renameWorkspace(workspaceName, displayName: displayName))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard committedWorkspaceRenameName == workspaceName else { return }
            clearWorkspaceRenameState()
        }
    }

    func clearWorkspaceRenameState() {
        renamingWorkspaceName = nil
        renamingWorkspaceText = ""
        committedWorkspaceRenameName = nil
        currentPanel()?.endInlineTextEditing()
    }

    func reconcileWorkspaceRenameState() {
        guard let renamingWorkspaceName else { return }
        let renamedWorkspace = snapshot.workspaces.first { workspace in
            workspace.name == renamingWorkspaceName
        }
        if renamedWorkspace == nil {
            finishWorkspaceRename(cancelled: true)
        } else if committedWorkspaceRenameName == renamingWorkspaceName,
                  renamedWorkspace?.displayName == renamingWorkspaceText
        {
            clearWorkspaceRenameState()
        }
    }

    func currentPanel() -> WorkspaceSidebarPanel? {
        WorkspaceSidebarPanel.panel(for: snapshot.targetMonitorScopeId)
    }

    func beginSidebarSearchIfNeeded(panel: WorkspaceSidebarPanel? = nil) {
        guard workspaceSidebarSearchIsEnabled else {
            finishSidebarSearch(clearText: true)
            return
        }
        guard renamingProjectId == nil, renamingWorkspaceName == nil, !isSearchEditing else { return }
        guard snapshot.visibleWidth > snapshot.configuration.collapsedWidth + 0.5 || isSidebarExpanding else { return }
        let editingPanel = panel ?? currentPanel() ?? WorkspaceSidebarPanel.shared
        adoptCommandSidebarSearchIfNeeded(panel: editingPanel)
    }

    func adoptCommandSidebarSearchIfNeeded(panel editingPanel: WorkspaceSidebarPanel) {
        guard workspaceSidebarSearchIsEnabled else {
            editingPanel.shouldLockNextSidebarSearchExpansion = false
            editingPanel.bufferedCommandSidebarSearchKeys = []
            finishSidebarSearch(clearText: true)
            return
        }
        guard renamingProjectId == nil, renamingWorkspaceName == nil else { return }
        if !isSearchEditing {
            isSearchEditing = true
            searchEditingPanel = editingPanel
            selectFirstSearchTarget()
        }
        let locksExpansion = editingPanel.commandExpansionLocksCollapse || editingPanel.shouldLockNextSidebarSearchExpansion
        editingPanel.shouldLockNextSidebarSearchExpansion = false
        editingPanel.beginInlineTextEditing(
            locksExpansion: locksExpansion,
            cancelsOnPointerExit: false,
            onCancel: {
                finishSidebarSearch(clearText: true)
            },
            onKeyDown: { key in
                handleSidebarSearchKey(key)
            },
        )
        let bufferedKeys = editingPanel.bufferedCommandSidebarSearchKeys
        editingPanel.bufferedCommandSidebarSearchKeys = []
        for key in bufferedKeys {
            handleSidebarSearchKey(key)
        }
    }

    func finishSidebarSearch(clearText: Bool) {
        let panel = searchEditingPanel
        if isSearchEditing {
            isSearchEditing = false
            (panel ?? currentPanel() ?? WorkspaceSidebarPanel.shared).endInlineTextEditing()
            searchEditingPanel = nil
        }
        if clearText {
            searchText = ""
        }
        selectedSearchTarget = nil
    }

    func handleSidebarSearchKey(_ key: WorkspaceSidebarInlineTextKey) {
        guard workspaceSidebarSearchIsEnabled else {
            finishSidebarSearch(clearText: true)
            return
        }
        switch key {
            case .text(let inserted):
                searchText += inserted
                selectFirstSearchTarget()
            case .deleteBackward:
                if !searchText.isEmpty {
                    searchText.removeLast()
                }
                selectFirstSearchTarget()
            case .deleteWordBackward:
                searchText.deleteLastWord()
                selectFirstSearchTarget()
            case .deleteToBeginningOfLine:
                searchText = ""
                selectedSearchTarget = nil
            case .deleteForward:
                break
            case .commit:
                activateSelectedSearchTarget()
            case .cancel:
                let panel = searchEditingPanel ?? WorkspaceSidebarPanel.shared
                finishSidebarSearch(clearText: true)
                closeWorkspaceSidebarFromCommand(panel)
            case .moveUp:
                moveSearchSelection(delta: -1)
            case .moveDown:
                moveSearchSelection(delta: 1)
            case .ignored:
                break
        }
    }

    func selectFirstSearchTarget() {
        selectedSearchTarget = searchText.isEmpty ? nil : currentSearchSelections().first
    }

    func moveSearchSelection(delta: Int) {
        let selections = currentSearchSelections()
        guard !selections.isEmpty else {
            selectedSearchTarget = nil
            return
        }
        guard let selectedSearchTarget,
              let index = selections.firstIndex(of: selectedSearchTarget)
        else {
            self.selectedSearchTarget = selections.first
            return
        }
        let nextIndex = max(0, min(selections.count - 1, index + delta))
        self.selectedSearchTarget = selections[nextIndex]
    }

    func activateSelectedSearchTarget() {
        guard let selectedSearchTarget else { return }
        let panel = searchEditingPanel ?? WorkspaceSidebarPanel.shared
        switch selectedSearchTarget {
            case .workspace(let workspaceName):
                beginPendingWorkspaceActivation(workspaceName)
                actions.send(.selectWorkspace(workspaceName))
        }
        finishSidebarSearch(clearText: true)
        closeWorkspaceSidebarFromCommand(panel)
    }

    func currentSearchSelections() -> [WorkspaceSidebarSearchSelection] {
        let workspaces = currentFilteredProjectWorkspaces()
        return workspaceSidebarSearchSelections(workspaces: workspaces)
    }

    func currentFilteredProjectWorkspaces() -> [WorkspaceSidebarWorkspaceViewModel] {
        let visibleWorkspacesByProject = workspaceSidebarVisibleWorkspacesByProject(
            workspaces: snapshot.workspaces,
            selectedScopeId: snapshot.selectedMonitorScopeId,
            focusedMonitorScopeId: snapshot.focusedMonitorScopeId,
            targetMonitorScopeId: snapshot.targetMonitorScopeId,
            browsedProjectId: browsedProjectId,
            projectsEnabled: projectsAreEnabled(),
        )
        let filteredWorkspacesByProject = workspaceSidebarFilteredWorkspacesByProject(
            visibleWorkspacesByProject,
            projects: snapshot.projects,
            query: sidebarSearchQuery,
        )
        let projectId: WorkspaceProjectId
        if let index = projectPagerDisplayIndex, snapshot.projects.indices.contains(index) {
            projectId = snapshot.projects[index].id
        } else {
            projectId = snapshot.activeProjectId
        }
        return filteredWorkspacesByProject[projectId] ?? []
    }
}

extension WorkspaceSidebarView {
    var browsedProjectId: WorkspaceProjectId? {
        browseMode.otherProjectId
    }

    var sidebarSearchQuery: String {
        workspaceSidebarEffectiveSearchQuery(searchText)
    }

    var isSidebarSearchFiltering: Bool {
        !sidebarSearchQuery.isEmpty
    }
}

private func workspaceSidebarDragPointer(from notification: Notification) -> CGPoint? {
    (notification.userInfo?[workspaceSidebarDragPointerUserInfoKey] as? NSValue)?.pointValue
}

private func notificationPanel(from notification: Notification) -> WorkspaceSidebarPanel? {
    notification.object as? WorkspaceSidebarPanel
}

struct WorkspaceSidebarContainerView: View {
    @ObservedObject var viewModel: TrayMenuModel
    let actions: WorkspaceSidebarActions
    @AppStorage(workspaceSidebarShowsNotePadPreferenceKey) private var showsNotePad = true
    @AppStorage(workspaceSidebarShowsTasksPreferenceKey) private var showsTasks = true

    var body: some View {
        WorkspaceSidebarView(
            snapshot: workspaceSidebarSnapshot(from: viewModel),
            actions: actions,
            showsNotePad: showsNotePad,
            onToggleNotePad: {
                showsNotePad.toggle()
            },
            showsTasks: showsTasks,
            onToggleTasks: {
                showsTasks.toggle()
            },
        )
    }
}
