@testable import AppBundle
import XCTest

@MainActor
final class WorkspaceTabMigrationTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testRootTabGroupChildrenBecomeSeparateWorkspaceTabs() {
        let workspace = Workspace.get(byName: "1")
        workspace.markAsAutomaticallyNamed()
        let root = workspace.rootTilingContainer
        root.layout = .tabGroup
        let first = TestWindow.new(id: 1, parent: root)
        let second = TestWindow.new(id: 2, parent: root)
        second.markAsMostRecentChild()
        XCTAssertTrue(workspace.focusWorkspace())

        Workspace.reconcileWorkspaceState()

        let workspaces = orderedWorkspacesForPresentation()
            .filter { !$0.isArchived && workspaceHasSidebarVisibleWindows($0) }
        XCTAssertEqual(workspaces.count, 2)
        XCTAssertTrue(workspace.rootTilingContainer.children.contains(second))
        XCTAssertEqual(workspace.rootTilingContainer.layout, .tiles)
        XCTAssertTrue(second.nodeWorkspace === workspace)
        XCTAssertTrue(first.nodeWorkspace !== workspace)
        XCTAssertEqual(first.nodeWorkspace?.rootTilingContainer.children, [first])
        XCTAssertFalse(Workspace.all.contains { $0.rootTilingContainer.layout == .tabGroup && $0.rootTilingContainer.children.count > 1 })
    }

    func testNestedTabGroupChildComposedLayoutIsPreservedAsWorkspaceTab() {
        let workspace = Workspace.get(byName: "1")
        workspace.markAsAutomaticallyNamed()
        let root = workspace.rootTilingContainer
        let leading = TestWindow.new(id: 1, parent: root)
        let tabGroup = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: INDEX_BIND_LAST)
        let composed = TilingContainer(parent: tabGroup, adaptiveWeight: WEIGHT_AUTO, .h, .tiles, index: INDEX_BIND_LAST)
        let splitA = TestWindow.new(id: 2, parent: composed)
        let splitB = TestWindow.new(id: 3, parent: composed)
        let active = TestWindow.new(id: 4, parent: tabGroup)
        active.markAsMostRecentChild()
        XCTAssertTrue(workspace.focusWorkspace())

        Workspace.reconcileWorkspaceState()

        XCTAssertEqual(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .window(4),
        ]))
        XCTAssertTrue(leading.nodeWorkspace === workspace)
        XCTAssertTrue(active.nodeWorkspace === workspace)
        XCTAssertTrue(splitA.nodeWorkspace === splitB.nodeWorkspace)
        XCTAssertTrue(splitA.nodeWorkspace !== workspace)
        XCTAssertEqual(splitA.nodeWorkspace?.rootTilingContainer.layoutDescription, .h_tiles([
            .h_tiles([
                .window(2),
                .window(3),
            ]),
        ]))
    }

    func testProjectsAreHardDisabledForWorkspaceTabs() {
        config.enableProjects = true

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertEqual(buildWorkspaceSidebarProjectViewModels().map(\.id), [workspaceProjectDefaultId])
    }
}
