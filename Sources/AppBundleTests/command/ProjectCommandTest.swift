@testable import AppBundle
import Common
import XCTest

@MainActor
final class ProjectCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testLegacyProjectCommandDisabledMessageUsesTabLanguage() {
        XCTAssertEqual(
            projectFeatureDisabledMessage(),
            "Legacy folder commands are disabled. Tabs and folders are managed in the sidebar."
        )
        XCTAssertFalse(projectFeatureDisabledMessage().contains("enable-projects"))
    }

    func testFolderCommandsParseWithProjectCompatibilityAlias() {
        XCTAssertTrue(parseCommand("folder").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("folder next").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("project").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("project next").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-project").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-project next").cmdOrNil is MoveNodeToProjectCommand)
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

    func testMoveNodeToProjectCommandFailsWhenProjectsDisabled() async throws {
        _ = TestWindow.new(id: 1, parent: focus.workspace.rootTilingContainer).focusWindow()
        config.enableProjects = false

        let result = try await MoveNodeToProjectCommand(
            args: MoveNodeToProjectCmdArgs(target: .relative(.next)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, [projectFeatureDisabledMessage()])
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

    func testProjectBackingStorageRemainsAvailableForSidebarFolders() async throws {
        config.enableProjects = true
        let folder = createWorkspaceProject()
        let folderTab = projectWorkspaces(projectId: folder.id).first.orDie()
        folderTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 8, parent: folderTab.rootTilingContainer)

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertNotNil(winMuxWorkspaceState.projectsById[folder.id])
        XCTAssertTrue(workspaceSidebarFolderMutationIsEnabled(folder.id))

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(1)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertTrue(focus.workspace === folderTab)
    }
}
