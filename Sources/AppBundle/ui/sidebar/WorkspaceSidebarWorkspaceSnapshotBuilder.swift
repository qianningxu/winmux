@MainActor
func buildWorkspaceSidebarWorkspaceViewModels(
    currentFocus: LiveFocus,
    workspaceLabels: [String: String],
    availableMonitors: [Monitor],
) async -> [WorkspaceSidebarWorkspaceViewModel] {
    var workspaces: [WorkspaceSidebarWorkspaceViewModel] = []
    for workspace in orderedWorkspacesForPresentation() {
        workspaces.append(await makeWorkspaceSidebarWorkspaceViewModel(
            workspace,
            currentFocus: currentFocus,
            workspaceLabels: workspaceLabels,
            availableMonitors: availableMonitors,
        ))
    }
    return workspaces
}

@MainActor
private func makeWorkspaceSidebarWorkspaceViewModel(
    _ workspace: Workspace,
    currentFocus: LiveFocus,
    workspaceLabels: [String: String],
    availableMonitors: [Monitor],
) async -> WorkspaceSidebarWorkspaceViewModel {
    let workspaceMonitor = workspace.workspaceMonitor
    let sidebarLabel = workspaceLabels[workspace.name] ?? ""
    let tabSummary = await makeWorkspaceSidebarTabSummaryViewModel(
        workspace,
        currentFocus: currentFocus,
        sidebarLabel: sidebarLabel,
    )
    return WorkspaceSidebarWorkspaceViewModel(
        name: workspace.name,
        projectId: workspace.projectId,
        displayName: tabSummary.title,
        sidebarLabel: sidebarLabel,
        isGeneratedName: isSidebarDraftWorkspaceName(workspace.name) || workspace.usesAutomaticDisplayName,
        tabSummary: tabSummary,
        monitorScopeId: workspaceSidebarMonitorScopeId(for: workspaceMonitor),
        monitorName: availableMonitors.count > 1 ? workspaceMonitor.name : nil,
        isFocused: currentFocus.workspace == workspace,
        isVisible: workspace.isVisible,
        items: [],
    )
}

@MainActor
private func makeWorkspaceSidebarTabSummaryViewModel(
    _ workspace: Workspace,
    currentFocus: LiveFocus,
    sidebarLabel: String,
) async -> WorkspaceSidebarTabSummaryViewModel {
    let windows = workspace.allLeafWindowsRecursive.filter(\.isBound)
    let representativeWindow =
        currentFocus.windowOrNil?.takeIf { $0.nodeWorkspace == workspace && $0.isBound } ??
        workspace.mostRecentWindowRecursive?.takeIf(\.isBound) ??
        windows.first
    let appName = representativeWindow?.app.name ?? representativeWindow?.app.rawAppBundleId
    let windowTitle: String?
    if let representativeWindow {
        windowTitle = await tabDisplayTitle(for: representativeWindow)
    } else {
        windowTitle = nil
    }
    let automaticTitle = windowTitle ?? appName ?? workspaceDisplayName(workspace.name)
    let manualTitle = sidebarLabel.trimmingCharacters(in: .whitespacesAndNewlines).takeIf { !$0.isEmpty }
    let title = manualTitle ?? automaticTitle
    let subtitle = manualTitle == nil
        ? nil
        : automaticTitle.takeIf { $0 != title && $0 != appName }
    return WorkspaceSidebarTabSummaryViewModel(
        title: title,
        subtitle: subtitle,
        appBundleId: representativeWindow?.app.rawAppBundleId,
        appBundlePath: representativeWindow?.app.bundlePath,
        windowCount: windows.count,
        isEmpty: windows.isEmpty,
    )
}

func visibleWorkspaceNamesForSidebar(
    workspaces: [WorkspaceSidebarWorkspaceViewModel],
    selectedMonitorScopeId: String,
    focusedMonitorScopeId: String,
) -> Set<String> {
    Set(workspaces.filter {
        workspaceSidebarWorkspaceMatchesScope(
            $0,
            selectedScopeId: selectedMonitorScopeId,
            focusedMonitorScopeId: focusedMonitorScopeId,
        )
    }.map(\.name))
}
