import AppKit
import Common
import SwiftUI

@MainActor
func focusWorkspaceFromSidebar(_ workspaceName: String, targetMonitorScopeId: String? = nil) {
    WorkspaceSidebarPanel.suppressEdgeTrapForWorkspaceActivation()
    runWorkspaceSidebarSession {
        guard let workspace = Workspace.existing(byName: workspaceName) else { return }
        _ = focusWorkspaceFromSidebar(workspace, targetMonitorScopeId: targetMonitorScopeId)
    }
}

@MainActor
func focusWorkspaceFromSidebar(_ workspace: Workspace, targetMonitorScopeId: String? = nil) -> Bool {
    guard let targetMonitorScopeId,
          let targetMonitor = workspaceSidebarMonitor(forScopeId: targetMonitorScopeId)
    else {
        return workspace.focusWorkspace()
    }

    if workspace.isVisible {
        guard workspace.workspaceMonitor.rect.topLeftCorner == targetMonitor.rect.topLeftCorner else {
            return false
        }
        return workspace.focusWorkspace()
    }

    guard targetMonitor.setActiveWorkspace(workspace) else { return false }
    return workspace.focusWorkspace()
}

@MainActor
func overrideWorkspaceInUseFromSidebar(_ workspaceName: String, targetMonitorScopeId: String? = nil) {
    WorkspaceSidebarPanel.suppressEdgeTrapForWorkspaceActivation()
    runWorkspaceSidebarSession {
        guard let workspace = Workspace.existing(byName: workspaceName),
              let targetMonitorScopeId,
              let targetMonitor = workspaceSidebarMonitor(forScopeId: targetMonitorScopeId)
        else { return }
        _ = overrideWorkspaceOnMonitorBySwappingActiveViewports(workspace, targetMonitor: targetMonitor)
        _ = workspace.focusWorkspace()
    }
}

@MainActor
func runWorkspaceSidebarSession(_ body: @escaping @MainActor () async throws -> Void) {
    guard let token: RunSessionGuard = .isServerEnabled else { return }
    Task { @MainActor in
        do {
            try await runLightSession(.menuBarButton, token) {
                try await body()
            }
        } catch {
            showWorkspaceSidebarError(error.localizedDescription)
        }
    }
}

@MainActor
func showWorkspaceSidebarError(_ body: String) {
    MessageModel.shared.message = Message(
        description: "Tab Sidebar Error",
        body: body,
    )
}

@MainActor
func setWorkspaceSidebarPinnedExpanded(
    _ isPinned: Bool,
    viewModel: TrayMenuModel = TrayMenuModel.shared,
) {
    setWorkspaceSidebarPinnedExpandedPreference(isPinned)
    viewModel.isWorkspaceSidebarPinnedExpanded = isPinned
    for panel in WorkspaceSidebarPanel.visiblePanels {
        panel.viewModel.isWorkspaceSidebarPinnedExpanded = isPinned
        panel.cancelExpansionWork()
        if isPinned {
            panel.expandSidebar(to: CGFloat(config.workspaceSidebar.width))
        } else {
            panel.updateHoverStateFromMousePosition()
        }
    }
    WorkspaceSidebarPanel.refreshAll()
}

@MainActor
func sidebarWorkspaceTargetMonitor(fallbackWindow: Window? = nil, fallbackPoint: CGPoint? = nil) -> Monitor {
    workspaceSidebarTargetMonitor(
        selectedMonitor: selectedWorkspaceSidebarMonitorScope(),
        fallbackPoint: fallbackPoint,
        fallbackWindowMonitor: fallbackWindow?.nodeMonitor,
        focusedMonitor: focus.workspace.workspaceMonitor,
    )
}

@MainActor
func workspaceSidebarTargetMonitor(
    selectedMonitor: Monitor?,
    fallbackPoint: CGPoint?,
    fallbackWindowMonitor: Monitor?,
    focusedMonitor: Monitor,
) -> Monitor {
    selectedMonitor ??
        fallbackPoint?.monitorApproximation ??
        fallbackWindowMonitor ??
        focusedMonitor
}

@MainActor
func selectedWorkspaceSidebarMonitorScope() -> Monitor? {
    let selectedScopeId = TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId
    guard selectedScopeId != workspaceSidebarDefaultScopeId,
          selectedScopeId != workspaceSidebarFocusedScopeId
    else {
        return nil
    }
    return sortedMonitors.first { workspaceSidebarMonitorScopeId(for: $0) == selectedScopeId }
}

@MainActor
func workspaceSidebarTargetMonitor(
    scopeId: String,
    fallbackWindow: Window? = nil,
    fallbackPoint: CGPoint? = nil,
) -> Monitor {
    let selectedMonitor = workspaceSidebarMonitorForScopeId(scopeId)
    return workspaceSidebarTargetMonitor(
        selectedMonitor: selectedMonitor,
        fallbackPoint: fallbackPoint,
        fallbackWindowMonitor: fallbackWindow?.nodeMonitor,
        focusedMonitor: focus.workspace.workspaceMonitor,
    )
}

@MainActor
private func workspaceSidebarMonitorForScopeId(_ scopeId: String) -> Monitor? {
    guard scopeId != workspaceSidebarDefaultScopeId,
          scopeId != workspaceSidebarFocusedScopeId
    else {
        return nil
    }
    return sortedMonitors.first { workspaceSidebarMonitorScopeId(for: $0) == scopeId }
}

func workspaceSidebarWorkspaceCreateScope(
    selectedScopeId: String,
    targetMonitorScopeId: String,
    focusedScopeId: String,
) -> String {
    switch selectedScopeId {
        case workspaceSidebarDefaultScopeId:
            targetMonitorScopeId
        case workspaceSidebarFocusedScopeId:
            focusedScopeId
        default:
            selectedScopeId
    }
}

@MainActor
func selectWorkspaceSidebarMonitorScope(_ scopeId: String, viewModel: TrayMenuModel = TrayMenuModel.shared) {
    guard viewModel.workspaceSidebarMonitorScopes.contains(where: { $0.id == scopeId }) else { return }
    guard viewModel.workspaceSidebarSelectedMonitorScopeId != scopeId else { return }
    viewModel.workspaceSidebarSelectedMonitorScopeId = scopeId
    let visibleWorkspaceNames = Set(viewModel.visibleWorkspaceSidebarWorkspaces.map(\.name))
    let sanitizedHoveredWorkspaceName = sanitizedWorkspaceSidebarHoveredWorkspaceName(
        visibleWorkspaceNames: visibleWorkspaceNames,
        hoveredWorkspaceName: viewModel.workspaceSidebarHoveredWorkspaceName,
    )
    if viewModel.workspaceSidebarHoveredWorkspaceName != sanitizedHoveredWorkspaceName {
        viewModel.workspaceSidebarHoveredWorkspaceName = sanitizedHoveredWorkspaceName
    }
}

@MainActor
func createWorkspaceFromSidebarButton() {
    let targetMonitor = sidebarWorkspaceTargetMonitor()
    createWorkspaceFromSidebarButton(
        projectId: activeWorkspaceProjectId(for: targetMonitor),
        monitorScopeId: TrayMenuModel.shared.workspaceSidebarSelectedMonitorScopeId,
    )
}

@MainActor
func createWorkspaceFromSidebarButton(projectId: WorkspaceProjectId, monitorScopeId: String) {
    runWorkspaceSidebarSession {
        let targetMonitor = workspaceSidebarTargetMonitor(scopeId: monitorScopeId)
        let workspace = createFreshAdjacentBlankWorkspace(
            projectId: projectId,
            monitor: targetMonitor,
            after: targetMonitor.activeWorkspace,
        )
        _ = workspace.focusWorkspace()
    }
}

@MainActor
func closeWindowFromSidebar(_ windowId: UInt32) {
    runWorkspaceSidebarSession {
        var args = CloseCmdArgs(rawArgs: [])
        args.windowId = windowId
        _ = try await CloseCommand(args: args).run(.defaultEnv, .emptyStdin)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func createWorkspaceFromSidebarDrag(sourceNode: TreeNode, sourceWindow: Window) -> Bool {
    createWorkspaceFromSidebarDrag(sourceNode: sourceNode, sourceWindow: sourceWindow, projectId: nil, monitorScopeId: nil)
}

@MainActor
func createWorkspaceFromSidebarDrag(
    sourceNode: TreeNode,
    sourceWindow: Window,
    projectId: WorkspaceProjectId?,
    monitorScopeId: String?,
) -> Bool {
    let targetMonitor = monitorScopeId.map {
        workspaceSidebarTargetMonitor(
            scopeId: $0,
            fallbackWindow: sourceWindow,
            fallbackPoint: mouseLocation,
        )
    } ?? sidebarWorkspaceTargetMonitor(fallbackWindow: sourceWindow, fallbackPoint: mouseLocation)
    let projectId = projectId ?? activeWorkspaceProjectId(for: targetMonitor)
    let workspace = getOrCreateAdjacentBlankWorkspace(projectId: projectId, monitor: targetMonitor)
    let targetContainer: NonLeafTreeNodeObject
    if sourceNode is Window, sourceWindow.isFloating {
        targetContainer = workspace
    } else {
        targetContainer = workspace.rootTilingContainer
    }
    sourceNode.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    return true
}

@MainActor
func moveWindowFromSidebar(_ windowId: UInt32, toWorkspace workspaceName: String) {
    moveSidebarSource(windowId, subject: .window, toWorkspace: workspaceName)
}

@MainActor
func moveTabGroupFromSidebar(_ windowId: UInt32, toWorkspace workspaceName: String) {
    moveSidebarSource(windowId, subject: .group, toWorkspace: workspaceName)
}

@MainActor
func moveWindowToNewWorkspaceFromSidebar(_ windowId: UInt32, projectId: WorkspaceProjectId, monitorScopeId: String) {
    moveSidebarSourceToNewWorkspace(windowId, subject: .window, projectId: projectId, monitorScopeId: monitorScopeId)
}

@MainActor
func moveTabGroupToNewWorkspaceFromSidebar(_ windowId: UInt32, projectId: WorkspaceProjectId, monitorScopeId: String) {
    moveSidebarSourceToNewWorkspace(windowId, subject: .group, projectId: projectId, monitorScopeId: monitorScopeId)
}

@MainActor
private func moveSidebarSource(_ windowId: UInt32, subject: WindowDragSubject, toWorkspace workspaceName: String) {
    runWorkspaceSidebarSession {
        guard applySidebarSource(windowId, subject: subject, toWorkspace: workspaceName) else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
private func moveSidebarSourceToNewWorkspace(
    _ windowId: UInt32,
    subject: WindowDragSubject,
    projectId: WorkspaceProjectId,
    monitorScopeId: String,
) {
    runWorkspaceSidebarSession {
        guard applySidebarSourceToNewWorkspace(
            windowId,
            subject: subject,
            projectId: projectId,
            monitorScopeId: monitorScopeId
        ) else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
private func applySidebarSource(_ windowId: UInt32, subject: WindowDragSubject, toWorkspace workspaceName: String) -> Bool {
    guard let sourceWindow = Window.get(byId: windowId),
          let targetWorkspace = Workspace.existing(byName: workspaceName)
    else { return false }
    let sourceNode = dragSubjectNode(for: sourceWindow, subject: subject)
    syncClosedWindowsCacheToCurrentWorld()
    suppressPostDragAxObserverEvents(for: sourceNode.allLeafWindowsRecursive.map(\.windowId))
    applySidebarWorkspaceMove(sourceNode: sourceNode, sourceWindow: sourceWindow, targetWorkspace: targetWorkspace)
    return true
}

@MainActor
private func applySidebarSourceToNewWorkspace(
    _ windowId: UInt32,
    subject: WindowDragSubject,
    projectId: WorkspaceProjectId,
    monitorScopeId: String,
) -> Bool {
    guard let sourceWindow = Window.get(byId: windowId) else { return false }
    let sourceNode = dragSubjectNode(for: sourceWindow, subject: subject)
    let targetMonitor = workspaceSidebarTargetMonitor(
        scopeId: monitorScopeId,
        fallbackWindow: sourceWindow,
        fallbackPoint: mouseLocation,
    )
    let workspace = getOrCreateAdjacentBlankWorkspace(projectId: projectId, monitor: targetMonitor)
    let targetContainer: NonLeafTreeNodeObject = sourceNode is Window && sourceWindow.isFloating
        ? workspace
        : workspace.rootTilingContainer
    syncClosedWindowsCacheToCurrentWorld()
    suppressPostDragAxObserverEvents(for: sourceNode.allLeafWindowsRecursive.map(\.windowId))
    sourceNode.bind(to: targetContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    return true
}

@MainActor
func previewWorkspaceSidebarDrop(_ windowId: UInt32, subject: WindowDragSubject, target: WorkspaceSidebarDropTargetKind) {
    guard let sourceWindow = Window.get(byId: windowId) else {
        clearWorkspaceSidebarDropPreview()
        return
    }
    guard isActionableSidebarDropTarget(sourceWindow: sourceWindow, subject: subject, target: target) else {
        clearWorkspaceSidebarDropPreview()
        return
    }
    guard case .workspace(let workspaceName) = target else {
        if case .newWorkspace(let projectId, let monitorScopeId) = target {
            setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(
                sourceWindow: sourceWindow,
                subject: subject,
                targetWorkspaceName: nil,
                targetsNewWorkspace: true,
                targetProjectId: projectId,
                targetMonitorScopeId: monitorScopeId,
            ))
        } else if case .folder(let projectId, let monitorScopeId) = target {
            setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(
                sourceWindow: sourceWindow,
                subject: subject,
                targetWorkspaceName: nil,
                targetsNewWorkspace: false,
                targetProjectId: projectId,
                targetMonitorScopeId: monitorScopeId,
            ))
        } else {
            clearWorkspaceSidebarDropPreview()
        }
        return
    }
    setWorkspaceSidebarDropPreviewIfChanged(workspaceSidebarDropPreview(
        sourceWindow: sourceWindow,
        subject: subject,
        targetWorkspaceName: workspaceName,
        targetsNewWorkspace: false,
        targetProjectId: nil,
    ))
}

@MainActor
func clearWorkspaceSidebarDropPreview() {
    setWorkspaceSidebarDropPreviewIfChanged(nil)
}

@MainActor
func workspaceSidebarSourcePreview(sourceWindow: Window, subject: WindowDragSubject) -> WorkspaceSidebarDropPreviewViewModel {
    workspaceSidebarDropPreview(
        sourceWindow: sourceWindow,
        subject: subject,
        targetWorkspaceName: nil,
        targetsNewWorkspace: false,
    )
}

@MainActor
func showWorkspaceSidebarDragCursorPreview(sourceWindow: Window, subject: WindowDragSubject, point: CGPoint) {
    WindowDragCursorProxyPanel.shared.show(
        preview: workspaceSidebarSourcePreview(sourceWindow: sourceWindow, subject: subject),
        mouseScreenPoint: denormalizedAppKitScreenPoint(point),
    )
}

func denormalizedAppKitScreenPoint(_ point: CGPoint) -> CGPoint {
    normalizeAppKitScreenPoint(point)
}

@MainActor
private func isActionableSidebarDropTarget(
    sourceWindow: Window,
    subject: WindowDragSubject,
    target: WorkspaceSidebarDropTargetKind,
) -> Bool {
    let sourceWorkspaceName = dragSubjectNode(for: sourceWindow, subject: subject).nodeWorkspace?.name
    return isActionableSidebarWorkspaceDropTarget(sourceWorkspaceName: sourceWorkspaceName, targetKind: target)
}

@MainActor
private func workspaceSidebarDropPreview(
    sourceWindow: Window,
    subject: WindowDragSubject,
    targetWorkspaceName: String?,
    targetsNewWorkspace: Bool,
    targetProjectId: WorkspaceProjectId? = nil,
    targetMonitorScopeId: String? = nil,
) -> WorkspaceSidebarDropPreviewViewModel {
    let moveNode = dragSubjectNode(for: sourceWindow, subject: subject)
    let isTabGroup = moveNode is TilingContainer
    let sourceLabel = sidebarDragSourceTitle(for: sourceWindow, subject: subject)
    let appName = sourceWindow.app.name ?? sourceWindow.app.rawAppBundleId ?? "Window"
    return WorkspaceSidebarDropPreviewViewModel(
        sourceWindowId: sourceWindow.windowId,
        label: sourceLabel,
        appName: appName,
        appBundleIdentifier: sourceWindow.app.rawAppBundleId,
        appBundlePath: sourceWindow.app.bundlePath,
        targetWorkspaceName: targetWorkspaceName,
        targetsNewWorkspace: targetsNewWorkspace,
        targetProjectId: targetProjectId,
        targetMonitorScopeId: targetMonitorScopeId,
        isTabGroup: isTabGroup,
        windowCount: max(moveNode.allLeafWindowsRecursive.count, 1),
        tabItems: workspaceSidebarDropPreviewTabs(for: moveNode, isTabGroup: isTabGroup),
    )
}

@MainActor
private func workspaceSidebarDropPreviewTabs(
    for moveNode: TreeNode,
    isTabGroup: Bool,
) -> [WorkspaceSidebarDropPreviewTabItem] {
    guard isTabGroup else { return [] }
    return moveNode.allLeafWindowsRecursive.map { window in
        let appName = window.app.name ?? window.app.rawAppBundleId ?? "Window"
        return WorkspaceSidebarDropPreviewTabItem(
            title: cachedWindowTitle(for: window)?.takeIf { $0 != appName } ?? appName,
            appName: appName,
            appBundleIdentifier: window.app.rawAppBundleId,
            appBundlePath: window.app.bundlePath,
        )
    }
}

@MainActor
func selectWorkspaceSidebarProject(
    _ projectId: WorkspaceProjectId,
    viewModel: TrayMenuModel = TrayMenuModel.shared,
    targetMonitorScopeId: String? = nil,
) {
    let knownProjects = workspaceProjects()
    let resolvedTargetScopeId = targetMonitorScopeId ?? viewModel.workspaceSidebarTargetMonitorScopeId
    debugWorkspaceSidebarProjectLog(
        "selectProjectBegin project=\(projectId.rawValue) known=\(knownProjects.map(\.id.rawValue)) targetScope=\(resolvedTargetScopeId) activeBefore=\(viewModel.workspaceSidebarActiveProjectId.rawValue)"
    )
    guard knownProjects.contains(where: { $0.id == projectId }) else {
        debugWorkspaceSidebarProjectLog("selectProjectAbort unknownProject=\(projectId.rawValue)")
        return
    }
    runWorkspaceSidebarSession {
        let monitor = workspaceSidebarTargetMonitor(
            scopeId: targetMonitorScopeId ?? viewModel.workspaceSidebarTargetMonitorScopeId
        )
        debugWorkspaceSidebarProjectLog(
            "selectProjectSession project=\(projectId.rawValue) monitor=\(monitor.monitorAppKitNsScreenScreensId) visibleBefore=\(monitor.activeWorkspace.name) activeProjectBefore=\(activeWorkspaceProjectId(for: monitor).rawValue)"
        )
        if let workspace = switchWorkspaceProject(projectId, on: monitor) {
            debugWorkspaceSidebarProjectLog(
                "selectProjectSwitchResult project=\(projectId.rawValue) workspace=\(workspace.name) workspaceProject=\(workspace.projectId.rawValue)"
            )
            _ = workspace.focusWorkspace()
            viewModel.workspaceSidebarActiveProjectId = projectId
        } else {
            debugWorkspaceSidebarProjectLog("selectProjectSwitchResult project=\(projectId.rawValue) workspace=nil")
        }
        await updateWorkspaceSidebarModel()
        debugWorkspaceSidebarProjectLog(
            "selectProjectEnd project=\(projectId.rawValue) activeAfter=\(viewModel.workspaceSidebarActiveProjectId.rawValue)"
        )
    }
}

@MainActor
func createWorkspaceSidebarProject(
    viewModel: TrayMenuModel = TrayMenuModel.shared,
    targetMonitorScopeId: String? = nil,
) {
    runWorkspaceSidebarSession {
        let project = createWorkspaceProject()
        let monitor = workspaceSidebarTargetMonitor(
            scopeId: targetMonitorScopeId ?? viewModel.workspaceSidebarTargetMonitorScopeId
        )
        if let workspace = switchWorkspaceProject(project.id, on: monitor) {
            _ = workspace.focusWorkspace()
            viewModel.workspaceSidebarActiveProjectId = project.id
        }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func createWorkspaceSidebarFolder(
    viewModel: TrayMenuModel = TrayMenuModel.shared,
) {
    runWorkspaceSidebarSession {
        let project = createWorkspaceSidebarFolderProject()
        try renameWorkspaceProject(project.id, displayName: workspaceSidebarDefaultFolderName(project))
        setWorkspaceSidebarFolderExpanded(project.id, isExpanded: true)
        viewModel.workspaceSidebarActiveProjectId = workspaceProjectDefaultId
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
private func createWorkspaceSidebarFolderProject() -> WorkspaceProject {
    materializePersistedWorkspaceProjects()
    let identity = winMuxWorkspaceState.nextGeneratedProjectIdentity()
    let order = winMuxWorkspaceState.nextProjectOrder()
    let project = WorkspaceProject(id: identity.id, name: identity.name, order: order)
    winMuxWorkspaceState.registerProject(project)
    return project
}

private func workspaceSidebarDefaultFolderName(_ project: WorkspaceProject) -> String {
    workspaceSidebarFolderDisplayName(project.name)
}

@MainActor
func renameWorkspaceSidebarProject(_ projectId: WorkspaceProjectId, displayName: String) {
    runWorkspaceSidebarSession {
        try renameWorkspaceProject(projectId, displayName: displayName)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func setWorkspaceSidebarProjectColor(_ project: WorkspaceSidebarProjectViewModel, colorHex: String?) {
    runWorkspaceSidebarSession {
        let normalizedColorHex = colorHex.flatMap(normalizedWorkspaceSidebarColorHex)
        if let normalizedColorHex {
            config.workspaceSidebar.projectColors[project.id.rawValue] = normalizedColorHex
        } else {
            config.workspaceSidebar.projectColors.removeValue(forKey: project.id.rawValue)
        }
        if !isUnitTest {
            try persistWorkspaceSidebarProjectColor(projectId: project.id.rawValue, colorHex: normalizedColorHex)
        }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func deleteWorkspaceSidebarProject(
    _ project: WorkspaceSidebarProjectViewModel,
    viewModel: TrayMenuModel = TrayMenuModel.shared,
) {
    guard canDeleteWorkspaceProject(project.id) else { return }
    guard confirmWorkspaceSidebarProjectDeletion(project) else { return }
    runWorkspaceSidebarSession {
        try await deleteWorkspaceProjectFromSidebar(project.id)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
private func confirmWorkspaceSidebarProjectDeletion(_ project: WorkspaceSidebarProjectViewModel) -> Bool {
    let windowCount = windowsInWorkspaceProject(project.id).count
    guard windowCount > 0 else { return true }

    let alert = NSAlert()
    switch config.workspaceSidebar.projectDeletionAction {
        case .closeWindows:
            alert.messageText = "Close Folder Windows?"
            alert.informativeText = """
            WinMux will ask macOS to close \(windowCount) window\(windowCount == 1 ? "" : "s") in “\(project.displayName)”. Apps may show their own confirmation dialogs for unsaved work. If any window stays open, WinMux will keep the folder.
            """
            alert.addButton(withTitle: "Close Folder")
        case .moveWindowsToFallback:
            alert.messageText = "Delete Folder?"
            alert.informativeText = """
            WinMux will delete “\(project.displayName)” and move \(windowCount) window\(windowCount == 1 ? "" : "s") to another folder.
            """
            alert.addButton(withTitle: "Delete Folder")
    }
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning
    return alert.runModal() == .alertFirstButtonReturn
}

@MainActor
func renameWorkspaceFromSidebar(_ workspaceName: String, displayName: String) {
    debugWorkspaceSidebarRenameLog("renameWorkspaceFromSidebar workspace=\(workspaceName) displayName=\(displayName)")
    runWorkspaceSidebarSession {
        try renameWorkspaceForSidebar(workspaceName: workspaceName, displayName: displayName)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func deleteWorkspaceFromSidebar(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
    runWorkspaceSidebarSession {
        try deleteWorkspaceForSidebar(workspaceName: workspace.name)
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func reorderWorkspaceFromSidebar(_ workspaceName: String, projectId: WorkspaceProjectId, placement: WorkspaceReorderPlacement) {
    runWorkspaceSidebarSession {
        let didReorder = reorderWorkspaceForSidebar(
            sourceWorkspaceName: workspaceName,
            projectId: projectId,
            placement: placement
        )
        guard didReorder else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func createFolderFromWorkspacesFromSidebar(
    sourceWorkspaceName: String,
    targetWorkspaceName: String
) {
    runWorkspaceSidebarSession {
        guard createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: sourceWorkspaceName,
            targetWorkspaceName: targetWorkspaceName
        ) else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func moveWorkspaceToFolderFromSidebar(
    _ workspaceName: String,
    projectId: WorkspaceProjectId
) {
    runWorkspaceSidebarSession {
        guard moveWorkspaceToSidebarFolder(workspaceName, projectId: projectId) else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
func mergeWorkspacesFromSidebar(
    sourceWorkspaceName: String,
    targetWorkspaceName: String,
    position: WindowStackSplitPosition
) {
    runWorkspaceSidebarSession {
        guard mergeWorkspaceTab(
            sourceWorkspaceName: sourceWorkspaceName,
            targetWorkspaceName: targetWorkspaceName,
            position: position
        ) else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
@discardableResult
func createSidebarFolderFromWorkspaces(
    sourceWorkspaceName: String,
    targetWorkspaceName: String
) -> Bool {
    materializePersistedWorkspaceProjects()
    guard sourceWorkspaceName != targetWorkspaceName,
          let sourceWorkspace = Workspace.existing(byName: sourceWorkspaceName),
          let targetWorkspace = Workspace.existing(byName: targetWorkspaceName),
          !sourceWorkspace.isArchived,
          !targetWorkspace.isArchived
    else { return false }
    if let sourceMonitor = sourceWorkspace.visibleMonitor,
       let targetMonitor = targetWorkspace.visibleMonitor,
       sourceMonitor.rect.topLeftCorner != targetMonitor.rect.topLeftCorner
    {
        return false
    }

    let folderWorkspaces = orderedWorkspacesForPresentation()
        .filter { $0 == sourceWorkspace || $0 == targetWorkspace }
    let orderedFolderWorkspaces = folderWorkspaces.count == 2 ? folderWorkspaces : [targetWorkspace, sourceWorkspace]
    let project = createWorkspaceSidebarFolderProject()
    do {
        try renameWorkspaceProject(project.id, displayName: workspaceSidebarDefaultFolderName(project))
    } catch {
        return false
    }
    for workspace in orderedFolderWorkspaces {
        workspace.assignProject(project.id)
    }
    var storedProject = winMuxWorkspaceState.projectsById[project.id].orDie()
    storedProject.workspaceOrder = orderedFolderWorkspaces.map(\.id)
    winMuxWorkspaceState.projectsById[project.id] = storedProject
    setWorkspaceSidebarFolderExpanded(project.id, isExpanded: true)
    checkWorkspaceHierarchyInvariants()
    return true
}

@MainActor
@discardableResult
func moveWorkspaceToSidebarFolder(
    _ workspaceName: String,
    projectId: WorkspaceProjectId
) -> Bool {
    materializePersistedWorkspaceProjects()
    guard var project = winMuxWorkspaceState.projectsById[projectId],
          let workspace = Workspace.existing(byName: workspaceName),
          workspace.projectId != projectId,
          !workspace.isArchived
    else { return false }
    workspace.assignProject(projectId)
    project.workspaceOrder.removeAll { $0 == workspace.id }
    project.workspaceOrder.append(workspace.id)
    winMuxWorkspaceState.projectsById[projectId] = project
    if projectId != workspaceProjectDefaultId {
        setWorkspaceSidebarFolderExpanded(projectId, isExpanded: true)
    }
    checkWorkspaceHierarchyInvariants()
    return true
}

@MainActor
func mergeWorkspaceIntoActiveViewFromSidebarIfPossible(
    sourceWorkspaceName: String,
    pointer: CGPoint,
    position: WindowStackSplitPosition = .right
) {
    runWorkspaceSidebarSession {
        guard mergeWorkspaceIntoActiveViewFromSidebar(
            sourceWorkspaceName: sourceWorkspaceName,
            pointer: pointer,
            position: position
        ) else { return }
        await updateWorkspaceSidebarModel()
    }
}

@MainActor
@discardableResult
func mergeWorkspaceIntoActiveViewFromSidebar(
    sourceWorkspaceName: String,
    pointer: CGPoint,
    position: WindowStackSplitPosition = .right
) -> Bool {
    guard let sourceWorkspace = Workspace.existing(byName: sourceWorkspaceName) else { return false }
    guard WorkspaceSidebarPanel.panel(containing: pointer) == nil else { return false }
    let monitor = pointer.monitorApproximation
    let targetWorkspace = monitor.activeWorkspace
    guard targetWorkspace != sourceWorkspace else { return false }
    return mergeWorkspaceTab(
        sourceWorkspaceName: sourceWorkspaceName,
        targetWorkspaceName: targetWorkspace.name,
        position: position,
    )
}

@MainActor
@discardableResult
func mergeWorkspaceTab(
    sourceWorkspaceName: String,
    targetWorkspaceName: String,
    position: WindowStackSplitPosition
) -> Bool {
    guard sourceWorkspaceName != targetWorkspaceName,
          let sourceWorkspace = Workspace.existing(byName: sourceWorkspaceName),
          let targetWorkspace = Workspace.existing(byName: targetWorkspaceName),
          !sourceWorkspace.isArchived,
          !targetWorkspace.isArchived
    else { return false }
    guard !projectsAreEnabled() || sourceWorkspace.projectId == targetWorkspace.projectId else {
        return false
    }
    if let sourceMonitor = sourceWorkspace.visibleMonitor,
       let targetMonitor = targetWorkspace.visibleMonitor,
       sourceMonitor.rect.topLeftCorner != targetMonitor.rect.topLeftCorner
    {
        return false
    }

    let movedWindows = sourceWorkspace.allLeafWindowsRecursive.map(\.windowId)
    syncClosedWindowsCacheToCurrentWorld()
    suppressPostDragAxObserverEvents(for: movedWindows)

    mergeWorkspaceTilingContent(
        from: sourceWorkspace,
        into: targetWorkspace,
        position: position
    )
    moveWorkspaceFloatingContent(from: sourceWorkspace, to: targetWorkspace)
    moveWorkspaceNativeContent(from: sourceWorkspace, to: targetWorkspace)

    if let sourceMonitor = sourceWorkspace.visibleMonitor, targetWorkspace.visibleMonitor == nil {
        _ = sourceMonitor.setActiveWorkspace(targetWorkspace)
    }
    if focus.workspace == sourceWorkspace {
        _ = setFocus(to: targetWorkspace.toLiveFocus())
    }
    _ = targetWorkspace.focusWorkspace()
    if !projectsAreEnabled(), targetWorkspace.projectId != workspaceProjectDefaultId {
        targetWorkspace.assignProject(workspaceProjectDefaultId)
    }
    removeWorkspaceFromRegistry(sourceWorkspace)
    checkWorkspaceHierarchyInvariants()
    return true
}

@MainActor
private func mergeWorkspaceTilingContent(
    from sourceWorkspace: Workspace,
    into targetWorkspace: Workspace,
    position: WindowStackSplitPosition
) {
    let sourceRoot = sourceWorkspace.rootTilingContainer
    guard !sourceRoot.children.isEmpty else { return }
    let targetRoot = workspaceSiblingInsertionRoot(targetWorkspace, orientation: position.orientation)
    let movedNode = sourceRoot.children.singleOrNil() ?? sourceRoot
    movedNode.bind(
        to: targetRoot,
        adaptiveWeight: WEIGHT_AUTO,
        index: position.isPositive ? INDEX_BIND_LAST : 0
    )
}

@MainActor
private func moveWorkspaceFloatingContent(from sourceWorkspace: Workspace, to targetWorkspace: Workspace) {
    for window in sourceWorkspace.floatingWindows {
        window.bind(to: targetWorkspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
}

@MainActor
private func moveWorkspaceNativeContent(from sourceWorkspace: Workspace, to targetWorkspace: Workspace) {
    if let fullscreenContainer = sourceWorkspace.existingMacOsNativeFullscreenWindowsContainer {
        for window in fullscreenContainer.children.filterIsInstance(of: Window.self) {
            window.bind(to: targetWorkspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
        }
    }
    if let hiddenAppsContainer = sourceWorkspace.existingMacOsNativeHiddenAppsWindowsContainer {
        for window in hiddenAppsContainer.children.filterIsInstance(of: Window.self) {
            window.bind(to: targetWorkspace.macOsNativeHiddenAppsWindowsContainer, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
        }
    }
    for window in workspaceOwnedMinimizedWindows(sourceWorkspace) {
        switch window.layoutReason {
            case .macos(let prevParentKind, _):
                window.layoutReason = .macos(prevParentKind: prevParentKind, prevWorkspaceName: targetWorkspace.name)
            case .standard:
                break
        }
    }
}

@MainActor
func focusWindowFromSidebar(_ windowId: UInt32) {
    WorkspaceSidebarPanel.suppressEdgeTrapForWorkspaceActivation()
    runWorkspaceSidebarSession {
        guard let window = Window.get(byId: windowId),
              let liveFocus = window.toLiveFocusOrNil()
        else {
            if let fallbackWorkspace = workspaceSidebarFallbackWorkspaceName(for: windowId) {
                _ = Workspace.existing(byName: fallbackWorkspace)?.focusWorkspace()
            }
            return
        }
        _ = setFocus(to: liveFocus)
        window.nativeFocus()
    }
}

@MainActor
func workspaceSidebarFallbackWorkspaceName(for windowId: UInt32) -> String? {
    for workspace in TrayMenuModel.shared.workspaceSidebarWorkspaces {
        for item in workspace.items {
            switch item.kind {
                case .window(let window) where window.windowId == windowId:
                    return window.workspaceName
                case .tabGroup(let group) where group.representativeWindowId == windowId:
                    return group.workspaceName
                case .tabGroup(let group):
                    if group.tabs.contains(where: { $0.windowId == windowId }) {
                        return group.workspaceName
                    }
                case .window:
                    continue
            }
        }
    }
    return nil
}

@MainActor
func updateSidebarWindowDrag(_ windowId: UInt32, subject: WindowDragSubject = .window, pointer: CGPoint? = nil) {
    if let pointer {
        MousePointerTracker.shared.note(point: pointer)
        postWorkspaceSidebarDragPointerNotification(workspaceSidebarDragPointerChangedNotification, pointer: pointer)
    }
    guard let window = Window.get(byId: windowId) else {
        clearWorkspaceSidebarDropPreview()
        clearPendingWindowDragIntent()
        WindowDragCursorProxyPanel.shared.hide()
        clearActiveWorkspaceSidebarDrag()
        return
    }
    beginActiveWorkspaceSidebarDrag(windowId: window.windowId, subject: subject)
    let point = MousePointerTracker.shared.currentSample.point
    updateActiveWorkspaceSidebarDragPreview(sourceWindow: window, subject: subject)
    beginWindowMoveWithMouseSessionIfNeeded(
        windowId: window.windowId,
        subject: subject,
        detachOrigin: .window,
        startedInSidebar: true,
        anchorRect: resolvedDraggedWindowAnchorRect(for: window, subject: subject),
        refreshActualRects: true,
    )
    WindowMouseInteractionDriver.shared.startMove(
        windowId: window.windowId,
        subject: subject,
        detachOrigin: .window,
        startedInSidebar: true,
    )
    _ = updatePendingWindowDragIntent(
        sourceWindow: window,
        mouseLocation: point,
        subject: subject,
        detachOrigin: .window,
    )
}

@MainActor
func finishSidebarWindowDrag(pointer: CGPoint? = nil) {
    if let pointer {
        MousePointerTracker.shared.note(point: pointer)
        postWorkspaceSidebarDragPointerNotification(workspaceSidebarDragPointerEndedNotification, pointer: pointer)
    }
    let didCommitSidebarDrop = commitActiveWorkspaceSidebarDragIfPossible()
    clearActiveWorkspaceSidebarDrag()
    if didCommitSidebarDrop {
        clearPendingWindowDragIntent()
        cancelManipulatedWithMouseState()
        scheduleRefreshSession(.resetManipulatedWithMouse, optimisticallyPreLayoutWorkspaces: true)
        return
    }
    Task { @MainActor in
        try? await resetManipulatedWithMouseIfPossible()
    }
    clearWorkspaceSidebarDropPreview()
    WindowDragCursorProxyPanel.shared.hide()
}

@MainActor
func finishWorkspaceSidebarDragAfterGlobalMouseUp() {
    let hasSidebarWindowDragState = currentActiveWorkspaceSidebarDrag() != nil
    let hasCursorProxy = WindowDragCursorProxyPanel.shared.currentContent != nil || WindowDragCursorProxyPanel.shared.isVisible
    guard hasSidebarWindowDragState || hasCursorProxy else {
        postWorkspaceSidebarDragPointerNotification(
            workspaceSidebarDragPointerEndedNotification,
            pointer: MousePointerTracker.shared.currentSample.point
        )
        resetWorkspaceSidebarItemDrag()
        return
    }
    if hasSidebarWindowDragState {
        finishSidebarWindowDrag()
    } else {
        clearWorkspaceSidebarDropPreview()
        WindowDragCursorProxyPanel.shared.hide()
    }
    resetWorkspaceSidebarItemDrag()
}

@MainActor
private func postWorkspaceSidebarDragPointerNotification(_ name: Notification.Name, pointer: CGPoint) {
    NotificationCenter.default.post(
        name: name,
        object: nil,
        userInfo: [workspaceSidebarDragPointerUserInfoKey: NSValue(point: pointer)]
    )
}

@MainActor
private func workspaceSidebarDragTarget(for sourceWindow: Window, subject: WindowDragSubject) -> WorkspaceSidebarDropTargetKind? {
    let point = MousePointerTracker.shared.currentSample.point
    guard WorkspaceSidebarPanel.panel(containing: point) != nil else { return nil }
    guard let target = workspaceSidebarDropTarget(at: point)?.kind else { return nil }
    guard isActionableSidebarDropTarget(sourceWindow: sourceWindow, subject: subject, target: target) else { return nil }
    return target
}

@MainActor
func refreshActiveWorkspaceSidebarDragPreviewIfNeeded() {
    guard let activeDrag = currentActiveWorkspaceSidebarDrag(),
          let sourceWindow = Window.get(byId: activeDrag.windowId)
    else { return }
    updateActiveWorkspaceSidebarDragPreview(sourceWindow: sourceWindow, subject: activeDrag.subject)
}

@MainActor
private func updateActiveWorkspaceSidebarDragPreview(sourceWindow: Window, subject: WindowDragSubject) {
    showWorkspaceSidebarDragCursorPreview(
        sourceWindow: sourceWindow,
        subject: subject,
        point: MousePointerTracker.shared.currentSample.point
    )
    guard let target = workspaceSidebarDragTarget(for: sourceWindow, subject: subject) else {
        clearWorkspaceSidebarDropPreview()
        return
    }
    previewWorkspaceSidebarDrop(sourceWindow.windowId, subject: subject, target: target)
}

@MainActor
func commitActiveWorkspaceSidebarDrag(to target: WorkspaceSidebarDropTargetKind) -> Bool {
    guard let activeDrag = currentActiveWorkspaceSidebarDrag(),
          let sourceWindow = Window.get(byId: activeDrag.windowId),
          isActionableSidebarDropTarget(sourceWindow: sourceWindow, subject: activeDrag.subject, target: target)
    else {
        clearWorkspaceSidebarDropPreview()
        WindowDragCursorProxyPanel.shared.hide()
        return false
    }
    clearWorkspaceSidebarDropPreview()
    WindowDragCursorProxyPanel.shared.hide()
    switch target {
        case .workspace(let workspaceName):
            if activeDrag.subject == .group {
                return applySidebarSource(sourceWindow.windowId, subject: .group, toWorkspace: workspaceName)
            } else {
                return applySidebarSource(sourceWindow.windowId, subject: .window, toWorkspace: workspaceName)
            }
        case .folder(let projectId, let monitorScopeId):
            return applySidebarSourceToNewWorkspace(
                sourceWindow.windowId,
                subject: activeDrag.subject,
                projectId: projectId,
                monitorScopeId: monitorScopeId
            )
        case .newWorkspace(let projectId, let monitorScopeId):
            if activeDrag.subject == .group {
                return applySidebarSourceToNewWorkspace(
                    sourceWindow.windowId,
                    subject: .group,
                    projectId: projectId,
                    monitorScopeId: monitorScopeId
                )
            } else {
                return applySidebarSourceToNewWorkspace(
                    sourceWindow.windowId,
                    subject: .window,
                    projectId: projectId,
                    monitorScopeId: monitorScopeId
                )
            }
        case .monitor:
            return false
    }
}

@MainActor
private func commitActiveWorkspaceSidebarDragIfPossible() -> Bool {
    guard let activeDrag = currentActiveWorkspaceSidebarDrag(),
          let sourceWindow = Window.get(byId: activeDrag.windowId),
          let target = workspaceSidebarDragTarget(for: sourceWindow, subject: activeDrag.subject)
    else {
        clearWorkspaceSidebarDropPreview()
        WindowDragCursorProxyPanel.shared.hide()
        return false
    }
    return commitActiveWorkspaceSidebarDrag(to: target)
}
