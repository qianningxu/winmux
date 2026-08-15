import AppKit
import Common

@MainActor
func projectsAreEnabled() -> Bool {
    false
}

@MainActor
func projectFeatureDisabledMessage() -> String {
    "Legacy project commands are disabled. Folders are always available in the sidebar."
}

@MainActor
func workspaceFolders() -> [WorkspaceFolder] {
    materializePersistedWorkspaceProjects()
    if projectsAreEnabled() {
        ensureMinimumWorkspaceForAllProjects()
    } else {
        pruneEmptyWorkspaceTabGroups()
        ensureMinimumWorkspace(for: workspaceProjectDefaultId)
    }
    winMuxWorkspaceState.normalizeDefaultProjectFolderOrder()
    let folders = workspaceFoldersInSidebarOrder()
    return folders.map { folder in
        let displayName: String
        if let configuredName = config.workspaceSidebar.projectLabels[folder.id.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configuredName.isEmpty,
           configuredName != folder.id.rawValue
        {
            displayName = workspaceSidebarFolderDisplayName(configuredName)
        } else if folder.id == workspaceFolderDefaultId {
            displayName = workspaceDefaultFolderDisplayName
        } else {
            // A durable sidebar snapshot may be the only source for a custom
            // folder name after browser windows receive new macOS IDs.
            displayName = workspaceSidebarFolderDisplayName(folder.name)
        }
        return WorkspaceFolder(
            id: folder.id,
            projectId: folder.projectId,
            name: displayName,
            order: folder.order,
            workspaceOrder: folder.workspaceOrder,
            linkedViewportIds: folder.linkedViewportIds,
        )
    }
}

@MainActor
func workspaceFoldersInSidebarOrder() -> [WorkspaceFolder] {
    let folderById = winMuxWorkspaceState.workspaceFoldersById
    let orderedIds = winMuxWorkspaceState.projectsById[workspaceProjectDefaultId]?.folderOrder ?? []
    var seen: Set<WorkspaceFolderId> = []
    var folders = orderedIds.compactMap { folderId -> WorkspaceFolder? in
        guard let folder = folderById[folderId],
              seen.insert(folderId).inserted
        else { return nil }
        return folder
    }
    folders.append(contentsOf: folderById.values
        .filter { seen.insert($0.id).inserted }
        .sorted(by: workspaceFolderOrderPrecedes))
    return folders
}

@MainActor
func workspaceFolderName(_ folderId: WorkspaceFolderId) -> String {
    workspaceProjectName(folderId.backingProjectId)
}

@MainActor
func workspaceFolderDisplayName(_ folderId: WorkspaceFolderId, fallbackName: String) -> String {
    workspaceProjectDisplayName(folderId.backingProjectId, fallbackName: fallbackName)
}

@MainActor
func activeWorkspaceFolderId(for monitor: Monitor) -> WorkspaceFolderId {
    WorkspaceFolderId(activeWorkspaceProjectId(for: monitor))
}

@MainActor
func createWorkspaceFolder() -> WorkspaceFolder {
    materializePersistedWorkspaceProjects()
    let identity = winMuxWorkspaceState.nextGeneratedFolderIdentity()
    let order = winMuxWorkspaceState.nextFolderOrder()
    let folder = WorkspaceFolder(id: identity.id, name: identity.name, order: order)
    winMuxWorkspaceState.registerFolder(folder)
    ensureMinimumWorkspace(for: folder.id.backingProjectId)
    config.workspaceSidebar.projectLabels[folder.id.rawValue] = folder.id.rawValue
    if !isUnitTest {
        try? persistWorkspaceSidebarProjectLabel(projectId: folder.id.rawValue, label: folder.id.rawValue)
    }
    return winMuxWorkspaceState.workspaceFoldersById[folder.id] ?? folder
}

@MainActor
func switchWorkspaceFolder(_ folderId: WorkspaceFolderId, on monitor: Monitor) -> Workspace? {
    if let workspace = sidebarPreferredWorkspace(folderId: folderId, monitor: monitor) {
        return activateWorkspaceOnMonitorPreservingSourceViewport(workspace, targetMonitor: monitor)
            ? workspace
            : nil
    }
    return switchWorkspaceProject(folderId.backingProjectId, on: monitor)
}

@MainActor
func folderWorkspaces(folderId: WorkspaceFolderId) -> [Workspace] {
    projectWorkspaces(projectId: folderId.backingProjectId)
}

@MainActor
private func sidebarPreferredWorkspace(folderId: WorkspaceFolderId, monitor: Monitor) -> Workspace? {
    let candidates = userFacingWorkspaces(orderedWorkspacesForPresentation(), focusedWorkspace: focus.workspace)
        .filter {
            $0.folderId == folderId &&
                isValidAssignment(workspace: $0, screen: monitor.rect.topLeftCorner)
        }
    let monitorLocalCandidates = candidates.filter {
        !$0.isVisible || $0.workspaceMonitor.rect.topLeftCorner == monitor.rect.topLeftCorner
    }
    let preferredWorkspace = monitorLocalCandidates.first(where: workspaceHasSidebarVisibleWindows) ??
        candidates.first(where: workspaceHasSidebarVisibleWindows) ??
        monitorLocalCandidates.first ??
        candidates.first
    let rememberedWorkspace = winMuxWorkspaceState.monitorViewportsById[MonitorViewportId(monitor)]?
        .lastActiveWorkspaceByProject[folderId.backingProjectId]
        .flatMap { rememberedId in candidates.first { $0.id == rememberedId } }
        .flatMap { remembered in
            workspaceHasSidebarVisibleWindows(remembered) ||
                remembered.isConfiguredPersistent ||
                !workspaceOwnedMinimizedWindows(remembered).isEmpty ||
                preferredWorkspace == nil ||
                preferredWorkspace === remembered
                ? remembered
                : nil
        }
    return rememberedWorkspace ?? preferredWorkspace
}

@MainActor
func workspaceProjects() -> [WorkspaceProject] {
    workspaceFolders().map(workspaceProjectView(backingFolder:))
}

@MainActor
func workspaceProjectName(_ projectId: WorkspaceProjectId) -> String {
    workspaceProjects().first { $0.id == projectId }?.name ?? "Folder"
}

@MainActor
func workspaceProjectDisplayName(_ projectId: WorkspaceProjectId, fallbackName: String) -> String {
    workspaceProjects().first { $0.id == projectId }?.name ?? fallbackName
}

@MainActor
func activeWorkspaceProjectId(for monitor: Monitor) -> WorkspaceProjectId {
    materializePersistedWorkspaceProjects()
    return winMuxWorkspaceState.activeProjectId(for: monitor)
}

@MainActor
func createWorkspaceProject() -> WorkspaceProject {
    workspaceProjectView(backingFolder: createWorkspaceFolder())
}

func workspaceProjectOrderPrecedes(_ lhs: WorkspaceProject, _ rhs: WorkspaceProject) -> Bool {
    if lhs.order != rhs.order {
        return lhs.order < rhs.order
    }
    return lhs.id < rhs.id
}

func workspaceFolderOrderPrecedes(_ lhs: WorkspaceFolder, _ rhs: WorkspaceFolder) -> Bool {
    if lhs.order != rhs.order {
        return lhs.order < rhs.order
    }
    return lhs.id < rhs.id
}

private func workspaceProjectView(backingFolder folder: WorkspaceFolder) -> WorkspaceProject {
    WorkspaceProject(
        id: folder.id.backingProjectId,
        name: folder.name,
        order: folder.order,
        workspaceOrder: folder.workspaceOrder,
        linkedViewportIds: folder.linkedViewportIds,
    )
}

@MainActor
func materializePersistedWorkspaceProjects() {
    materializePersistedWorkspaceProjectMetadata()
    if projectsAreEnabled() {
        ensureMinimumWorkspaceForAllProjects()
    } else {
        // Legacy project commands are disabled, but their metadata keys are kept
        // as the on-disk compatibility format for sidebar folders.
        ensureMinimumWorkspace(for: workspaceProjectDefaultId)
    }
}

@MainActor
private func materializePersistedWorkspaceProjectMetadata() {
    var rawProjectIds = Set(config.workspaceSidebar.projectLabels.keys)
    rawProjectIds.formUnion(config.workspaceSidebar.projectColors.keys)
    rawProjectIds.remove(workspaceProjectDefaultId.rawValue)
    for rawProjectId in rawProjectIds.sorted() {
        guard !rawProjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
        let label = config.workspaceSidebar.projectLabels[rawProjectId] ?? rawProjectId
        let folderId = WorkspaceFolderId(rawProjectId)
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, winMuxWorkspaceState.workspaceFoldersById[folderId] == nil else { continue }
        let order = winMuxWorkspaceState.nextFolderOrder()
        winMuxWorkspaceState.registerFolder(WorkspaceFolder(id: folderId, name: name, order: order))
    }
}

@MainActor
func ensureMinimumWorkspaceForAllProjects(monitor: Monitor = mainMonitor) {
    let projectIds = projectsAreEnabled()
        ? winMuxWorkspaceState.workspaceFoldersById.keys.map(\.backingProjectId)
        : [workspaceProjectDefaultId]
    for projectId in projectIds {
        ensureMinimumWorkspace(for: projectId, monitor: monitor)
    }
}

@MainActor
func ensureMinimumWorkspace(for projectId: WorkspaceProjectId, monitor: Monitor = mainMonitor) {
    guard winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(projectId)] != nil else { return }
    guard !Workspace.all.contains(where: { $0.projectId == projectId && !$0.isArchived }) else { return }
    _ = createBlankWorkspace(projectId: projectId, monitor: monitor)
}

@MainActor
func renameWorkspaceForSidebar(workspaceName: String, displayName: String) throws {
    guard Workspace.existing(byName: workspaceName) != nil else {
        throw WorkspaceMutationError.workspaceNotFound(workspaceName)
    }
    let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
        throw WorkspaceMutationError.emptyName
    }
    if trimmedName == workspaceDefaultDisplayName(workspaceName) {
        try resetWorkspaceSidebarName(workspaceName: workspaceName)
        return
    }
    config.workspaceSidebar.workspaceLabels[workspaceName] = trimmedName
    if !isUnitTest {
        try persistWorkspaceSidebarLabel(workspaceName: workspaceName, label: trimmedName)
        persistSidebarStateForRestartIfPossible()
    }
}

@MainActor
@discardableResult
func reorderWorkspaceForSidebar(
    sourceWorkspaceName: String,
    projectId: WorkspaceProjectId,
    placement: WorkspaceReorderPlacement
) -> Bool {
    materializePersistedWorkspaceProjects()
    guard let source = Workspace.existing(byName: sourceWorkspaceName),
          let target = Workspace.existing(byName: placement.targetWorkspaceName),
          !source.isArchived,
          !target.isArchived
    else { return false }

    guard target.folderId == WorkspaceFolderId(projectId)
    else { return false }

    if source.projectId != projectId {
        return moveWorkspaceForSidebarReorder(
            source: source,
            target: target,
            destinationProjectId: projectId,
            placement: placement
        )
    }

    let destination: WorkspaceOrderDestination = switch placement {
        case .before(_): .before(target.id)
        case .after(_): .after(target.id)
    }
    return winMuxWorkspaceState.reorderWorkspace(source.id, inProject: projectId, destination: destination)
}

@MainActor
private func moveWorkspaceForSidebarReorder(
    source: Workspace,
    target: Workspace,
    destinationProjectId: WorkspaceProjectId,
    placement: WorkspaceReorderPlacement
) -> Bool {
    guard source != target,
          target.folderId == WorkspaceFolderId(destinationProjectId),
          winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(destinationProjectId)] != nil
    else { return false }
    source.assignProject(destinationProjectId)
    let folderId = WorkspaceFolderId(destinationProjectId)
    guard var folder = winMuxWorkspaceState.workspaceFoldersById[folderId] else { return false }
    folder.workspaceOrder.removeAll { $0 == source.id }
    guard let targetIndex = folder.workspaceOrder.firstIndex(of: target.id) else { return false }
    let insertionIndex = switch placement {
        case .before(_): targetIndex
        case .after(_): targetIndex + 1
    }
    folder.workspaceOrder.insert(source.id, at: insertionIndex)
    winMuxWorkspaceState.workspaceFoldersById[folderId] = folder
    setWorkspaceSidebarFolderExpanded(destinationProjectId, isExpanded: true)
    checkWorkspaceHierarchyInvariants()
    return true
}

@MainActor
func resetWorkspaceSidebarName(workspaceName: String) throws {
    guard Workspace.existing(byName: workspaceName) != nil else {
        throw WorkspaceMutationError.workspaceNotFound(workspaceName)
    }
    config.workspaceSidebar.workspaceLabels.removeValue(forKey: workspaceName)
    if !isUnitTest {
        try persistWorkspaceSidebarLabel(workspaceName: workspaceName, label: nil)
        persistSidebarStateForRestartIfPossible()
    }
}

@MainActor
func renameWorkspaceProject(_ projectId: WorkspaceProjectId, displayName: String) throws {
    materializePersistedWorkspaceProjects()
    let folderId = WorkspaceFolderId(projectId)
    guard winMuxWorkspaceState.workspaceFoldersById[folderId] != nil else {
        throw WorkspaceMutationError.projectNotFound(projectId.rawValue)
    }
    let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    if var folder = winMuxWorkspaceState.workspaceFoldersById[folderId] {
        folder.name = trimmedName
        winMuxWorkspaceState.workspaceFoldersById[folderId] = folder
    }
    config.workspaceSidebar.projectLabels[projectId.rawValue] = trimmedName
    if !isUnitTest {
        try persistWorkspaceSidebarProjectLabel(projectId: projectId.rawValue, label: trimmedName)
    }
}

@MainActor
@discardableResult
func reorderWorkspaceProjectForSidebar(
    sourceProjectId: WorkspaceProjectId,
    placement: WorkspaceSidebarFolderReorderPlacement
) -> Bool {
    materializePersistedWorkspaceProjects()
    let targetProjectId = placement.targetProjectId
    guard sourceProjectId != workspaceProjectDefaultId,
          targetProjectId != workspaceProjectDefaultId,
          sourceProjectId != targetProjectId,
          winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(sourceProjectId)] != nil,
          winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(targetProjectId)] != nil
    else { return false }

    let sortedProjectIds = workspaceProjects()
        .map(\.id)
        .filter { $0 != workspaceProjectDefaultId }
    guard sortedProjectIds.contains(sourceProjectId),
          sortedProjectIds.contains(targetProjectId)
    else { return false }

    var reorderedProjectIds = sortedProjectIds.filter { $0 != sourceProjectId }
    guard let targetIndex = reorderedProjectIds.firstIndex(of: targetProjectId) else { return false }
    let insertionIndex = switch placement {
        case .before: targetIndex
        case .after: targetIndex + 1
    }
    reorderedProjectIds.insert(sourceProjectId, at: insertionIndex)
    guard reorderedProjectIds != sortedProjectIds else { return false }

    for (offset, projectId) in reorderedProjectIds.enumerated() {
        let folderId = WorkspaceFolderId(projectId)
        guard var folder = winMuxWorkspaceState.workspaceFoldersById[folderId] else { continue }
        folder.order = offset + 1
        winMuxWorkspaceState.workspaceFoldersById[folderId] = folder
    }
    if var project = winMuxWorkspaceState.projectsById[workspaceProjectDefaultId] {
        project.folderOrder = reorderedProjectIds.map(WorkspaceFolderId.init)
        if winMuxWorkspaceState.workspaceFoldersById[workspaceFolderDefaultId] != nil {
            project.folderOrder.append(workspaceFolderDefaultId)
        }
        winMuxWorkspaceState.projectsById[workspaceProjectDefaultId] = project
    }
    checkWorkspaceHierarchyInvariants()
    return true
}

@MainActor
func canDeleteWorkspaceProject(_ projectId: WorkspaceProjectId) -> Bool {
    materializePersistedWorkspaceProjects()
    return projectId != workspaceProjectDefaultId &&
        winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(projectId)] != nil
}

@MainActor
func workspaceProjectFallbackForDeletion(excluding projectId: WorkspaceProjectId) -> WorkspaceProjectId {
    let projects = workspaceProjects()
    guard let deletedIndex = projects.firstIndex(where: { $0.id == projectId }) else {
        return projects.first { $0.id != projectId }?.id ?? workspaceProjectDefaultId
    }
    if let next = projects.getOrNil(atIndex: deletedIndex + 1) {
        return next.id
    }
    if deletedIndex > 0 {
        return projects[deletedIndex - 1].id
    }
    return workspaceProjectDefaultId
}

@MainActor
func deleteWorkspaceForSidebar(workspaceName: String) throws {
    guard let workspace = Workspace.existing(byName: workspaceName) else {
        throw WorkspaceMutationError.workspaceNotFound(workspaceName)
    }
    try deleteWorkspace(workspace)
}

@MainActor
func closeWorkspaceWindowsFromSidebar(workspaceName: String) async throws {
    guard let workspace = Workspace.existing(byName: workspaceName) else {
        throw WorkspaceMutationError.workspaceNotFound(workspaceName)
    }

    let displayName = workspaceDisplayName(workspace.name)
    let remaining = await closeWindowsForSidebarDeletion(
        windowsInWorkspace(workspace),
        terminateAppsWhenAllWindowsIncluded: false
    )
    if !remaining.isEmpty {
        throw WorkspaceMutationError.workspaceCloseBlocked(displayName, remaining.count)
    }

    guard winMuxWorkspaceState.workspaceById[workspace.id] === workspace else { return }
    let newlyRemaining = windowsInWorkspace(workspace)
    guard newlyRemaining.isEmpty else {
        throw WorkspaceMutationError.workspaceCloseBlocked(displayName, newlyRemaining.count)
    }
    try deleteWorkspace(workspace)
}

@MainActor
func deleteWorkspaceProject(_ projectId: WorkspaceProjectId) throws {
    try deleteWorkspaceProjectMovingWindowsToFallback(projectId)
}

@MainActor
func deleteWorkspaceProjectFromSidebar(_ projectId: WorkspaceProjectId) async throws {
    switch config.workspaceSidebar.projectDeletionAction {
        case .closeWindows:
            try await closeWindowsAndDeleteWorkspaceProject(projectId)
        case .moveWindowsToFallback:
            try deleteWorkspaceProjectMovingWindowsToFallback(projectId)
    }
}

@MainActor
private func deleteWorkspaceProjectMovingWindowsToFallback(_ projectId: WorkspaceProjectId) throws {
    materializePersistedWorkspaceProjects()
    let folderId = WorkspaceFolderId(projectId)
    guard let folder = winMuxWorkspaceState.workspaceFoldersById[folderId] else {
        throw WorkspaceMutationError.projectNotFound(projectId.rawValue)
    }
    guard canDeleteWorkspaceProject(projectId) else {
        throw WorkspaceMutationError.projectCannotBeDeleted(folder.name)
    }

    let fallbackId = workspaceProjectFallbackForDeletion(excluding: projectId)
    let viewportsShowingDeletedProject = winMuxWorkspaceState.monitorViewportsById.values.compactMap { viewport -> MonitorViewportId? in
        guard let activeWorkspaceId = viewport.activeWorkspaceId,
              winMuxWorkspaceState.workspaceById[activeWorkspaceId]?.projectId == projectId
        else { return nil }
        return viewport.id
    }
    for viewportId in viewportsShowingDeletedProject {
        _ = switchWorkspaceProject(fallbackId, on: viewportId.topLeftCorner.monitorApproximation)
    }

    for workspace in Workspace.all.filter({ $0.projectId == projectId }) {
        let fallback = workspaceFallbackForDeletion(
            excluding: workspace,
            projectId: fallbackId,
            monitor: workspace.workspaceMonitor,
        )
        moveWorkspaceContents(from: workspace, to: fallback)
        removeWorkspaceFromRegistry(workspace)
    }

    winMuxWorkspaceState.workspaceFoldersById.removeValue(forKey: folderId)
    try clearWorkspaceSidebarProjectMetadata(projectId)
    ensureVisibleActiveProjectWorkspaces()
    checkWorkspaceHierarchyInvariants()
}

@MainActor
private func closeWindowsAndDeleteWorkspaceProject(_ projectId: WorkspaceProjectId) async throws {
    materializePersistedWorkspaceProjects()
    let folderId = WorkspaceFolderId(projectId)
    guard let folder = winMuxWorkspaceState.workspaceFoldersById[folderId] else {
        throw WorkspaceMutationError.projectNotFound(projectId.rawValue)
    }
    guard canDeleteWorkspaceProject(projectId) else {
        throw WorkspaceMutationError.projectCannotBeDeleted(folder.name)
    }

    let windows = windowsInWorkspaceProject(projectId)
    if !windows.isEmpty {
        let remaining = await closeWindowsForSidebarDeletion(
            windows,
            terminateAppsWhenAllWindowsIncluded: true
        )
        if !remaining.isEmpty {
            throw WorkspaceMutationError.projectCloseBlocked(folder.name, remaining.count)
        }
    }

    let fallbackId = workspaceProjectFallbackForDeletion(excluding: projectId)
    let viewportsShowingDeletedProject = winMuxWorkspaceState.monitorViewportsById.values.compactMap { viewport -> MonitorViewportId? in
        guard let activeWorkspaceId = viewport.activeWorkspaceId,
              winMuxWorkspaceState.workspaceById[activeWorkspaceId]?.projectId == projectId
        else { return nil }
        return viewport.id
    }
    for viewportId in viewportsShowingDeletedProject {
        _ = switchWorkspaceProject(fallbackId, on: viewportId.topLeftCorner.monitorApproximation)
    }

    for workspace in Workspace.all.filter({ $0.projectId == projectId }) {
        removeWorkspaceFromRegistry(workspace)
    }

    winMuxWorkspaceState.workspaceFoldersById.removeValue(forKey: folderId)
    try clearWorkspaceSidebarProjectMetadata(projectId)
    ensureVisibleActiveProjectWorkspaces()
    checkWorkspaceHierarchyInvariants()
}

@MainActor
private func clearWorkspaceSidebarProjectMetadata(_ projectId: WorkspaceProjectId) throws {
    let rawProjectId = projectId.rawValue
    let hadLabel = config.workspaceSidebar.projectLabels.removeValue(forKey: rawProjectId) != nil
    let hadColor = config.workspaceSidebar.projectColors.removeValue(forKey: rawProjectId) != nil
    clearWorkspaceSidebarFolderExpansionPreference(projectId)
    guard !isUnitTest else { return }
    if hadLabel {
        try persistWorkspaceSidebarProjectLabel(projectId: rawProjectId, label: nil)
    }
    if hadColor {
        try persistWorkspaceSidebarProjectColor(projectId: rawProjectId, colorHex: nil)
    }
}

@MainActor
private func clearOrphanedWorkspaceTabGroupMetadata() {
    var metadataProjectIds: Set<WorkspaceProjectId> = []
    for rawProjectId in config.workspaceSidebar.projectLabels.keys {
        metadataProjectIds.insert(WorkspaceProjectId(rawProjectId))
    }
    for rawProjectId in config.workspaceSidebar.projectColors.keys {
        metadataProjectIds.insert(WorkspaceProjectId(rawProjectId))
    }
    for projectId in metadataProjectIds
    where projectId != workspaceProjectDefaultId &&
        winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(projectId)] == nil
    {
        try? clearWorkspaceSidebarProjectMetadata(projectId)
    }
}

@MainActor
func pruneEmptyWorkspaceTabGroups() {
    guard !projectsAreEnabled() else { return }
    winMuxWorkspaceState.pruneProjectWorkspaceIndexes()
    let emptyProjectIds = winMuxWorkspaceState.workspaceFoldersById.keys
        .map(\.backingProjectId)
        .filter { $0 != workspaceProjectDefaultId }
        .filter { !workspaceSidebarProjectHasMetadata($0) }
        .filter { !workspaceTabGroupProjectHasContent($0) }

    for projectId in emptyProjectIds {
        for workspace in Workspace.all where workspace.projectId == projectId {
            if workspace.isVisible {
                let fallback = workspaceFallbackForDeletion(
                    excluding: workspace,
                    projectId: workspaceProjectDefaultId,
                    monitor: workspace.workspaceMonitor,
                )
                _ = workspace.workspaceMonitor.setActiveWorkspace(fallback)
                if focus.workspace == workspace {
                    _ = setFocus(to: fallback.toLiveFocus())
                }
            }
            removeWorkspaceFromRegistry(workspace)
        }
        winMuxWorkspaceState.workspaceFoldersById.removeValue(forKey: WorkspaceFolderId(projectId))
        try? clearWorkspaceSidebarProjectMetadata(projectId)
    }
}

@MainActor
private func workspaceSidebarProjectHasMetadata(_ projectId: WorkspaceProjectId) -> Bool {
    let rawProjectId = projectId.rawValue
    return config.workspaceSidebar.projectLabels[rawProjectId] != nil ||
        config.workspaceSidebar.projectColors[rawProjectId] != nil
}

@MainActor
private func workspaceTabGroupProjectHasContent(_ projectId: WorkspaceProjectId) -> Bool {
    projectWorkspaces(projectId: projectId).contains {
        !$0.isArchived && (workspaceHasLifecycleWindows($0) || $0.isConfiguredPersistent)
    }
}

@MainActor
func windowsInWorkspaceProject(_ projectId: WorkspaceProjectId) -> [Window] {
    var seen: Set<UInt32> = []
    var result: [Window] = []
    for workspace in Workspace.all where workspace.projectId == projectId {
        for window in workspace.allLeafWindowsRecursive + workspaceOwnedMinimizedWindows(workspace)
        where seen.insert(window.windowId).inserted
        {
            result.append(window)
        }
    }
    return result
}

@MainActor
func windowsInWorkspace(_ workspace: Workspace) -> [Window] {
    var seen: Set<UInt32> = []
    return (workspace.allLeafWindowsRecursive + workspaceOwnedMinimizedWindows(workspace)).filter {
        seen.insert($0.windowId).inserted
    }
}

@MainActor
private func closeWindowsForSidebarDeletion(
    _ windows: [Window],
    terminateAppsWhenAllWindowsIncluded: Bool
) async -> [Window] {
    var remaining: [Window] = []
    let macWindows = windows.compactMap { $0 as? MacWindow }
    let windowsByPid = Dictionary(grouping: macWindows, by: { $0.macApp.pid })
    var handledWindowIds: Set<UInt32> = []

    if terminateAppsWhenAllWindowsIncluded {
        for (_, appWindows) in windowsByPid {
            guard let app = appWindows.first?.macApp else { continue }
            let axWindowCount = (try? await app.getAxWindowsCount()) ?? MacWindow.allWindows.count { $0.macApp === app }
            if axWindowCount == appWindows.count, app.nsApp.terminate() {
                let didTerminate = await waitForAppTermination(app)
                if didTerminate {
                    for window in appWindows {
                        window.garbageCollect(skipClosedWindowsCache: true)
                        handledWindowIds.insert(window.windowId)
                    }
                }
            }
        }
    }

    for window in windows where !handledWindowIds.contains(window.windowId) {
        if let macWindow = window as? MacWindow {
            if await macWindow.requestCloseAndWait() {
                handledWindowIds.insert(window.windowId)
            } else {
                remaining.append(window)
            }
        } else {
            window.closeAxWindow()
            if window.parent == nil {
                handledWindowIds.insert(window.windowId)
            } else {
                remaining.append(window)
            }
        }
    }
    return remaining
}

@MainActor
private func waitForAppTermination(_ app: MacApp, timeout: TimeInterval = 2.0) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if app.nsApp.isTerminated {
            return true
        }
        if (try? await app.getAxWindowsCount()) == 0 {
            return true
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    return false
}
