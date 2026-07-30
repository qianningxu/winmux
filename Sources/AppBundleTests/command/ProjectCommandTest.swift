@testable import AppBundle
import Common
import XCTest

@MainActor
final class ProjectCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testLegacyProjectCommandDisabledMessageUsesTabLanguage() {
        XCTAssertEqual(
            projectFeatureDisabledMessage(),
            "Legacy project commands are disabled. Folders are always available in the sidebar."
        )
        XCTAssertFalse(projectFeatureDisabledMessage().contains("enable-projects"))
    }

    func testFolderCommandsParseWithProjectCompatibilityAlias() {
        XCTAssertTrue(parseCommand("folder").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("folder default").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("folder unfolded").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("folder next").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("project").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("project next").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-project").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-project next").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-folder").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-folder default").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-folder unfolded").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-folder next").cmdOrNil is MoveNodeToProjectCommand)
    }

    func testFolderCommandNavigatesSidebarFoldersBeforeRootTabs() async throws {
        config.enableProjects = false
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 1, parent: root.rootTilingContainer)
        let firstFolder = createWorkspaceProject()
        let firstFolderTab = projectWorkspaces(projectId: firstFolder.id).first.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 2, parent: firstFolderTab.rootTilingContainer)
        let secondFolder = createWorkspaceProject()
        let secondFolderTab = projectWorkspaces(projectId: secondFolder.id).first.orDie()
        secondFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 3, parent: secondFolderTab.rootTilingContainer)
        XCTAssertTrue(secondFolderTab.focusWorkspace())

        let folderResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(folderResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === firstFolderTab)

        let rootResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(3)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(rootResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === root)
    }

    func testFolderCommandIndexesRealSidebarFoldersAndIgnoresLabelOnlyFolders() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 21, parent: root.rootTilingContainer)
        let labelOnlyFolderId = WorkspaceProjectId("project-stale-label")
        config.workspaceSidebar.projectLabels[labelOnlyFolderId.rawValue] = "Stale"
        let emptyFolder = createWorkspaceProject()
        let visibleFolder = createWorkspaceProject()
        let visibleFolderTab = projectWorkspaces(projectId: visibleFolder.id).first.orDie()
        visibleFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 22, parent: visibleFolderTab.rootTilingContainer)
        XCTAssertTrue(root.focusWorkspace())

        XCTAssertEqual(workspaceSidebarFolderNavigationProjectIds(monitor: mainMonitor), [
            emptyFolder.id,
            visibleFolder.id,
            workspaceProjectDefaultId,
        ])

        let folderResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(folderResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === visibleFolderTab)

        let window = TestWindow.new(id: 23, parent: root.rootTilingContainer)
        _ = window.focusWindow()
        let moveResult = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(moveResult.exitCode, 0)
        XCTAssertEqual(window.nodeWorkspace?.projectId, emptyFolder.id)
    }

    func testFolderShortcutsFollowSidebarFolderOrderAfterReorder() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        let movingWindow = TestWindow.new(id: 51, parent: root.rootTilingContainer)
        let firstFolder = createWorkspaceProject()
        let firstFolderTab = projectWorkspaces(projectId: firstFolder.id).first.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 52, parent: firstFolderTab.rootTilingContainer)
        let secondFolder = createWorkspaceProject()
        let secondFolderTab = projectWorkspaces(projectId: secondFolder.id).first.orDie()
        secondFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 53, parent: secondFolderTab.rootTilingContainer)

        XCTAssertTrue(reorderWorkspaceProjectForSidebar(
            sourceProjectId: secondFolder.id,
            placement: .before(firstFolder.id)
        ))
        XCTAssertEqual(workspaceSidebarFolderNavigationProjectIds(monitor: mainMonitor), [
            secondFolder.id,
            firstFolder.id,
            workspaceProjectDefaultId,
        ])

        _ = movingWindow.focusWindow()
        let moveResult = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(moveResult.exitCode, 0)
        XCTAssertEqual(movingWindow.nodeWorkspace?.projectId, secondFolder.id)
        XCTAssertEqual(workspaceProjects().map(\.id), [
            secondFolder.id,
            firstFolder.id,
            workspaceProjectDefaultId,
        ])
        XCTAssertEqual(winMuxWorkspaceState.projectsById[workspaceProjectDefaultId]?.folderOrder, [
            WorkspaceFolderId(secondFolder.id),
            WorkspaceFolderId(firstFolder.id),
            workspaceFolderDefaultId,
        ])

        let switchResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(switchResult.exitCode, 0)
        XCTAssertEqual(focus.workspace.projectId, firstFolder.id)
    }

    func testControlNumberFolderSwitchUpdatesSingleExpandedFolder() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 54, parent: root.rootTilingContainer)
        let firstFolder = createWorkspaceProject()
        let firstFolderTab = projectWorkspaces(projectId: firstFolder.id).first.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 55, parent: firstFolderTab.rootTilingContainer)
        let secondFolder = createWorkspaceProject()
        let secondFolderTab = projectWorkspaces(projectId: secondFolder.id).first.orDie()
        secondFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 56, parent: secondFolderTab.rootTilingContainer)
        XCTAssertTrue(firstFolderTab.focusWorkspace())
        setWorkspaceSidebarFolderExpanded(firstFolder.id, isExpanded: true)

        let secondFolderResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(secondFolderResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondFolderTab)
        XCTAssertFalse(workspaceSidebarFolderIsExpanded(firstFolder.id))
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(secondFolder.id))
        XCTAssertFalse(workspaceSidebarFolderIsExpanded(workspaceProjectDefaultId))

        let unfoldedResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(3)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(unfoldedResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === root)
        XCTAssertFalse(workspaceSidebarFolderIsExpanded(firstFolder.id))
        XCTAssertFalse(workspaceSidebarFolderIsExpanded(secondFolder.id))
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(workspaceProjectDefaultId))
    }

    func testFolderNavigationCountsRemoteOnlyFoldersInSidebarOrder() async throws {
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true
        )
        let secondary = TestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        let movingWindow = TestWindow.new(id: 61, parent: root.rootTilingContainer)
        let firstFolder = createWorkspaceProject()
        let firstFolderTab = projectWorkspaces(projectId: firstFolder.id).first.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        firstFolderTab.seedMonitorIfNeeded(main)
        _ = TestWindow.new(id: 62, parent: firstFolderTab.rootTilingContainer)
        let remoteFolder = createWorkspaceProject()
        let remoteFolderTab = projectWorkspaces(projectId: remoteFolder.id).first.orDie()
        remoteFolderTab.markAsAutomaticallyNamed()
        remoteFolderTab.seedMonitorIfNeeded(secondary)
        _ = TestWindow.new(id: 63, parent: remoteFolderTab.rootTilingContainer)
        XCTAssertTrue(root.focusWorkspace())

        XCTAssertEqual(workspaceSidebarFolderNavigationProjectIds(monitor: main), [
            firstFolder.id,
            remoteFolder.id,
            workspaceProjectDefaultId,
        ])

        let switchResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(switchResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === remoteFolderTab)

        _ = movingWindow.focusWindow()
        let moveResult = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(moveResult.exitCode, 0)
        XCTAssertEqual(movingWindow.nodeWorkspace?.projectId, remoteFolder.id)
        XCTAssertEqual(workspaceProjects().map(\.id), [
            firstFolder.id,
            remoteFolder.id,
            workspaceProjectDefaultId,
        ])
    }

    func testFolderNavigationCountsUnfoldedFolderWhenEmpty() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        XCTAssertTrue(root.isEffectivelyEmpty)
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        folderTab.markAsAutomaticallyNamed()
        let window = TestWindow.new(id: 91, parent: folderTab.rootTilingContainer)
        _ = window.focusWindow()

        XCTAssertEqual(workspaceSidebarFolderNavigationProjectIds(monitor: mainMonitor), [
            folder.id,
            workspaceProjectDefaultId,
        ])

        let result = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(window.nodeWorkspace?.projectId, workspaceProjectDefaultId)
        XCTAssertNotEqual(window.nodeWorkspace, root)
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).last, window.nodeWorkspace)
    }

    func testFolderNavigationIgnoresStaleLabelsBeforeRealFolderAndCountsUnfolded() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 92, parent: root.rootTilingContainer)
        config.workspaceSidebar.projectLabels["project-1"] = "Old Folder 1"
        config.workspaceSidebar.projectLabels["project-2"] = "Old Folder 2"
        let realFolderId = WorkspaceProjectId("project-3")
        let realFolderTab = Workspace.get(byName: "real-folder-tab")
        realFolderTab.markAsAutomaticallyNamed()
        realFolderTab.assignProject(realFolderId)
        realFolderTab.seedMonitorIfNeeded(mainMonitor)
        _ = TestWindow.new(id: 93, parent: realFolderTab.rootTilingContainer)
        let window = TestWindow.new(id: 94, parent: realFolderTab.rootTilingContainer)
        _ = window.focusWindow()

        XCTAssertEqual(workspaceSidebarFolderNavigationProjectIds(monitor: mainMonitor), [
            realFolderId,
            workspaceProjectDefaultId,
        ])

        let result = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(window.nodeWorkspace?.projectId, workspaceProjectDefaultId)
        XCTAssertTrue(projectWorkspaces(projectId: WorkspaceProjectId("project-1")).isEmpty)
        XCTAssertTrue(projectWorkspaces(projectId: WorkspaceProjectId("project-2")).isEmpty)
    }

    func testFolderNavigationFollowsVisibleSidebarOrderWithLabeledGaps() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 104, parent: root.rootTilingContainer)
        config.workspaceSidebar.projectLabels[workspaceProjectDefaultId.rawValue] = "Unfolded"
        config.workspaceSidebar.projectLabels["project-1"] = "Old Folder 1"
        config.workspaceSidebar.projectLabels["project-2"] = "Polymarket"
        config.workspaceSidebar.projectLabels["project-3"] = "Old Folder 3"
        config.workspaceSidebar.projectLabels["project-4"] = "Others"

        let firstVisibleFolderId = WorkspaceProjectId("project-2")
        let firstVisibleTab = Workspace.get(byName: "polymarket-tab")
        firstVisibleTab.markAsAutomaticallyNamed()
        firstVisibleTab.assignProject(firstVisibleFolderId)
        firstVisibleTab.seedMonitorIfNeeded(mainMonitor)
        _ = TestWindow.new(id: 105, parent: firstVisibleTab.rootTilingContainer)

        let secondVisibleFolderId = WorkspaceProjectId("project-4")
        let secondVisibleTab = Workspace.get(byName: "others-tab")
        secondVisibleTab.markAsAutomaticallyNamed()
        secondVisibleTab.assignProject(secondVisibleFolderId)
        secondVisibleTab.seedMonitorIfNeeded(mainMonitor)
        _ = TestWindow.new(id: 106, parent: secondVisibleTab.rootTilingContainer)
        XCTAssertTrue(root.focusWorkspace())

        XCTAssertEqual(workspaceSidebarFolderNavigationProjectIds(monitor: mainMonitor), [
            firstVisibleFolderId,
            secondVisibleFolderId,
            workspaceProjectDefaultId,
        ])

        let switchResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(switchResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondVisibleTab)
    }

    func testFolderCommandPrefersNonEmptyTabOverRememberedBlankTab() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 81, parent: root.rootTilingContainer)
        let folder = createWorkspaceProject()
        let blankFolderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        blankFolderTab.markAsAutomaticallyNamed()
        XCTAssertTrue(blankFolderTab.focusWorkspace())
        let realFolderTab = Workspace.get(byName: "real-folder-tab")
        realFolderTab.markAsAutomaticallyNamed()
        realFolderTab.assignProject(folder.id)
        realFolderTab.seedMonitorIfNeeded(mainMonitor)
        _ = TestWindow.new(id: 82, parent: realFolderTab.rootTilingContainer)
        XCTAssertTrue(root.focusWorkspace())

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === realFolderTab)
    }

    func testFolderCommandSwitchesToRealSidebarTabInsteadOfCreatingBlank() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 95, parent: root.rootTilingContainer)
        let folder = createWorkspaceProject()
        let blankFolderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        blankFolderTab.markAsAutomaticallyNamed()
        let realFolderTab = Workspace.get(byName: "folder-real-tab")
        realFolderTab.markAsAutomaticallyNamed()
        realFolderTab.assignProject(folder.id)
        realFolderTab.seedMonitorIfNeeded(mainMonitor)
        _ = TestWindow.new(id: 96, parent: realFolderTab.rootTilingContainer)
        let knownFolderWorkspaceIds = Set(projectWorkspaces(projectId: folder.id).map(\.id))
        XCTAssertTrue(root.focusWorkspace())

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === realFolderTab)
        XCTAssertTrue(projectWorkspaces(projectId: folder.id).allSatisfy {
            knownFolderWorkspaceIds.contains($0.id)
        })
    }

    func testFolderCommandPrefersRealRemoteTabOverLocalBlankTab() async throws {
        let main = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true
        )
        let secondary = TestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 97, parent: root.rootTilingContainer)
        XCTAssertTrue(main.setActiveWorkspace(root))
        XCTAssertTrue(root.focusWorkspace())

        let folder = createWorkspaceProject()
        let localBlankTab = projectWorkspaces(projectId: folder.id).first.orDie()
        localBlankTab.markAsAutomaticallyNamed()
        localBlankTab.seedMonitorIfNeeded(main)
        let realRemoteTab = Workspace.get(byName: "folder-real-remote-tab")
        realRemoteTab.markAsAutomaticallyNamed()
        realRemoteTab.assignProject(folder.id)
        realRemoteTab.seedMonitorIfNeeded(secondary)
        _ = TestWindow.new(id: 98, parent: realRemoteTab.rootTilingContainer)
        XCTAssertTrue(secondary.setActiveWorkspace(realRemoteTab))
        XCTAssertTrue(root.focusWorkspace())

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(main.activeWorkspace === realRemoteTab)
        XCTAssertFalse(main.activeWorkspace === localBlankTab)
        XCTAssertTrue(focus.workspace === realRemoteTab)
    }

    func testFolderCommandCanTargetUnfoldedByName() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 31, parent: root.rootTilingContainer)
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        _ = TestWindow.new(id: 32, parent: folderTab.rootTilingContainer)
        XCTAssertTrue(folderTab.focusWorkspace())

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .defaultFolder),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === root)
    }

    func testFolderCommandNavigatesRelativeSidebarFolders() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 4, parent: root.rootTilingContainer)
        let firstFolder = createWorkspaceProject()
        let firstFolderTab = projectWorkspaces(projectId: firstFolder.id).first.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 5, parent: firstFolderTab.rootTilingContainer)
        let secondFolder = createWorkspaceProject()
        let secondFolderTab = projectWorkspaces(projectId: secondFolder.id).first.orDie()
        secondFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 6, parent: secondFolderTab.rootTilingContainer)
        XCTAssertTrue(firstFolderTab.focusWorkspace())

        let nextResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .relative(.next)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(nextResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === secondFolderTab)

        let rootResult = try await ProjectCommand(
            args: ProjectCmdArgs(target: .relative(.next)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(rootResult.exitCode, 0)
        XCTAssertTrue(focus.workspace === root)
    }

    func testMoveNodeToFolderCommandMovesToSidebarFolderWhenProjectsDisabled() async throws {
        let window = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer)
        _ = window.focusWindow()
        config.enableProjects = false
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        folderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 2, parent: folderTab.rootTilingContainer)

        let result = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(window.nodeWorkspace?.projectId, folder.id)
    }

    func testMoveNodeToFolderCreatesTrailingStandaloneTab() async throws {
        let window = TestWindow.new(id: 101, parent: focus.workspace.rootTilingContainer)
        _ = window.focusWindow()
        let folder = createWorkspaceProject()
        let firstFolderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 102, parent: firstFolderTab.rootTilingContainer)
        let secondFolderTab = Workspace.get(byName: "second-folder-tab")
        secondFolderTab.markAsAutomaticallyNamed()
        secondFolderTab.assignProject(folder.id)
        secondFolderTab.seedMonitorIfNeeded(mainMonitor)
        _ = TestWindow.new(id: 103, parent: secondFolderTab.rootTilingContainer)

        let result = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        let destination = window.nodeWorkspace
        guard let destination else {
            XCTFail("Expected window to move to a folder tab")
            return
        }
        XCTAssertEqual(destination.projectId, folder.id)
        XCTAssertFalse(destination === firstFolderTab)
        XCTAssertFalse(destination === secondFolderTab)
        XCTAssertEqual(projectWorkspaces(projectId: folder.id), [
            firstFolderTab,
            secondFolderTab,
            destination,
        ])
    }

    func testMoveNodeToFolderCanTargetUnfoldedByName() async throws {
        let root = focus.workspace
        root.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 41, parent: root.rootTilingContainer)
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        let window = TestWindow.new(id: 42, parent: folderTab.rootTilingContainer)
        _ = window.focusWindow()

        let result = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .defaultFolder),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(window.nodeWorkspace?.projectId, workspaceProjectDefaultId)
    }

    func testFolderCommandIgnoresLegacyProjectsConfiguredEnabledFlag() async throws {
        config.enableProjects = true
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        folderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 7, parent: folderTab.rootTilingContainer)

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === folderTab)
    }

    func testFolderCommandSwitchesToPersistedFolderLabelWhenProjectsDisabled() async throws {
        let projectId = WorkspaceProjectId("project-7")
        config.enableProjects = false
        config.workspaceSidebar.projectLabels[projectId.rawValue] = "Research"
        let workspace = Workspace.get(byName: "research-tab")
        workspace.assignProject(projectId)
        workspace.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 71, parent: workspace.rootTilingContainer)

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(focus.workspace.projectId, projectId)
        XCTAssertEqual(workspaceProjectName(projectId), "Research")
    }

    func testFoldersUseSeparateStorageWhenProjectsDisabled() async throws {
        config.enableProjects = true
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        folderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 8, parent: folderTab.rootTilingContainer)

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertNil(winMuxWorkspaceState.projectsById[folder.id])
        XCTAssertNotNil(winMuxWorkspaceState.workspaceFoldersById[WorkspaceFolderId(folder.id)])
        XCTAssertTrue(winMuxWorkspaceState.projectsById[workspaceProjectDefaultId]?.folderOrder.contains(WorkspaceFolderId(folder.id)) == true)
        XCTAssertTrue(workspaceSidebarFolderMutationIsEnabled(folder.id))

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === folderTab)
    }

    func testDisabledProjectContainsMultipleSeparateFolders() async throws {
        config.enableProjects = true
        let firstFolder = createWorkspaceProject()
        let secondFolder = createWorkspaceProject()
        let firstFolderId = WorkspaceFolderId(firstFolder.id)
        let secondFolderId = WorkspaceFolderId(secondFolder.id)
        let firstTab = projectWorkspaces(projectId: firstFolder.id).first.orDie()
        let secondTab = projectWorkspaces(projectId: secondFolder.id).first.orDie()

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertNil(winMuxWorkspaceState.projectsById[firstFolder.id])
        XCTAssertNil(winMuxWorkspaceState.projectsById[secondFolder.id])
        XCTAssertEqual(winMuxWorkspaceState.workspaceFoldersById[firstFolderId]?.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(winMuxWorkspaceState.workspaceFoldersById[secondFolderId]?.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(winMuxWorkspaceState.projectsById[workspaceProjectDefaultId]?.folderOrder, [
            firstFolderId,
            secondFolderId,
            workspaceFolderDefaultId,
        ])
        XCTAssertEqual(firstTab.folderId, firstFolderId)
        XCTAssertEqual(secondTab.folderId, secondFolderId)
        XCTAssertEqual(firstTab.projectId, firstFolder.id)
        XCTAssertEqual(secondTab.projectId, secondFolder.id)
    }
}
