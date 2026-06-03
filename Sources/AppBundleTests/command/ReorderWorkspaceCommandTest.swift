@testable import AppBundle
import Common
import XCTest

@MainActor
final class ReorderWorkspaceCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseReorderWorkspaceCommand() {
        testParseCommandSucc(
            "reorder-workspace 3 --before 2",
            ReorderWorkspaceCmdArgs(source: .parse("3").getOrDie(), beforeTarget: .parse("2").getOrDie())
        )
        testParseCommandSucc(
            "reorder-workspace 1 --after 2",
            ReorderWorkspaceCmdArgs(source: .parse("1").getOrDie(), afterTarget: .parse("2").getOrDie())
        )
        assertEquals(parseCommand("reorder-workspace 1").errorOrNil, "Either --before or --after is required")
        assertEquals(parseCommand("reorder-workspace 1 --before 2 --after 3").errorOrNil, "ERROR: Conflicting options: --after, --before")
    }

    func testReorderWorkspaceCommandMovesSourceBeforeTarget() async throws {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        let result = try await ReorderWorkspaceCommand(
            args: ReorderWorkspaceCmdArgs(
                source: .parse(third.name).getOrDie(),
                beforeTarget: .parse(second.name).getOrDie()
            )
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 0)
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            first.name,
            third.name,
            second.name,
        ])
    }

    func testReorderWorkspaceCommandRejectsMissingTarget() async throws {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        let result = try await ReorderWorkspaceCommand(
            args: ReorderWorkspaceCmdArgs(
                source: .parse(first.name).getOrDie(),
                afterTarget: .parse("missing").getOrDie()
            )
        ).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["Workspace 'missing' doesn't exist"])
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            first.name,
            second.name,
            third.name,
        ])
    }

    private func makeOrderedDefaultWorkspaces() -> (Workspace, Workspace, Workspace) {
        let first = focus.workspace
        let second = Workspace.get(byName: "second")
        let third = Workspace.get(byName: "third")
        _ = TestWindow.new(id: 1, parent: first.rootTilingContainer)
        _ = TestWindow.new(id: 2, parent: second.rootTilingContainer)
        _ = TestWindow.new(id: 3, parent: third.rootTilingContainer)
        setDefaultWorkspaceOrder([first, second, third])
        return (first, second, third)
    }

    private func setDefaultWorkspaceOrder(_ workspaces: [Workspace]) {
        for workspace in workspaces {
            workspace.assignProject(workspaceProjectDefaultId)
        }
        var project = winMuxWorkspaceState.projectsById[workspaceProjectDefaultId].orDie()
        project.workspaceOrder = workspaces.map(\.id)
        winMuxWorkspaceState.projectsById[workspaceProjectDefaultId] = project
    }
}
