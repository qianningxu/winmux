import AppKit
import Common

@MainActor
func migrateWorkspaceTabGroupsToWorkspaceTabs() {
    var didMigrate = false
    for workspace in orderedWorkspacesForPresentation() {
        didMigrate = migrateTabGroups(in: workspace) || didMigrate
    }
    guard didMigrate else { return }
    winMuxWorkspaceState.pruneProjectWorkspaceIndexes()
    pruneEmptyWorkspaces()
    ensureVisibleActiveProjectWorkspaces()
    checkWorkspaceHierarchyInvariants(requireActiveMonitorViewports: true)
}

@MainActor
@discardableResult
private func migrateTabGroups(in workspace: Workspace) -> Bool {
    migrateTabGroups(in: workspace.rootTilingContainer, sourceWorkspace: workspace)
}

@MainActor
@discardableResult
private func migrateTabGroups(in container: TilingContainer, sourceWorkspace: Workspace) -> Bool {
    var didMigrate = false
    for child in container.children.compactMap({ $0 as? TilingContainer }) {
        didMigrate = migrateTabGroups(in: child, sourceWorkspace: sourceWorkspace) || didMigrate
    }
    guard container.layout == .tabGroup, container.children.count > 1 else { return didMigrate }
    splitTabGroupIntoWorkspaceTabs(container, sourceWorkspace: sourceWorkspace)
    return true
}

@MainActor
private func splitTabGroupIntoWorkspaceTabs(_ tabGroup: TilingContainer, sourceWorkspace: Workspace) {
    let tabChildren = tabGroup.children
    guard tabChildren.count > 1 else {
        tabGroup.layout = .tiles
        return
    }

    let activeChild = tabGroup.mostRecentChild ?? tabChildren.first.orDie()
    let insertionProjectId = workspaceProjectDefaultId
    let targetMonitor = sourceWorkspace.workspaceMonitor
    let tabGroupParent = tabGroup.parent as? TilingContainer
    let tabGroupIndex = tabGroup.ownIndex ?? INDEX_BIND_LAST

    for child in tabChildren where child !== activeChild {
        let workspace = createMigratedWorkspaceTab(
            sourceWorkspace: sourceWorkspace,
            projectId: insertionProjectId,
            monitor: targetMonitor,
        )
        child.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }

    if tabGroup.isRootContainer {
        tabGroup.layout = .tiles
    } else {
        activeChild.bind(to: tabGroup.parent.orDie(), adaptiveWeight: WEIGHT_AUTO, index: tabGroup.ownIndex ?? INDEX_BIND_LAST)
        if tabGroup.children.isEmpty {
            _ = tabGroup.bind(to: NilTreeNode.instance, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
        } else {
            tabGroup.layout = .tiles
        }
        normalizeSingleChildContainerAroundMigratedTab(
            parent: tabGroupParent,
            previousIndex: tabGroupIndex,
        )
    }
}

@MainActor
private func createMigratedWorkspaceTab(
    sourceWorkspace: Workspace,
    projectId: WorkspaceProjectId,
    monitor: Monitor,
) -> Workspace {
    let workspace = Workspace.get(byName: nextAutomaticWorkspaceName(projectId: projectId, monitor: monitor))
    workspace.markAsAutomaticallyNamed()
    workspace.assignProject(projectId)
    workspace.seedMonitorIfNeeded(monitor)
    if let sourceLabel = config.workspaceSidebar.workspaceLabels[sourceWorkspace.name],
       !sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       config.workspaceSidebar.workspaceLabels[workspace.name] == nil
    {
        config.workspaceSidebar.workspaceLabels[workspace.name] = sourceLabel
    }
    return workspace
}

@MainActor
private func normalizeSingleChildContainerAroundMigratedTab(
    parent: TilingContainer?,
    previousIndex: Int,
) {
    guard let parent,
          parent.children.count == 1,
          let onlyChild = parent.children.first,
          let grandParent = parent.parent
    else { return }
    onlyChild.bind(to: grandParent, adaptiveWeight: parent.getWeight(parent.orientation), index: previousIndex)
    _ = parent.bind(to: NilTreeNode.instance, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
}
