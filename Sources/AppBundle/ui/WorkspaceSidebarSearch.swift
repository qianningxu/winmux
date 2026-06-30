import Foundation

func workspaceSidebarFilteredWorkspacesByProject(
    _ workspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]],
    projects: [WorkspaceSidebarProjectViewModel],
    query: String,
) -> [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]] {
    let terms = workspaceSidebarSearchTerms(query)
    guard !terms.isEmpty else { return workspacesByProject }
    let projectNamesById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.displayName) })

    return workspacesByProject.mapValues { workspaces in
        workspaces.compactMap { workspace in
            workspaceSidebarFilteredWorkspace(
                workspace,
                projectName: projectNamesById[workspace.projectId],
                terms: terms,
            )
        }
    }
}

private func workspaceSidebarFilteredWorkspace(
    _ workspace: WorkspaceSidebarWorkspaceViewModel,
    projectName: String?,
    terms: [String],
) -> WorkspaceSidebarWorkspaceViewModel? {
    if workspaceSidebarWorkspaceMatchesSearch(workspace, projectName: projectName, terms: terms) {
        return WorkspaceSidebarWorkspaceViewModel(
            name: workspace.name,
            projectId: workspace.projectId,
            displayName: workspace.displayName,
            sidebarLabel: workspace.sidebarLabel,
            isGeneratedName: workspace.isGeneratedName,
            tabSummary: workspace.tabSummary,
            monitorScopeId: workspace.monitorScopeId,
            monitorName: workspace.monitorName,
            isFocused: workspace.isFocused,
            isVisible: workspace.isVisible,
            items: [],
        )
    }
    return nil
}

private func workspaceSidebarSearchTerms(_ query: String) -> [String] {
    query
        .split(whereSeparator: { $0.isWhitespace })
        .map { String($0).localizedLowercase }
        .filter { !$0.isEmpty }
}

private func workspaceSidebarWorkspaceMatchesSearch(
    _ workspace: WorkspaceSidebarWorkspaceViewModel,
    projectName: String?,
    terms: [String],
) -> Bool {
    workspaceSidebarSearchTextMatches(
        [
            workspace.displayName,
            workspace.sidebarLabel,
            workspace.tabSummary.title,
            workspace.tabSummary.subtitle,
            workspace.tabSummary.appBundleId,
            workspace.tabSummary.appBundlePath,
            workspace.name,
            workspace.monitorName,
            projectName,
        ],
        terms: terms,
    )
}

private func workspaceSidebarSearchTextMatches(_ values: [String?], terms: [String]) -> Bool {
    let searchableText = values
        .compactMap { $0?.localizedLowercase }
        .joined(separator: " ")
    return terms.allSatisfy { searchableText.contains($0) }
}
