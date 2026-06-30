@testable import AppBundle
import Common
import XCTest

@MainActor
final class StackWithCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testStackWithRightIsDisabledForSidebarTabs() async throws {
        let root = Workspace.get(byName: name).rootTilingContainer.apply {
            TestWindow.new(id: 0, parent: $0)
            assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            TestWindow.new(id: 2, parent: $0)
        }

        let result = try await StackWithCommand(args: StackWithCmdArgs(rawArgs: [], direction: .right)).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["Window stacking into old top tab groups is disabled. Use edge split actions inside the active Tab instead."])
        assertEquals(root.layoutDescription, .h_tiles([
            .window(0),
            .window(1),
            .window(2),
        ]))
    }

    func testStackWithLeftFailsAndRefreshMigratesExistingLegacyTabGroup() async throws {
        Workspace.get(byName: name).rootTilingContainer.apply {
            TilingContainer(parent: $0, adaptiveWeight: 1, .v, .tabGroup, index: INDEX_BIND_LAST).apply {
                TestWindow.new(id: 0, parent: $0)
                assertEquals(TestWindow.new(id: 1, parent: $0).focusWindow(), true)
            }
        }

        let result = try await StackWithCommand(args: StackWithCmdArgs(rawArgs: [], direction: .left)).run(.defaultEnv, .emptyStdin)

        assertEquals(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["Window stacking into old top tab groups is disabled. Use edge split actions inside the active Tab instead."])
        XCTAssertEqual(Workspace.all.flatMap(\.allLeafWindowsRecursive).map(\.windowId).sorted(), [0, 1])
        XCTAssertFalse(Workspace.all.contains { workspaceContainsLegacyTabGroup($0) })
    }
}

@MainActor
private func workspaceContainsLegacyTabGroup(_ workspace: Workspace) -> Bool {
    containsLegacyTabGroup(workspace.rootTilingContainer)
}

@MainActor
private func containsLegacyTabGroup(_ node: TreeNode) -> Bool {
    if let container = node as? TilingContainer, container.layout == .tabGroup, container.children.count > 1 {
        return true
    }
    return node.children.contains(where: containsLegacyTabGroup)
}
