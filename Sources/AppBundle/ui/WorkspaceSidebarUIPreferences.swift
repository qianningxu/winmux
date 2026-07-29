import AppKit
import Common
import Foundation

private let workspaceSidebarPinnedExpandedPreferenceKey = "workspaceSidebar.pinnedExpanded"
private let workspaceSidebarCollapsedFolderIdsPreferenceKey = "workspaceSidebar.collapsedFolderIds"
private let workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey = "workspaceSidebar.collapsedTabGroupIds"
private let workspaceSidebarAppearancePreferenceKey = "workspaceSidebar.appearance"
let workspaceSidebarShowsNotePadPreferenceKey = "workspaceSidebar.showsNotePad"

func workspaceSidebarAppearancePreference(rawValue: String) -> AppearanceTheme? {
    switch rawValue {
        case "light": .light
        case "dark": .dark
        default: nil
    }
}

@MainActor
func restoreWorkspaceSidebarAppearancePreference() {
    guard let rawValue = UserDefaults.standard.string(forKey: workspaceSidebarAppearancePreferenceKey),
          let theme = workspaceSidebarAppearancePreference(rawValue: rawValue)
    else { return }
    applyWorkspaceSidebarAppearance(theme, persist: false)
}

@MainActor
func toggleWorkspaceSidebarAppearance() {
    let theme: AppearanceTheme = AppearanceTheme.current == .dark ? .light : .dark
    applyWorkspaceSidebarAppearance(theme, persist: true)
}

@MainActor
private func applyWorkspaceSidebarAppearance(_ theme: AppearanceTheme, persist: Bool) {
    NSApplication.shared.appearance = NSAppearance(named: theme == .dark ? .darkAqua : .aqua)
    guard persist else { return }
    UserDefaults.standard.setValue(theme == .dark ? "dark" : "light", forKey: workspaceSidebarAppearancePreferenceKey)
    UserDefaults.standard.synchronize()
}

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
    UserDefaults.standard.removeObject(forKey: workspaceSidebarAppearancePreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarShowsNotePadPreferenceKey)
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
    // Keep the restart snapshot in lockstep with the visible folded state.
    // Relying only on termination left a stale snapshot behind when macOS
    // terminated/relaunched the app before its async shutdown hook completed.
    if !isUnitTest {
        persistFrozenWorldForRestartIfPossible()
    }
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
