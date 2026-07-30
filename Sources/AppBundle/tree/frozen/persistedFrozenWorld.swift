import Common
import Foundation

private let persistedFrozenWorldVersion = 1
private let persistedFrozenWorldFilename = "window-state.json"
private let persistedSidebarStateFilename = "sidebar-state.json"
@MainActor private var pendingPersistedFrozenWorld: FrozenWorld? = nil
@MainActor private var didRestorePersistedFrozenWorldDuringCurrentSession = false
@MainActor private var pendingPersistedSidebarState: FrozenSidebarState? = nil
@MainActor private var didRestorePersistedSidebarStateDuringCurrentSession = false
@MainActor private var didLoadPersistedSidebarStateDuringCurrentSession = false
@MainActor private var isPersistedSidebarStateReady = false
@MainActor private var isSidebarStatePersistenceScheduled = false

private struct PersistedFrozenWorldEnvelope: Codable {
    let version: Int
    let world: FrozenWorld
}

private struct PersistedSidebarStateEnvelope: Codable {
    let version: Int
    let sidebar: FrozenSidebarState
}

@MainActor
private func persistedFrozenWorldUrl() throws -> URL {
    let appSupport = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true,
    )
    let directory = appSupport.appendingPathComponent(winMuxAppName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent(persistedFrozenWorldFilename, isDirectory: false)
}

@MainActor
private func persistedSidebarStateUrl() throws -> URL {
    try persistedFrozenWorldUrl()
        .deletingLastPathComponent()
        .appendingPathComponent(persistedSidebarStateFilename, isDirectory: false)
}

/// Folder identity, order, membership, and folded state are independent from
/// the temporary window-layout restart snapshot.  Save them independently so
/// a folder change survives a quick quit, a crash, or a restart that cannot
/// match the old macOS window IDs.
@MainActor
func persistSidebarStateForRestartIfPossible() {
    guard !isUnitTest, isPersistedSidebarStateReady else { return }
    do {
        let sidebar = FrozenSidebarState(restorableWorkspaces: Workspace.all.filter { !$0.isArchived })
        let data = try JSONEncoder.winMuxDefault.encode(
            PersistedSidebarStateEnvelope(version: persistedFrozenWorldVersion, sidebar: sidebar),
        )
        try data.write(to: persistedSidebarStateUrl(), options: .atomic)
    } catch {
        // Folder persistence is best effort and must never interrupt a UI
        // mutation or shutdown.
    }
}

/// State mutations often happen through an `inout` access to
/// `winMuxWorkspaceState`.  Saving synchronously from a property observer
/// re-entered that access and caused a Swift exclusivity crash at launch.
/// Coalesce the write onto the next main-loop turn instead.
@MainActor
func scheduleSidebarStatePersistenceForRestart() {
    guard !isUnitTest,
          isPersistedSidebarStateReady,
          !isSidebarStatePersistenceScheduled
    else { return }
    isSidebarStatePersistenceScheduled = true
    DispatchQueue.main.async {
        isSidebarStatePersistenceScheduled = false
        persistSidebarStateForRestartIfPossible()
    }
}

@MainActor
func loadPersistedSidebarStateForStartupIfPresent() {
    defer {
        didRestorePersistedSidebarStateDuringCurrentSession = false
        isPersistedSidebarStateReady = false
    }
    didLoadPersistedSidebarStateDuringCurrentSession = false
    do {
        let url = try persistedSidebarStateUrl()
        guard FileManager.default.fileExists(atPath: url.path) else {
            pendingPersistedSidebarState = nil
            return
        }
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(PersistedSidebarStateEnvelope.self, from: data)
        pendingPersistedSidebarState = envelope.version == persistedFrozenWorldVersion ? envelope.sidebar : nil
        didLoadPersistedSidebarStateDuringCurrentSession = pendingPersistedSidebarState != nil
    } catch {
        pendingPersistedSidebarState = nil
    }
}

@MainActor
func finalizePersistedSidebarStateAfterStartupIfNeeded() {
    guard !didRestorePersistedSidebarStateDuringCurrentSession else { return }
    if let sidebar = pendingPersistedSidebarState {
        restoreFrozenSidebarState(
            sidebar,
            restoredWorkspaceNames: Set(Workspace.all.map(\.name)),
            materializeMissingWorkspaces: true,
        )
        pendingPersistedSidebarState = nil
    }
    didRestorePersistedSidebarStateDuringCurrentSession = true
    isPersistedSidebarStateReady = true
    // Capture the post-restore state immediately.  Unlike window-state.json,
    // sidebar-state.json is intentionally retained for every subsequent run.
    // Persistence must be enabled before this call. Previously these flags
    // were updated in a defer block, so this write always returned at its
    // readiness guard and the restored folders were never checkpointed.
    persistSidebarStateForRestartIfPossible()
}

@MainActor
func persistFrozenWorldForRestartIfPossible() {
    persistSidebarStateForRestartIfPossible()
    do {
        let url = try persistedFrozenWorldUrl()
        let world = snapshotCurrentFrozenWorld()
        guard !world.windowIds.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let data = try JSONEncoder.winMuxDefault.encode(
            PersistedFrozenWorldEnvelope(version: persistedFrozenWorldVersion, world: world),
        )
        try data.write(to: url, options: .atomic)
    } catch {
        // Best effort. Failure to save restart state must not block termination.
    }
}

@discardableResult
@MainActor
func loadPersistedFrozenWorldForStartupIfPresent() -> Bool {
    do {
        let url = try persistedFrozenWorldUrl()
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(PersistedFrozenWorldEnvelope.self, from: data)
        guard envelope.version == persistedFrozenWorldVersion else { return false }
        pendingPersistedFrozenWorld = envelope.world
        didRestorePersistedFrozenWorldDuringCurrentSession = false
        return true
    } catch {
        return false
    }
}

@MainActor
func restorePersistedFrozenWorldIfNeeded(newlyDetectedWindow: Window) async throws -> Bool {
    guard let pendingPersistedFrozenWorld else { return false }
    let didRestore = try await restoreFrozenWorldIfNeeded(pendingPersistedFrozenWorld, newlyDetectedWindow: newlyDetectedWindow)
    if didRestore {
        didRestorePersistedFrozenWorldDuringCurrentSession = true
    }
    return didRestore
}

@MainActor
func finalizePersistedFrozenWorldAfterRefresh(aliveWindowIds: Set<UInt32>) {
    defer { finalizePersistedSidebarStateAfterStartupIfNeeded() }
    guard let world = pendingPersistedFrozenWorld else { return }
    let knownWindowIds = Set(MacWindow.allWindowsMap.keys)
    // Window IDs can legitimately change when WinMux itself is restarted even
    // though the user's browser windows and sidebar workspaces survive. Once
    // the startup scan has found at least the saved number of windows, restore
    // sidebar folder membership by its durable workspace names instead of
    // dropping every folder because no old window ID matched.
    let canRestoreSidebarByWorkspaceName = !didRestorePersistedFrozenWorldDuringCurrentSession &&
        knownWindowIds.count >= world.windowIds.count &&
        Workspace.all.count >= world.workspaces.count
    if canRestoreSidebarByWorkspaceName {
        // sidebar-state.json is updated after every sidebar mutation and is
        // therefore newer than the sidebar copy embedded in window-state.json.
        // Do not let the older layout snapshot overwrite it after a delayed
        // startup refresh.
        if !didLoadPersistedSidebarStateDuringCurrentSession {
            restoreFrozenSidebarState(
                world.sidebar,
                restoredWorkspaceNames: Set(Workspace.all.map(\.name))
            )
        }
        pendingPersistedFrozenWorld = nil
        didRestorePersistedFrozenWorldDuringCurrentSession = false
        try? FileManager.default.removeItem(at: persistedFrozenWorldUrl())
        return
    }
    if world.windowIds.isSubset(of: knownWindowIds) ||
        (didRestorePersistedFrozenWorldDuringCurrentSession &&
            !world.windowIds.isSubset(of: aliveWindowIds))
    {
        pendingPersistedFrozenWorld = nil
        didRestorePersistedFrozenWorldDuringCurrentSession = false
        try? FileManager.default.removeItem(at: persistedFrozenWorldUrl())
    }
}
