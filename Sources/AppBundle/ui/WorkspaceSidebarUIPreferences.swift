import Foundation

private let workspaceSidebarPinnedExpandedPreferenceKey = "workspaceSidebar.pinnedExpanded"
private let workspaceSidebarCollapsedFolderIdsPreferenceKey = "workspaceSidebar.collapsedFolderIds"
private let workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey = "workspaceSidebar.collapsedTabGroupIds"

func workspaceSidebarPinnedExpandedPreference() -> Bool {
    UserDefaults.standard.bool(forKey: workspaceSidebarPinnedExpandedPreferenceKey)
}

@MainActor
func setWorkspaceSidebarPinnedExpandedPreference(_ isPinned: Bool) {
    UserDefaults.standard.setValue(isPinned, forKey: workspaceSidebarPinnedExpandedPreferenceKey)
    UserDefaults.standard.synchronize()
    TrayMenuModel.shared.isWorkspaceSidebarPinnedExpanded = isPinned
}

func collapsedWorkspaceSidebarFolderIdsPreference() -> Set<String> {
    let ids = UserDefaults.standard.stringArray(forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
        ?? UserDefaults.standard.stringArray(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
        ?? []
    return Set(ids)
}

@MainActor
func resetWorkspaceSidebarUIPreferencesForTests() {
    UserDefaults.standard.removeObject(forKey: workspaceSidebarPinnedExpandedPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
    TrayMenuModel.shared.isWorkspaceSidebarPinnedExpanded = false
}

func workspaceSidebarFolderIsExpanded(_ projectId: WorkspaceProjectId) -> Bool {
    !collapsedWorkspaceSidebarFolderIdsPreference().contains(projectId.rawValue)
}

@MainActor
func setWorkspaceSidebarFolderExpanded(_ projectId: WorkspaceProjectId, isExpanded: Bool) {
    var collapsedIds = collapsedWorkspaceSidebarFolderIdsPreference()
    if isExpanded {
        collapsedIds.remove(projectId.rawValue)
    } else {
        collapsedIds.insert(projectId.rawValue)
    }
    UserDefaults.standard.setValue(collapsedIds.sorted(), forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
}

@MainActor
func restoreWorkspaceSidebarCollapsedFolderIds(_ projectIds: [WorkspaceProjectId]) {
    UserDefaults.standard.setValue(projectIds.map(\.rawValue).sorted(), forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
}

@MainActor
func clearWorkspaceSidebarFolderExpansionPreference(_ projectId: WorkspaceProjectId) {
    var collapsedIds = collapsedWorkspaceSidebarFolderIdsPreference()
    guard collapsedIds.remove(projectId.rawValue) != nil else { return }
    UserDefaults.standard.setValue(collapsedIds.sorted(), forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
}
