@testable import AppBundle
import Common
import XCTest

@MainActor
final class ProjectCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

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

    func testProjectCommandStillWorksWhenProjectsEnabled() async throws {
        let project = createWorkspaceProject()

        let result = try await ProjectCommand(
            args: ProjectCmdArgs(target: .index(2)),
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(focus.workspace.projectId, project.id)
    }
}
