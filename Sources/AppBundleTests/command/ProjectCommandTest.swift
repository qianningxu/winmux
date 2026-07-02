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

    func testDisabledLegacyProjectCommandsParseWithOrWithoutOldTargets() {
        XCTAssertTrue(parseCommand("project").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("project next").cmdOrNil is ProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-project").cmdOrNil is MoveNodeToProjectCommand)
        XCTAssertTrue(parseCommand("move-node-to-project next").cmdOrNil is MoveNodeToProjectCommand)
    }

    func testProjectCommandFailsWhenProjectsDisabled() async throws {
        config.enableProjects = false

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .relative(.next)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, [projectFeatureDisabledMessage()])
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

    func testProjectCommandFailsEvenWhenProjectsConfiguredEnabled() async throws {
        config.enableProjects = true
        _ = createWorkspaceProject()

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, [projectFeatureDisabledMessage()])
    }

    func testProjectBackingStorageRemainsAvailableForSidebarFoldersWhileCommandsAreDisabled() async throws {
        config.enableProjects = true
        let folder = createWorkspaceProject()

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertNotNil(winMuxWorkspaceState.projectsById[folder.id])
        XCTAssertTrue(workspaceSidebarFolderMutationIsEnabled(folder.id))

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, [projectFeatureDisabledMessage()])
    }
}
