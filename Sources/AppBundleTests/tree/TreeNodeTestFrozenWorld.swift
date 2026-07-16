@testable import AppBundle
import XCTest

extension TreeNodeTest {
    func testExitMacOsNativeUnconventionalStateRestoresWindowToPreviousWorkspaceWhileWorkspaceStaysAlive() async throws {
        let workspaceA = Workspace.get(byName: "a")
        let window = TestWindow.new(id: 1, parent: workspaceA.rootTilingContainer)
        let workspaceB = Workspace.get(byName: "b")

        window.layoutReason = .macos(prevParentKind: .tilingContainer, prevWorkspaceName: workspaceA.name)
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
        _ = workspaceB.focusWorkspace()

        Workspace.reconcileWorkspaceState()
        XCTAssertEqual(Workspace.existing(byName: workspaceA.name), workspaceA)

        try await exitMacOsNativeUnconventionalState(
            window: window,
            prevParentKind: .tilingContainer,
            prevWorkspaceName: workspaceA.name,
            workspace: workspaceB,
        )

        let restoredWorkspace = Workspace.existing(byName: workspaceA.name).orDie()
        XCTAssertEqual(window.nodeWorkspace, restoredWorkspace)
        XCTAssertTrue(restoredWorkspace.rootTilingContainer.children.contains(window))
        XCTAssertEqual(restoredWorkspace.preferredMonitorPointForTesting, workspaceB.workspaceMonitor.rect.topLeftCorner)
    }

    func testPersistedFrozenWorldCodableRoundTrip() throws {
        let workspace = Workspace.get(byName: "1")
        let tabGroup = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: 0)
        let fullscreenWindow = TestWindow.new(id: 11, parent: tabGroup, adaptiveWeight: 1)
        TestWindow.new(id: 12, parent: tabGroup, adaptiveWeight: 1)
        fullscreenWindow.isFullscreen = true
        fullscreenWindow.noOuterGapsInFullscreen = true
        fullscreenWindow.layoutReason = .macos(prevParentKind: .tilingContainer, prevWorkspaceName: workspace.name)

        let frozenWorld = FrozenWorld(
            workspaces: [FrozenWorkspace(workspace)],
            monitors: monitors.map(FrozenMonitor.init),
            windowIds: [11, 12],
            sidebar: FrozenSidebarState(restorableWorkspaces: [workspace]),
        )

        let data = try JSONEncoder().encode(frozenWorld)
        let decoded = try JSONDecoder().decode(FrozenWorld.self, from: data)

        XCTAssertEqual(decoded.windowIds, [11, 12])
        XCTAssertEqual(decoded.workspaces.count, 1)
        XCTAssertEqual(decoded.sidebar?.projects.singleOrNil()?.workspaceNames, [workspace.name])

        let frozenChild = try XCTUnwrap(decoded.workspaces.first?.rootTilingNode.children.first)
        switch frozenChild {
            case .container(let container):
                XCTAssertEqual(container.layout, .tabGroup)
                XCTAssertEqual(container.orientation, .h)
                XCTAssertEqual(container.children.count, 2)
                let fullscreenChild = try XCTUnwrap(container.children.first)
                guard case .window(let decodedWindow) = fullscreenChild else {
                    return XCTFail("Expected fullscreen window leaf in persisted frozen world")
                }
                XCTAssertTrue(decodedWindow.isFullscreen)
                XCTAssertTrue(decodedWindow.noOuterGapsInFullscreen)
                XCTAssertEqual(decodedWindow.layoutReason, .macos(prevParentKind: .tilingContainer, prevWorkspaceName: workspace.name))
            case .window:
                XCTFail("Expected nested container in persisted frozen world")
        }
    }

    func testFrozenWorldDecodesLegacyPayloadWithoutSidebarState() throws {
        let json = #"{"workspaces":[],"monitors":[],"windowIds":[]}"#

        let decoded = try JSONDecoder().decode(FrozenWorld.self, from: Data(json.utf8))

        XCTAssertNil(decoded.sidebar)
        XCTAssertTrue(decoded.workspaces.isEmpty)
        XCTAssertTrue(decoded.monitors.isEmpty)
        XCTAssertTrue(decoded.windowIds.isEmpty)
    }

    func testFrozenWorldDecodesLegacySidebarStateWithoutLabels() throws {
        let json = #"{"workspaces":[],"monitors":[],"windowIds":[],"sidebar":{"projects":[],"collapsedFolderIds":[]}}"#

        let decoded = try JSONDecoder().decode(FrozenWorld.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.sidebar?.workspaceLabels, [:])
        XCTAssertEqual(decoded.sidebar?.projectLabels, [:])
    }

    func testSnapshotCurrentFrozenWorldExcludesDetachedMinimizedWindow() {
        let workspace = Workspace.get(byName: "minimized")
        let window = TestWindow.new(id: 32, parent: workspace.rootTilingContainer)

        window.rememberMacOsLayoutOrigin(detachFromWorkspace: true)
        window.nativeIsMacosMinimized = true
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)

        let frozenWorld = snapshotCurrentFrozenWorld()

        XCTAssertTrue(frozenWorld.windowIds.isEmpty)
        XCTAssertTrue(frozenWorld.workspaces.isEmpty)
    }

    func testSnapshotCurrentFrozenWorldCapturesSidebarFolderOrderAndExpansion() {
        let first = Workspace.get(byName: "first")
        first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 51, parent: first.rootTilingContainer)
        let second = Workspace.get(byName: "second")
        second.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 52, parent: second.rootTilingContainer)
        let folder = createWorkspaceProject()
        first.assignProject(folder.id)
        second.assignProject(folder.id)
        var storedFolder = winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)].orDie()
        storedFolder.workspaceOrder = [second.id, first.id]
        winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)] = storedFolder
        setWorkspaceSidebarFolderExpanded(folder.id, isExpanded: false)

        let frozenWorld = snapshotCurrentFrozenWorld()
        let frozenFolder = frozenWorld.sidebar?.projects.first { $0.id == folder.id }

        XCTAssertEqual(frozenFolder?.workspaceNames, ["second", "first"])
        XCTAssertTrue(frozenWorld.sidebar?.collapsedFolderIds.contains(folder.id) == true)
    }

    func testSnapshotCurrentFrozenWorldKeepsEmptySidebarFoldersForRestart() {
        let workspace = Workspace.get(byName: "retained")
        workspace.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 54, parent: workspace.rootTilingContainer)
        let emptyFolder = createWorkspaceProject()

        let frozenWorld = snapshotCurrentFrozenWorld()

        XCTAssertTrue(frozenWorld.sidebar?.projects.contains(where: { $0.id == emptyFolder.id }) == true)
    }

    func testRestoreFrozenSidebarStateRestoresFolderWithoutMatchingWindowIds() {
        let first = Workspace.get(byName: "first")
        first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 55, parent: first.rootTilingContainer)
        let folder = createWorkspaceProject()
        first.assignProject(folder.id)
        let sidebar = FrozenSidebarState(restorableWorkspaces: [first])

        first.assignProject(workspaceProjectDefaultId)
        restoreFrozenSidebarState(sidebar, restoredWorkspaceNames: [first.name])

        XCTAssertEqual(first.projectId, folder.id)
        XCTAssertNotNil(winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)])
    }

    func testSnapshotCurrentFrozenWorldCapturesSidebarRenamedTabsAndFolders() throws {
        let workspace = Workspace.get(byName: "renamed")
        workspace.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 53, parent: workspace.rootTilingContainer)
        let folder = createWorkspaceProject()
        workspace.assignProject(folder.id)
        try renameWorkspaceForSidebar(workspaceName: workspace.name, displayName: "Design")
        try renameWorkspaceProject(folder.id, displayName: "Client")

        let frozenWorld = snapshotCurrentFrozenWorld()

        XCTAssertEqual(frozenWorld.sidebar?.workspaceLabels[workspace.name], "Design")
        XCTAssertEqual(frozenWorld.sidebar?.projectLabels[folder.id.rawValue], "Client")
    }

    func testRestoreFrozenWorldRestoresSidebarOrderAndCollapsedFolders() async throws {
        let first = Workspace.get(byName: "first")
        first.markAsAutomaticallyNamed()
        let firstWindow = TestWindow.new(id: 61, parent: first.rootTilingContainer)
        let second = Workspace.get(byName: "second")
        second.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 62, parent: second.rootTilingContainer)
        let folder = createWorkspaceProject()
        let retainedFolderTab = try XCTUnwrap(projectWorkspaces(projectId: folder.id).first)
        first.assignProject(folder.id)
        second.assignProject(folder.id)
        var storedFolder = winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)].orDie()
        storedFolder.workspaceOrder = [second.id, first.id]
        winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)] = storedFolder
        setWorkspaceSidebarFolderExpanded(folder.id, isExpanded: false)
        let frozenWorld = snapshotCurrentFrozenWorld()

        first.assignProject(workspaceProjectDefaultId)
        second.assignProject(workspaceProjectDefaultId)
        setWorkspaceSidebarFolderExpanded(folder.id, isExpanded: true)

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: firstWindow)

        XCTAssertTrue(didRestore)
        XCTAssertEqual(first.projectId, folder.id)
        XCTAssertEqual(second.projectId, folder.id)
        XCTAssertEqual(
            winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)]?.workspaceOrder,
            [second.id, first.id, retainedFolderTab.id],
        )
        XCTAssertFalse(workspaceSidebarFolderIsExpanded(folder.id))
    }

    func testRestoreFrozenWorldRestoresSidebarRenamedTabsAndFolders() async throws {
        let workspace = Workspace.get(byName: "renamed")
        workspace.markAsAutomaticallyNamed()
        let window = TestWindow.new(id: 64, parent: workspace.rootTilingContainer)
        let folder = createWorkspaceProject()
        workspace.assignProject(folder.id)
        try renameWorkspaceForSidebar(workspaceName: workspace.name, displayName: "Design")
        try renameWorkspaceProject(folder.id, displayName: "Client")
        let frozenWorld = snapshotCurrentFrozenWorld()

        config.workspaceSidebar.workspaceLabels.removeValue(forKey: workspace.name)
        config.workspaceSidebar.projectLabels.removeValue(forKey: folder.id.rawValue)
        workspace.assignProject(workspaceProjectDefaultId)

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: window)

        XCTAssertTrue(didRestore)
        XCTAssertEqual(config.workspaceSidebar.workspaceLabels[workspace.name], "Design")
        XCTAssertEqual(config.workspaceSidebar.projectLabels[folder.id.rawValue], "Client")
    }

    func testRestoreFrozenWorldKeepsSidebarTabsOnTheirSavedMonitor() async throws {
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 760),
            isMain: true,
        )
        let secondary = TestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 800),
            visibleRect: Rect(topLeftX: 1000, topLeftY: 0, width: 1000, height: 760),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        let workspace = Workspace.get(byName: "secondary")
        workspace.markAsAutomaticallyNamed()
        workspace.seedMonitorIfNeeded(secondary)
        let window = TestWindow.new(id: 63, parent: workspace.rootTilingContainer)
        let frozenWorld = snapshotCurrentFrozenWorld()

        workspace.preferredMonitorPoint = main.rect.topLeftCorner

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: window)

        XCTAssertTrue(didRestore)
        XCTAssertEqual(workspace.preferredMonitorPointForTesting, secondary.rect.topLeftCorner)
    }

    func testRestoreFrozenWorldIfNeededUsesNativeFallbackWorkspaceForMissingVisibleWorkspace() async throws {
        let occupiedWorkspace = Workspace.get(byName: "occupied")
        let window = TestWindow.new(id: 31, parent: occupiedWorkspace.rootTilingContainer)
        let emptyWorkspace = Workspace.get(byName: "empty")
        _ = emptyWorkspace.focusWorkspace()

        let frozenWorld = FrozenWorld(
            workspaces: [FrozenWorkspace(occupiedWorkspace)],
            monitors: monitors.map(FrozenMonitor.init),
            windowIds: [window.windowId],
        )

        _ = occupiedWorkspace.focusWorkspace()
        Workspace.reconcileWorkspaceState()
        XCTAssertNil(Workspace.existing(byName: emptyWorkspace.name))

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: window)
        XCTAssertTrue(didRestore)

        XCTAssertEqual(mainMonitor.activeWorkspace.projectId, workspaceProjectDefaultId)
        XCTAssertTrue(mainMonitor.activeWorkspace.isEffectivelyEmpty)
        XCTAssertTrue(mainMonitor.activeWorkspace !== occupiedWorkspace)
    }

    func testRestoreFrozenWorldIfNeededRestoresWindowFullscreenState() async throws {
        let workspace = Workspace.get(byName: "restore")
        let tiled = TestWindow.new(id: 41, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 42, parent: workspace)
        tiled.isFullscreen = true
        tiled.noOuterGapsInFullscreen = true
        floating.isFullscreen = true
        floating.noOuterGapsInFullscreen = false

        let frozenWorld = FrozenWorld(
            workspaces: [FrozenWorkspace(workspace)],
            monitors: monitors.map(FrozenMonitor.init),
            windowIds: [tiled.windowId, floating.windowId],
        )

        tiled.isFullscreen = false
        tiled.noOuterGapsInFullscreen = false
        floating.isFullscreen = false
        floating.noOuterGapsInFullscreen = true

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: tiled)

        XCTAssertTrue(didRestore)
        XCTAssertTrue(tiled.isFullscreen)
        XCTAssertTrue(tiled.noOuterGapsInFullscreen)
        XCTAssertTrue(floating.isFullscreen)
        XCTAssertFalse(floating.noOuterGapsInFullscreen)
    }

    func testRestoreFrozenWorldMigratesLegacyTopTabGroupIntoSidebarTabs() async throws {
        let workspace = Workspace.get(byName: "restore-tabs")
        workspace.markAsAutomaticallyNamed()
        let tabGroup = TilingContainer(parent: workspace.rootTilingContainer, adaptiveWeight: 1, .h, .tabGroup, index: 0)
        let first = TestWindow.new(id: 141, parent: tabGroup, adaptiveWeight: 1)
        let active = TestWindow.new(id: 142, parent: tabGroup, adaptiveWeight: 1)
        active.markAsMostRecentChild()
        let frozenWorld = FrozenWorld(
            workspaces: [FrozenWorkspace(workspace)],
            monitors: monitors.map(FrozenMonitor.init),
            windowIds: [first.windowId, active.windowId],
        )
        guard case .container(let frozenTabGroup) = frozenWorld.workspaces[0].rootTilingNode.children[0] else {
            return XCTFail("Expected frozen legacy tab group")
        }
        XCTAssertEqual(frozenTabGroup.layout, .tabGroup)
        XCTAssertEqual(frozenTabGroup.children.count, 2)
        first.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        active.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        _ = tabGroup.bind(to: NilTreeNode.instance, adaptiveWeight: WEIGHT_DOESNT_MATTER, index: INDEX_BIND_LAST)
        XCTAssertFalse(workspace.rootTilingContainer.allTabbedContainersRecursive.contains { $0.layout == .tabGroup })

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: first)

        XCTAssertTrue(didRestore)
        XCTAssertFalse(Workspace.all.contains { workspace in
            workspace.rootTilingContainer.allTabbedContainersRecursive.contains { $0.layout == .tabGroup && $0.children.count > 1 }
        })
        XCTAssertTrue(active.nodeWorkspace === workspace)
        XCTAssertTrue(first.nodeWorkspace !== workspace)
        XCTAssertEqual(first.nodeWorkspace?.rootTilingContainer.children, [first])
        XCTAssertEqual(workspace.rootTilingContainer.children, [active])
        XCTAssertEqual(workspace.rootTilingContainer.layout, .tiles)
    }

    func testRestoreFrozenWorldIfNeededRetilesRestoredMinimizedWindowAfterNativeUnminimize() async throws {
        let workspace = Workspace.get(byName: "restore")
        let window = TestWindow.new(id: 43, parent: workspace.rootTilingContainer)
        window.rememberMacOsLayoutOrigin(detachFromWorkspace: true)
        window.nativeIsMacosMinimized = true
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)

        let frozenWorld = FrozenWorld(
            workspaces: [FrozenWorkspace(workspace)],
            monitors: monitors.map(FrozenMonitor.init),
            windowIds: [window.windowId],
        )

        let stagingWorkspace = Workspace.get(byName: "staging")
        window.nativeIsMacosMinimized = false
        window.layoutReason = .standard
        window.bindAsFloatingWindow(to: stagingWorkspace)

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: window)

        XCTAssertFalse(didRestore)
        XCTAssertEqual(window.nodeWorkspace, stagingWorkspace)
        XCTAssertTrue(stagingWorkspace.floatingWindows.contains(window))
        XCTAssertEqual(window.layoutReason, .standard)
    }

    func testRestoreFrozenWorldIfNeededKeepsStillMinimizedWindowInMinimizedContainer() async throws {
        let workspace = Workspace.get(byName: "restore")
        let window = TestWindow.new(id: 44, parent: workspace.rootTilingContainer)
        window.rememberMacOsLayoutOrigin(detachFromWorkspace: true)
        window.nativeIsMacosMinimized = true
        window.bind(to: macosMinimizedWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)

        let frozenWorld = FrozenWorld(
            workspaces: [FrozenWorkspace(workspace)],
            monitors: monitors.map(FrozenMonitor.init),
            windowIds: [window.windowId],
        )

        let stagingWorkspace = Workspace.get(byName: "staging")
        window.layoutReason = .standard
        window.bindAsFloatingWindow(to: stagingWorkspace)

        let didRestore = try await restoreFrozenWorldIfNeeded(frozenWorld, newlyDetectedWindow: window)

        XCTAssertFalse(didRestore)
        XCTAssertEqual(window.nodeWorkspace, stagingWorkspace)
        XCTAssertTrue(stagingWorkspace.floatingWindows.contains(window))
        XCTAssertEqual(window.layoutReason, .standard)
    }
}
