import AppKit
import Common
import Foundation

private let workspaceSidebarPinnedExpandedPreferenceKey = "workspaceSidebar.pinnedExpanded"
private let workspaceSidebarCollapsedFolderIdsPreferenceKey = "workspaceSidebar.collapsedFolderIds"
private let workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey = "workspaceSidebar.collapsedTabGroupIds"
private let workspaceSidebarAppearancePreferenceKey = "workspaceSidebar.appearance"
let workspaceSidebarShowsNotePadPreferenceKey = "workspaceSidebar.showsNotePad"
let workspaceSidebarShowsTasksPreferenceKey = "workspaceSidebar.showsTasks"

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

func workspaceSidebarSingleExpandedFolderId(
    projectIds: [WorkspaceProjectId],
    collapsedIds: Set<String>,
    preferredProjectId: WorkspaceProjectId? = nil
) -> WorkspaceProjectId? {
    let expandedProjectIds = projectIds.filter { !collapsedIds.contains($0.rawValue) }
    if let preferredProjectId, expandedProjectIds.contains(preferredProjectId) {
        return preferredProjectId
    }
    return expandedProjectIds.first
}

func workspaceSidebarNormalizedCollapsedFolderIds(
    projectIds: [WorkspaceProjectId],
    collapsedIds: Set<String>,
    expandedProjectId: WorkspaceProjectId?
) -> Set<String> {
    var normalizedIds = collapsedIds
    normalizedIds.formUnion(projectIds.map(\.rawValue))
    if let expandedProjectId {
        normalizedIds.remove(expandedProjectId.rawValue)
    }
    return normalizedIds
}

@MainActor
func resetWorkspaceSidebarUIPreferencesForTests() {
    UserDefaults.standard.removeObject(forKey: workspaceSidebarPinnedExpandedPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarAppearancePreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarShowsNotePadPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarShowsTasksPreferenceKey)
    UserDefaults.standard.synchronize()
    TrayMenuModel.shared.isWorkspaceSidebarPinnedExpanded = false
}

@MainActor
func workspaceSidebarFolderIsExpanded(_ projectId: WorkspaceProjectId) -> Bool {
    let projectIds = orderedWorkspaceSidebarFolderProjectIds(including: projectId)
    let expandedProjectId = workspaceSidebarSingleExpandedFolderId(
        projectIds: projectIds,
        collapsedIds: collapsedWorkspaceSidebarFolderIdsPreference(),
        preferredProjectId: focus.workspace.projectId
    )
    return expandedProjectId == projectId
}

@MainActor
func setWorkspaceSidebarFolderExpanded(_ projectId: WorkspaceProjectId, isExpanded: Bool) {
    let projectIds = orderedWorkspaceSidebarFolderProjectIds(including: projectId)
    let storedCollapsedIds = collapsedWorkspaceSidebarFolderIdsPreference()
    let currentExpandedProjectId = workspaceSidebarSingleExpandedFolderId(
        projectIds: projectIds,
        collapsedIds: storedCollapsedIds,
        preferredProjectId: focus.workspace.projectId
    )
    var collapsedIds = workspaceSidebarNormalizedCollapsedFolderIds(
        projectIds: projectIds,
        collapsedIds: storedCollapsedIds,
        expandedProjectId: currentExpandedProjectId
    )
    if isExpanded {
        collapsedIds.formUnion(projectIds.map(\.rawValue))
        collapsedIds.remove(projectId.rawValue)
    } else {
        collapsedIds.insert(projectId.rawValue)
    }
    persistWorkspaceSidebarCollapsedFolderIds(collapsedIds, updatesRestartSnapshot: true)
}

@MainActor
func restoreWorkspaceSidebarCollapsedFolderIds(_ projectIds: [WorkspaceProjectId]) {
    let folderProjectIds = orderedWorkspaceSidebarFolderProjectIds()
    let restoredCollapsedIds = Set(projectIds.map(\.rawValue))
    let expandedProjectId = workspaceSidebarSingleExpandedFolderId(
        projectIds: folderProjectIds,
        collapsedIds: restoredCollapsedIds,
        preferredProjectId: focus.workspace.projectId
    )
    let normalizedIds = workspaceSidebarNormalizedCollapsedFolderIds(
        projectIds: folderProjectIds,
        collapsedIds: restoredCollapsedIds,
        expandedProjectId: expandedProjectId
    )
    persistWorkspaceSidebarCollapsedFolderIds(normalizedIds, updatesRestartSnapshot: false)
}

@MainActor
@discardableResult
func normalizeWorkspaceSidebarFolderExpansionPreference(
    preferredProjectId: WorkspaceProjectId? = nil
) -> Bool {
    let projectIds = orderedWorkspaceSidebarFolderProjectIds()
    let collapsedIds = collapsedWorkspaceSidebarFolderIdsPreference()
    let expandedProjectId = workspaceSidebarSingleExpandedFolderId(
        projectIds: projectIds,
        collapsedIds: collapsedIds,
        preferredProjectId: preferredProjectId
    )
    let normalizedIds = workspaceSidebarNormalizedCollapsedFolderIds(
        projectIds: projectIds,
        collapsedIds: collapsedIds,
        expandedProjectId: expandedProjectId
    )
    guard normalizedIds != collapsedIds else { return false }
    persistWorkspaceSidebarCollapsedFolderIds(normalizedIds, updatesRestartSnapshot: true)
    return true
}

@MainActor
func clearWorkspaceSidebarFolderExpansionPreference(_ projectId: WorkspaceProjectId) {
    var collapsedIds = collapsedWorkspaceSidebarFolderIdsPreference()
    guard collapsedIds.remove(projectId.rawValue) != nil else { return }
    UserDefaults.standard.setValue(collapsedIds.sorted(), forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
}

@MainActor
private func orderedWorkspaceSidebarFolderProjectIds(
    including projectId: WorkspaceProjectId? = nil
) -> [WorkspaceProjectId] {
    var projectIds = workspaceFoldersInSidebarOrder().map { $0.id.backingProjectId }
    if let projectId, !projectIds.contains(projectId) {
        projectIds.append(projectId)
    }
    return projectIds
}

@MainActor
private func persistWorkspaceSidebarCollapsedFolderIds(
    _ collapsedIds: Set<String>,
    updatesRestartSnapshot: Bool
) {
    UserDefaults.standard.setValue(collapsedIds.sorted(), forKey: workspaceSidebarCollapsedFolderIdsPreferenceKey)
    UserDefaults.standard.removeObject(forKey: workspaceSidebarLegacyCollapsedTabGroupIdsPreferenceKey)
    UserDefaults.standard.synchronize()
    // Keep the restart snapshot in lockstep with the visible folded state.
    // Relying only on termination left a stale snapshot behind when macOS
    // terminated/relaunched the app before its async shutdown hook completed.
    if updatesRestartSnapshot, !isUnitTest {
        persistFrozenWorldForRestartIfPossible()
    }
}
