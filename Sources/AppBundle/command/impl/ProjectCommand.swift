import Common

struct ProjectCommand: Command {
    let args: ProjectCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let monitor = target.workspace.workspaceMonitor
        let currentProjectId = target.workspace.projectId
        guard let projectId = resolveWorkspaceSidebarFolderTarget(
            args.target.val,
            currentProjectId: currentProjectId,
            wrapAround: args.wrapAround
        ) else {
            return io.err("Can't resolve folder target")
        }
        let folderName = workspaceProjectDisplayName(projectId, fallbackName: projectId == workspaceProjectDefaultId ? "Tabs" : "Folder")
        if projectId == currentProjectId {
            if !args.failIfNoop {
                io.err("Folder '\(folderName)' is already focused. Tip: use --fail-if-noop to exit with non-zero code")
            }
            return !args.failIfNoop
        }
        guard let workspace = switchWorkspaceProject(projectId, on: monitor) else {
            return io.err("Can't switch to folder '\(folderName)'")
        }
        return workspace.focusWorkspace()
    }
}

@MainActor
func resolveWorkspaceSidebarFolderTarget(
    _ target: ProjectTarget,
    currentProjectId: WorkspaceProjectId,
    wrapAround: Bool
) -> WorkspaceProjectId? {
    let projectIds = workspaceSidebarFolderNavigationProjectIds()
    guard !projectIds.isEmpty else { return nil }
    switch target {
        case .index(let index):
            return projectIds.getOrNil(atIndex: index - 1)
        case .relative(let nextPrev):
            let currentIndex = projectIds.firstIndex(of: currentProjectId)
                ?? projectIds.firstIndex(of: workspaceProjectDefaultId)
            guard let currentIndex else { return nil }
            let targetIndex = currentIndex + (nextPrev == .next ? 1 : -1)
            return wrapAround ? projectIds.get(wrappingIndex: targetIndex) : projectIds.getOrNil(atIndex: targetIndex)
    }
}

@MainActor
func workspaceSidebarFolderNavigationProjectIds() -> [WorkspaceProjectId] {
    let folderProjectIds = workspaceProjects()
        .map(\.id)
        .filter { $0 != workspaceProjectDefaultId }
    return folderProjectIds + [workspaceProjectDefaultId]
}
