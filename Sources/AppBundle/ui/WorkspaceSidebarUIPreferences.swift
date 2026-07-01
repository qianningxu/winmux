import Foundation

private let workspaceSidebarPinnedExpandedPreferenceKey = "workspaceSidebar.pinnedExpanded"
private let workspaceSidebarCollapsedTabGroupIdsPreferenceKey = "workspaceSidebar.collapsedTabGroupIds"

func workspaceSidebarPinnedExpandedPreference() -> Bool {
    UserDefaults.standard.bool(forKey: workspaceSidebarPinnedExpandedPreferenceKey)
}

@MainActor
func setWorkspaceSidebarPinnedExpandedPreference(_ isPinned: Bool) {
    UserDefaults.standard.setValue(isPinned, forKey: workspaceSidebarPinnedExpandedPreferenceKey)
    UserDefaults.standard.synchronize()
    TrayMenuModel.shared.isWorkspaceSidebarPinnedExpanded = isPinned
}

func collapsedWorkspaceSidebarTabGroupIdsPreference() -> Set<String> {
    let ids = UserDefaults.standard.stringArray(forKey: workspaceSidebarCollapsedTabGroupIdsPreferenceKey) ?? []
    return Set(ids)
}

@MainActor
func resetWorkspaceSidebarUIPreferencesForTests() {
    UserDefaults.standard.removeObject(forKey: workspaceSidebarPinnedExpandedPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
    TrayMenuModel.shared.isWorkspaceSidebarPinnedExpanded = false
}

func workspaceSidebarTabGroupIsExpanded(_ projectId: WorkspaceProjectId) -> Bool {
    !collapsedWorkspaceSidebarTabGroupIdsPreference().contains(projectId.rawValue)
}

@MainActor
func setWorkspaceSidebarTabGroupExpanded(_ projectId: WorkspaceProjectId, isExpanded: Bool) {
    var collapsedIds = collapsedWorkspaceSidebarTabGroupIdsPreference()
    if isExpanded {
        collapsedIds.remove(projectId.rawValue)
    } else {
        collapsedIds.insert(projectId.rawValue)
    }
    UserDefaults.standard.setValue(collapsedIds.sorted(), forKey: workspaceSidebarCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
}
