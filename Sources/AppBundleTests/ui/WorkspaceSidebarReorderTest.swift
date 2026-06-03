@testable import AppBundle
import Common
import CoreGraphics
import XCTest

@MainActor
final class WorkspaceSidebarReorderTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testReorderWorkspaceMovesItemBeforeTarget() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: third.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(first.name)
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            third.name,
            first.name,
            second.name,
        ])
    }

    func testReorderWorkspaceMovesItemAfterTarget() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: first.name,
            projectId: workspaceProjectDefaultId,
            placement: .after(second.name)
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            second.name,
            first.name,
            third.name,
        ])
    }

    func testReorderWorkspaceCanMoveToLastPosition() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: first.name,
            projectId: workspaceProjectDefaultId,
            placement: .after(third.name)
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            second.name,
            third.name,
            first.name,
        ])
    }

    func testReorderWorkspaceSameTargetIsNoop() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertFalse(reorderWorkspaceForSidebar(
            sourceWorkspaceName: second.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(second.name)
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            first.name,
            second.name,
            third.name,
        ])
    }

    func testReorderWorkspaceMissingTargetIsNoop() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertFalse(reorderWorkspaceForSidebar(
            sourceWorkspaceName: first.name,
            projectId: workspaceProjectDefaultId,
            placement: .after("missing")
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            first.name,
            second.name,
            third.name,
        ])
    }

    func testReorderWorkspaceRejectsCrossProjectTarget() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()
        let project = createWorkspaceProject()
        let otherProjectWorkspace = createBlankWorkspace(projectId: project.id, monitor: mainMonitor)

        XCTAssertFalse(reorderWorkspaceForSidebar(
            sourceWorkspaceName: first.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(otherProjectWorkspace.name)
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            first.name,
            second.name,
            third.name,
        ])
    }

    func testReorderWorkspaceChangesPresentationOrder() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: third.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(second.name)
        ))

        XCTAssertEqual(orderedWorkspacesForPresentation().map(\.name), [
            first.name,
            third.name,
            second.name,
        ])
    }

    func testReorderWorkspaceChangesPresentationOrderWhenProjectsDisabled() {
        config.enableProjects = false
        let (first, second, third) = makeOrderedDefaultWorkspaces()

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: third.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(second.name)
        ))

        XCTAssertEqual(orderedWorkspacesForPresentation().map(\.name), [
            first.name,
            third.name,
            second.name,
        ])
    }

    func testWorkspaceSidebarModelRefreshUsesReorderedWorkspaceOrder() async {
        config.workspaceSidebar.enabled = true
        let (first, second, third) = makeOrderedDefaultWorkspaces()
        await updateWorkspaceSidebarModel()
        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarWorkspaces.map(\.name), [
            first.name,
            second.name,
            third.name,
        ])

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: third.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(second.name)
        ))
        await updateWorkspaceSidebarModel()

        XCTAssertEqual(TrayMenuModel.shared.workspaceSidebarWorkspaces.map(\.name), [
            first.name,
            third.name,
            second.name,
        ])
    }

    func testReorderWorkspacePreservesHiddenWorkspaceRelativeOrder() {
        let first = focus.workspace
        let hidden = Workspace.get(byName: "hidden")
        let second = Workspace.get(byName: "second")
        let third = Workspace.get(byName: "third")
        setDefaultWorkspaceOrder([first, hidden, second, third])

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: third.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(second.name)
        ))

        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            first.name,
            hidden.name,
            third.name,
            second.name,
        ])
    }

    func testWorkspaceReorderTargetUsesVisibleFrameMidpoints() {
        let frames = [
            reorderFrame("first", minY: 10, height: 30),
            reorderFrame("second", minY: 50, height: 30),
            reorderFrame("third", minY: 90, height: 30),
        ]

        let beforeSecond = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: "third",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 12, y: 55),
            frames: frames
        )
        let afterSecond = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 12, y: 130),
            frames: frames
        )

        XCTAssertEqual(beforeSecond?.placement, .before("second"))
        XCTAssertEqual(afterSecond?.placement, .after("third"))
    }

    func testWorkspaceReorderTargetIgnoresSourceAndUnreorderableFrames() {
        let frames = [
            reorderFrame("first", minY: 10, height: 30),
            reorderFrame("second", minY: 50, height: 30, isReorderable: false),
        ]

        let target = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 12, y: 70),
            frames: frames
        )

        XCTAssertNil(target)
    }

    func testWorkspaceReorderEnablementRequiresExpandedIdleInteractiveRow() {
        XCTAssertTrue(workspaceSidebarWorkspaceReorderIsEnabled(
            isCompact: false,
            isSearchFiltering: false,
            isRenamingWorkspace: false,
            isPinnedActiveWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarWorkspaceReorderIsEnabled(
            isCompact: true,
            isSearchFiltering: false,
            isRenamingWorkspace: false,
            isPinnedActiveWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarWorkspaceReorderIsEnabled(
            isCompact: false,
            isSearchFiltering: true,
            isRenamingWorkspace: false,
            isPinnedActiveWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarWorkspaceReorderIsEnabled(
            isCompact: false,
            isSearchFiltering: false,
            isRenamingWorkspace: true,
            isPinnedActiveWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarWorkspaceReorderIsEnabled(
            isCompact: false,
            isSearchFiltering: false,
            isRenamingWorkspace: false,
            isPinnedActiveWorkspace: true,
            isInteractive: true
        ))
    }

    private func makeOrderedDefaultWorkspaces() -> (Workspace, Workspace, Workspace) {
        let first = focus.workspace
        let second = Workspace.get(byName: "second")
        let third = Workspace.get(byName: "third")
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

    private func reorderFrame(
        _ workspaceName: String,
        minY: CGFloat,
        height: CGFloat,
        projectId: WorkspaceProjectId = workspaceProjectDefaultId,
        isReorderable: Bool = true
    ) -> WorkspaceSidebarWorkspaceReorderFrame {
        WorkspaceSidebarWorkspaceReorderFrame(
            workspaceName: workspaceName,
            projectId: projectId,
            frame: CGRect(x: 0, y: minY, width: 200, height: height),
            isReorderable: isReorderable
        )
    }
}
