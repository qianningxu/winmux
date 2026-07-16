import Common

struct ProjectCommand: Command {
    let args: ProjectCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let monitor = target.workspace.workspaceMonitor
        let currentFolderId = WorkspaceFolderId(target.workspace.projectId)
        guard let folderId = resolveWorkspaceSidebarFolderTarget(
            args.target.val,
            currentFolderId: currentFolderId,
            wrapAround: args.wrapAround,
            monitor: monitor
        ) else {
            return io.err("Can't resolve folder target")
        }
        let folderName = workspaceFolderDisplayName(folderId, fallbackName: folderId == workspaceFolderDefaultId ? workspaceDefaultFolderDisplayName : "Folder")
        if folderId == currentFolderId {
            if !args.failIfNoop {
                io.err("Folder '\(folderName)' is already focused. Tip: use --fail-if-noop to exit with non-zero code")
            }
            return !args.failIfNoop
        }
        guard let workspace = switchWorkspaceFolder(folderId, on: monitor) else {
            return io.err("Can't switch to folder '\(folderName)'")
        }
        return workspace.focusWorkspace()
    }
}

@MainActor
func resolveWorkspaceSidebarFolderTarget(
    _ target: ProjectTarget,
    currentFolderId: WorkspaceFolderId,
    wrapAround: Bool,
    monitor: Monitor? = nil
) -> WorkspaceFolderId? {
    let folderIds = workspaceSidebarFolderNavigationFolderIds(monitor: monitor)
    guard !folderIds.isEmpty else { return nil }
    switch target {
        case .defaultFolder:
            return workspaceFolderDefaultId
        case .index(let index):
            return folderIds.getOrNil(atIndex: index - 1)
        case .relative(let nextPrev):
            let currentIndex = folderIds.firstIndex(of: currentFolderId)
                ?? folderIds.firstIndex(of: workspaceFolderDefaultId)
            guard let currentIndex else { return nil }
            let targetIndex = currentIndex + (nextPrev == .next ? 1 : -1)
            return wrapAround ? folderIds.get(wrappingIndex: targetIndex) : folderIds.getOrNil(atIndex: targetIndex)
    }
}

@MainActor
func workspaceSidebarFolderNavigationProjectIds(monitor: Monitor? = nil) -> [WorkspaceProjectId] {
    workspaceSidebarFolderNavigationFolderIds(monitor: monitor).map(\.backingProjectId)
}

@MainActor
func workspaceSidebarFolderNavigationFolderIds(monitor: Monitor? = nil) -> [WorkspaceFolderId] {
    workspaceSidebarFolderNavigationSections(monitor: monitor).map { WorkspaceFolderId($0.id) }
}

@MainActor
func workspaceSidebarFolderNavigationSections(monitor: Monitor? = nil) -> [WorkspaceSidebarFolderSection] {
    workspaceSidebarFolderSections(
        projectId: workspaceFolderDefaultId.backingProjectId,
        workspaces: workspaceSidebarFolderNavigationWorkspaceViewModels(monitor: monitor),
        projects: workspaceSidebarFolderNavigationProjectViewModels(),
    )
}

@MainActor
private func workspaceSidebarNavigationWorkspaces(monitor _: Monitor?) -> [Workspace] {
    userFacingWorkspaces(orderedWorkspacesForPresentation(), focusedWorkspace: focus.workspace)
}

@MainActor
private func workspaceSidebarFolderNavigationProjectViewModels() -> [WorkspaceSidebarProjectViewModel] {
    workspaceFolders().map {
        WorkspaceSidebarProjectViewModel(
            id: $0.id.backingProjectId,
            displayName: $0.name,
            colorHex: config.workspaceSidebar.projectColors[$0.id.rawValue].flatMap(normalizedWorkspaceSidebarColorHex)
        )
    }
}

@MainActor
private func workspaceSidebarFolderNavigationWorkspaceViewModels(
    monitor: Monitor?
) -> [WorkspaceSidebarWorkspaceViewModel] {
    workspaceSidebarNavigationWorkspaces(monitor: monitor).map { workspace in
        let hasVisibleWindows = workspaceHasSidebarVisibleWindows(workspace)
        return WorkspaceSidebarWorkspaceViewModel(
            name: workspace.name,
            projectId: workspace.projectId,
            displayName: workspaceDisplayName(workspace.name),
            sidebarLabel: config.workspaceSidebar.workspaceLabels[workspace.name] ?? "",
            isGeneratedName: workspace.usesAutomaticDisplayName,
            tabSummary: WorkspaceSidebarTabSummaryViewModel(
                title: workspaceDisplayName(workspace.name),
                subtitle: nil,
                appBundleId: nil,
                appBundlePath: nil,
                windowCount: hasVisibleWindows ? max(workspace.allLeafWindowsRecursive.count, 1) : 0,
                isEmpty: !hasVisibleWindows
            ),
            monitorScopeId: workspaceSidebarMonitorScopeId(for: workspace.workspaceMonitor),
            monitorName: nil,
            isFocused: focus.workspace == workspace,
            isVisible: workspace.isVisible,
            items: []
        )
    }
}
