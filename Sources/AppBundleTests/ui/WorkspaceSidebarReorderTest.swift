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

    func testWorkspaceDragTargetUsesEdgesForDirectionalTabMerge() {
        let frames = [
            reorderFrame("first", minY: 10, height: 40),
            reorderFrame("second", minY: 60, height: 40),
        ]

        let leftTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 2, y: 78),
            frames: frames
        )
        let rightTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 198, y: 78),
            frames: frames
        )
        let aboveTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 100, y: 62),
            frames: frames
        )
        let belowTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 100, y: 98),
            frames: frames
        )

        XCTAssertEqual(leftTarget, .merge(WorkspaceSidebarWorkspaceMergeTarget(
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "first",
            targetWorkspaceName: "second",
            position: .left
        )))
        XCTAssertEqual(rightTarget, .merge(WorkspaceSidebarWorkspaceMergeTarget(
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "first",
            targetWorkspaceName: "second",
            position: .right
        )))
        XCTAssertEqual(aboveTarget, .merge(WorkspaceSidebarWorkspaceMergeTarget(
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "first",
            targetWorkspaceName: "second",
            position: .above
        )))
        XCTAssertEqual(belowTarget, .merge(WorkspaceSidebarWorkspaceMergeTarget(
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "first",
            targetWorkspaceName: "second",
            position: .below
        )))
    }

    func testWorkspaceDragTargetCenterDoesNotMergeTabs() {
        let frames = [
            reorderFrame("first", minY: 10, height: 40),
            reorderFrame("second", minY: 60, height: 40),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            projectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 100, y: 80),
            frames: frames
        )

        XCTAssertEqual(target, .reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: workspaceProjectDefaultId,
            targetWorkspaceName: "second",
            placement: .before("second")
        )))
    }

    func testMergeWorkspaceTabCombinesComposedLayoutsAndRemovesSourceTab() {
        let source = Workspace.get(byName: "source")
        source.markAsAutomaticallyNamed()
        source.assignProject(workspaceProjectDefaultId)
        source.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        let target = Workspace.get(byName: "target")
        target.markAsAutomaticallyNamed()
        target.assignProject(workspaceProjectDefaultId)
        target.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
        }
        XCTAssertTrue(target.focusWorkspace())

        XCTAssertTrue(mergeWorkspaceTab(
            sourceWorkspaceName: source.name,
            targetWorkspaceName: target.name,
            position: .left
        ))

        XCTAssertNil(Workspace.existing(byName: source.name))
        XCTAssertEqual(target.rootTilingContainer.layoutDescription, .h_tiles([
            .h_tiles([
                .window(1),
                .window(2),
            ]),
            .window(3),
        ]))
        XCTAssertEqual(focus.workspace, target)
    }

    func testMergeWorkspaceTabRejectsVisibleTabsOnDifferentDisplays() {
        let main = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Main",
            rect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 0, topLeftY: 0, width: 1920, height: 1080),
            isMain: true,
        )
        let secondary = WorkspaceSidebarDragTestMonitor(
            monitorAppKitNsScreenScreensId: 2,
            name: "Secondary",
            rect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            visibleRect: Rect(topLeftX: 1920, topLeftY: 0, width: 1920, height: 1080),
            isMain: false,
        )
        setMonitorsForTests([main, secondary])
        defer { setMonitorsForTests(nil) }

        let source = Workspace.get(byName: "source")
        let target = Workspace.get(byName: "target")
        XCTAssertTrue(main.setActiveWorkspace(source))
        XCTAssertTrue(secondary.setActiveWorkspace(target))

        XCTAssertFalse(mergeWorkspaceTab(
            sourceWorkspaceName: source.name,
            targetWorkspaceName: target.name,
            position: .right
        ))
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
