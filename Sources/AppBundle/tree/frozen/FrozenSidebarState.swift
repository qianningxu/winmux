import Foundation

struct FrozenSidebarState: Codable, Sendable {
    let projects: [FrozenSidebarProject]
    let collapsedFolderIds: [WorkspaceProjectId]
    let workspaceLabels: [String: String]
    let projectLabels: [String: String]

    @MainActor
    init(restorableWorkspaces: [Workspace]) {
        let restorableWorkspaceIds = Set(restorableWorkspaces.map(\.id))
        let restorableWorkspaceNames = Set(restorableWorkspaces.map(\.name))
        winMuxWorkspaceState.normalizeDefaultProjectFolderOrder()
        let folders = workspaceFoldersInSidebarOrder()
        // Folder identity/order is UI state in its own right. Do not discard a
        // folder merely because its tabs currently have no restorable windows;
        // doing so made user-created folders vanish after a restart.
        projects = folders.map { folder in
                FrozenSidebarProject(
                    folder: folder,
                    restorableWorkspaces: restorableWorkspaces,
                    restorableWorkspaceIds: restorableWorkspaceIds,
                )
        }
        let folderProjectIds = folders.map { $0.id.backingProjectId }
        let storedCollapsedIds = collapsedWorkspaceSidebarFolderIdsPreference()
        let expandedProjectId = workspaceSidebarSingleExpandedFolderId(
            projectIds: folderProjectIds,
            collapsedIds: storedCollapsedIds,
            preferredProjectId: focus.workspace.projectId
        )
        collapsedFolderIds = workspaceSidebarNormalizedCollapsedFolderIds(
            projectIds: folderProjectIds,
            collapsedIds: storedCollapsedIds,
            expandedProjectId: expandedProjectId
        )
            .map { WorkspaceProjectId($0) }
            .sorted()
        workspaceLabels = Dictionary(uniqueKeysWithValues: config.workspaceSidebar.workspaceLabels.filter {
            restorableWorkspaceNames.contains($0.key)
        })
        let folderProjectRawIds = Set(folders.map { $0.id.rawValue })
        projectLabels = Dictionary(uniqueKeysWithValues: config.workspaceSidebar.projectLabels.filter {
            folderProjectRawIds.contains($0.key)
        })
    }

    private enum CodingKeys: String, CodingKey {
        case projects
        case collapsedFolderIds
        case workspaceLabels
        case projectLabels
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decode([FrozenSidebarProject].self, forKey: .projects)
        collapsedFolderIds = try container.decode([WorkspaceProjectId].self, forKey: .collapsedFolderIds)
        workspaceLabels = try container.decodeIfPresent([String: String].self, forKey: .workspaceLabels) ?? [:]
        projectLabels = try container.decodeIfPresent([String: String].self, forKey: .projectLabels) ?? [:]
    }
}

struct FrozenSidebarProject: Codable, Sendable {
    let id: WorkspaceProjectId
    let name: String
    let order: Int
    let workspaceNames: [String]
    let linkedViewportIds: Set<MonitorViewportId>

    @MainActor
    init(
        folder: WorkspaceFolder,
        restorableWorkspaces: [Workspace],
        restorableWorkspaceIds: Set<WorkspaceId>
    ) {
        id = folder.id.backingProjectId
        name = folder.name
        order = folder.order
        linkedViewportIds = folder.linkedViewportIds

        var seen: Set<WorkspaceId> = []
        var names = folder.workspaceOrder.compactMap { workspaceId -> String? in
            guard restorableWorkspaceIds.contains(workspaceId),
                  seen.insert(workspaceId).inserted
            else { return nil }
            return winMuxWorkspaceState.workspaceById[workspaceId]?.name
        }
        names.append(contentsOf: restorableWorkspaces.compactMap { workspace in
            guard workspace.folderId == folder.id,
                  seen.insert(workspace.id).inserted
            else { return nil }
            return workspace.name
        })
        workspaceNames = names
    }
}

@MainActor
func restoreFrozenSidebarState(
    _ sidebar: FrozenSidebarState?,
    restoredWorkspaceNames: Set<String>,
    materializeMissingWorkspaces: Bool = false
) {
    guard let sidebar else { return }
    let effectiveRestoredWorkspaceNames = materializeMissingWorkspaces
        ? restoredWorkspaceNames.union(sidebar.projects.flatMap(\.workspaceNames))
        : restoredWorkspaceNames

    for frozenProject in sidebar.projects {
        let restoredWorkspaces = frozenProject.workspaceNames.compactMap { workspaceName -> Workspace? in
            if let workspace = Workspace.existing(byName: workspaceName),
               effectiveRestoredWorkspaceNames.contains(workspaceName)
            {
                return workspace
            }
            return materializeMissingWorkspaces ? Workspace.get(byName: workspaceName) : nil
        }
        let folderId = WorkspaceFolderId(frozenProject.id)
        for workspace in restoredWorkspaces where workspace.folderId != folderId {
            workspace.assignFolder(folderId)
        }

        winMuxWorkspaceState.registerFolder(WorkspaceFolder(
            id: folderId,
            name: frozenProject.name,
            order: frozenProject.order,
            workspaceOrder: restoredWorkspaces.map(\.id),
            linkedViewportIds: frozenProject.linkedViewportIds,
        ))
    }

    restoreFrozenSidebarLabels(sidebar, restoredWorkspaceNames: effectiveRestoredWorkspaceNames)
    restoreWorkspaceSidebarCollapsedFolderIds(sidebar.collapsedFolderIds)
    winMuxWorkspaceState.pruneProjectWorkspaceIndexes()
}

@MainActor
private func restoreFrozenSidebarLabels(_ sidebar: FrozenSidebarState, restoredWorkspaceNames: Set<String>) {
    for (workspaceName, label) in sidebar.workspaceLabels where restoredWorkspaceNames.contains(workspaceName) {
        let currentLabel = config.workspaceSidebar.workspaceLabels[workspaceName]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if currentLabel?.isEmpty ?? true {
            config.workspaceSidebar.workspaceLabels[workspaceName] = label
        }
    }
    for (rawProjectId, label) in sidebar.projectLabels {
        let folderId = WorkspaceFolderId(rawProjectId)
        guard winMuxWorkspaceState.workspaceFoldersById[folderId] != nil else { continue }
        let currentLabel = config.workspaceSidebar.projectLabels[rawProjectId]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if currentLabel?.isEmpty ?? true {
            config.workspaceSidebar.projectLabels[rawProjectId] = label
        }
    }
}
