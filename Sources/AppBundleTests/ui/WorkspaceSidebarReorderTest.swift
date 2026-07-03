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

    func testReorderWorkspaceCanMoveFlatTabBeforeFolderTab() {
        let (first, second, third) = makeOrderedDefaultWorkspaces()
        let project = createWorkspaceProject()
        let otherProjectWorkspace = Workspace.all.first { $0.projectId == project.id }.orDie()

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: first.name,
            projectId: project.id,
            placement: .before(otherProjectWorkspace.name)
        ))

        XCTAssertEqual(first.projectId, project.id)
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            second.name,
            third.name,
        ])
        XCTAssertEqual(projectWorkspaces(projectId: project.id).map(\.name), [
            first.name,
            otherProjectWorkspace.name,
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

    func testReorderWorkspaceUsesFlatPresentationOrderAcrossLegacyProjects() {
        let first = focus.workspace
        first.assignProject(workspaceProjectDefaultId)
        let project = createWorkspaceProject()
        let second = Workspace.all.first { $0.projectId == project.id }.orDie()
        second.markAsAutomaticallyNamed()
        let third = Workspace.get(byName: "third")
        third.assignProject(workspaceProjectDefaultId)
        third.markAsAutomaticallyNamed()
        setProjectWorkspaceOrder(workspaceProjectDefaultId, [first, third])
        setProjectWorkspaceOrder(project.id, [second])

        XCTAssertEqual(orderedWorkspacesForPresentation().map(\.name), [
            first.name,
            third.name,
            second.name,
        ])

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: second.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(third.name)
        ))

        XCTAssertEqual(orderedWorkspacesForPresentation().map(\.name), [
            first.name,
            second.name,
            third.name,
        ])
    }

    func testWorkspaceSidebarModelRefreshUsesReorderedWorkspaceOrder() async {
        config.workspaceSidebar.enabled = true
        let (first, second, third) = makeOrderedDefaultWorkspaces()
        _ = TestWindow.new(id: 301, parent: first.rootTilingContainer)
        _ = TestWindow.new(id: 302, parent: second.rootTilingContainer)
        _ = TestWindow.new(id: 303, parent: third.rootTilingContainer)
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
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 12, y: 55),
            frames: frames
        )
        let afterSecond = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 12, y: 130),
            frames: frames
        )

        XCTAssertEqual(beforeSecond?.placement, .before("second"))
        XCTAssertEqual(afterSecond?.placement, .after("third"))
    }

    func testWorkspaceDragTargetUsesTopBottomForReorderAndIgnoresMiddleDrop() {
        let frames = [
            reorderFrame("first", minY: 10, height: 40),
            reorderFrame("second", minY: 60, height: 40),
        ]

        let leftMiddleTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 2, y: 78),
            workspaceFrames: frames
        )
        let rightMiddleTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 198, y: 78),
            workspaceFrames: frames
        )
        let topBandTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 100, y: 62),
            workspaceFrames: frames
        )
        let bottomBandTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 100, y: 98),
            workspaceFrames: frames
        )
        let centerTarget = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 100, y: 80),
            workspaceFrames: frames
        )

        XCTAssertNil(leftMiddleTarget)
        XCTAssertNil(rightMiddleTarget)
        XCTAssertEqual(topBandTarget, .reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: workspaceProjectDefaultId,
            targetWorkspaceName: "second",
            placement: .before("second")
        )))
        XCTAssertEqual(bottomBandTarget, .reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: workspaceProjectDefaultId,
            targetWorkspaceName: "second",
            placement: .after("second")
        )))
        XCTAssertNil(centerTarget)
    }

    func testWorkspaceDragTargetDoesNotCreateFolderFromHorizontalEdge() {
        let frames = [
            reorderFrame("first", minY: 10, height: 40),
            reorderFrame("second", minY: 60, height: 40),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 0.5, y: 80),
            workspaceFrames: frames
        )

        XCTAssertNil(target)
    }

    func testWorkspaceDragTargetUsesFolderHeaderForMovingTabIntoFolder() {
        let folderId = WorkspaceProjectId("project-folder")
        let workspaceFrames = [
            reorderFrame("flat", minY: 10, height: 40),
        ]
        let folderFrames = [
            folderFrame(folderId, minY: 54, height: 32),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "flat",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 20, y: 70),
            workspaceFrames: workspaceFrames,
            folderFrames: folderFrames
        )

        XCTAssertEqual(target, .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
            projectId: folderId,
            sourceWorkspaceName: "flat"
        )))
    }

    func testWorkspaceDragTargetUsesFolderBodyForMovingTabIntoFolder() {
        let folderId = WorkspaceProjectId("project-folder")
        let workspaceFrames = [
            reorderFrame("flat", minY: 10, height: 40),
            reorderFrame("folder-child", minY: 90, height: 40, projectId: folderId),
        ]
        let folderFrames = [
            folderFrame(folderId, minY: 54, height: 140),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "flat",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 20, y: 172),
            workspaceFrames: workspaceFrames,
            folderFrames: folderFrames
        )

        XCTAssertEqual(target, .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
            projectId: folderId,
            sourceWorkspaceName: "flat"
        )))
    }

    func testWorkspaceDragTargetPrefersFolderChildRowInsertionOverFolderHeader() {
        let folderId = WorkspaceProjectId("project-folder")
        let workspaceFrames = [
            reorderFrame("flat", minY: 10, height: 40),
            reorderFrame("folder-child", minY: 90, height: 40, projectId: folderId),
        ]
        let folderFrames = [
            folderFrame(folderId, minY: 54, height: 100),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "flat",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 20, y: 94),
            workspaceFrames: workspaceFrames,
            folderFrames: folderFrames
        )

        XCTAssertEqual(target, .reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: folderId,
            targetWorkspaceName: "folder-child",
            placement: .before("folder-child")
        )))
    }

    func testWorkspaceDragTargetPrefersFolderHeaderOverFlatRowWhenHeaderOverlaps() {
        let folderId = WorkspaceProjectId("project-folder")
        let workspaceFrames = [
            reorderFrame("flat", minY: 54, height: 40),
        ]
        let folderFrames = [
            folderFrame(folderId, minY: 54, height: 32),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "flat",
            sourceProjectId: workspaceProjectDefaultId,
            pointer: CGPoint(x: 20, y: 70),
            workspaceFrames: workspaceFrames,
            folderFrames: folderFrames
        )

        XCTAssertEqual(target, .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
            projectId: folderId,
            sourceWorkspaceName: "flat"
        )))
    }

    func testWorkspaceDragTargetMovesFolderChildOutOnFlatRowBand() {
        let folderId = WorkspaceProjectId("project-folder")
        let frames = [
            reorderFrame("flat", minY: 10, height: 40),
            reorderFrame("folder-child", minY: 60, height: 40, projectId: folderId),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "folder-child",
            sourceProjectId: folderId,
            pointer: CGPoint(x: 100, y: 12),
            workspaceFrames: frames
        )

        XCTAssertEqual(target, .reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: workspaceProjectDefaultId,
            targetWorkspaceName: "flat",
            placement: .before("flat")
        )))
    }

    func testWorkspaceDragTargetUsesDefaultDropAreaForMovingFolderChildOutWhenRootListIsEmpty() {
        let folderId = WorkspaceProjectId("project-folder")
        let frames = [
            reorderFrame("folder-child", minY: 60, height: 40, projectId: folderId),
        ]
        let folderFrames = [
            folderFrame(workspaceProjectDefaultId, minY: 10, height: 32),
            folderFrame(folderId, minY: 54, height: 120),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "folder-child",
            sourceProjectId: folderId,
            pointer: CGPoint(x: 100, y: 20),
            workspaceFrames: frames,
            folderFrames: folderFrames
        )

        XCTAssertEqual(target, .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "folder-child"
        )))
    }

    func testWorkspaceDragFinishActionAllowsMovingFolderChildOut() {
        let folderId = WorkspaceProjectId("project-folder")
        let target = WorkspaceSidebarWorkspaceDragTarget.reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: workspaceProjectDefaultId,
            targetWorkspaceName: "flat",
            placement: .before("flat")
        ))

        let action = workspaceSidebarWorkspaceDragFinishAction(
            sourceWorkspaceName: "folder-child",
            target: target
        )

        XCTAssertEqual(action, .reorderWorkspace(
            "folder-child",
            projectId: workspaceProjectDefaultId,
            placement: .before("flat")
        ))
        XCTAssertNotEqual(folderId, workspaceProjectDefaultId)
    }

    func testWorkspaceDragTargetMovesFolderChildOutOnFlatRowCenterDrop() {
        let folderId = WorkspaceProjectId("project-folder")
        let frames = [
            reorderFrame("flat", minY: 10, height: 40),
            reorderFrame("folder-child", minY: 60, height: 40, projectId: folderId),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "folder-child",
            sourceProjectId: folderId,
            pointer: CGPoint(x: 100, y: 30),
            workspaceFrames: frames
        )

        XCTAssertEqual(target, .reorder(WorkspaceSidebarWorkspaceReorderTarget(
            projectId: workspaceProjectDefaultId,
            targetWorkspaceName: "flat",
            placement: .after("flat")
        )))
    }

    func testWorkspaceDragTargetDoesNotCreateNestedFolderFromFolderChildCenterDrop() {
        let folderId = WorkspaceProjectId("project-folder")
        let frames = [
            reorderFrame("folder-child", minY: 10, height: 40, projectId: folderId),
            reorderFrame("folder-sibling", minY: 60, height: 40, projectId: folderId),
        ]

        let target = workspaceSidebarWorkspaceDragTarget(
            sourceWorkspaceName: "folder-child",
            sourceProjectId: folderId,
            pointer: CGPoint(x: 100, y: 80),
            workspaceFrames: frames
        )

        XCTAssertNil(target)
    }

    func testFolderReorderTargetUsesFolderFrames() {
        let sourceId = WorkspaceProjectId("project-source")
        let firstId = WorkspaceProjectId("project-first")
        let secondId = WorkspaceProjectId("project-second")
        let frames = [
            folderFrame(workspaceProjectDefaultId, minY: 0, height: 40),
            folderFrame(firstId, minY: 50, height: 50),
            folderFrame(sourceId, minY: 110, height: 50),
            folderFrame(secondId, minY: 170, height: 50),
        ]

        let beforeFirst = workspaceSidebarFolderReorderTarget(
            sourceProjectId: sourceId,
            pointer: CGPoint(x: 100, y: 54),
            frames: frames
        )
        let afterSecond = workspaceSidebarFolderReorderTarget(
            sourceProjectId: sourceId,
            pointer: CGPoint(x: 100, y: 218),
            frames: frames
        )
        let ignoresDefault = workspaceSidebarFolderReorderTarget(
            sourceProjectId: sourceId,
            pointer: CGPoint(x: 100, y: 20),
            frames: frames
        )

        XCTAssertEqual(beforeFirst, WorkspaceSidebarFolderReorderTarget(
            targetProjectId: firstId,
            placement: .before(firstId)
        ))
        XCTAssertEqual(afterSecond, WorkspaceSidebarFolderReorderTarget(
            targetProjectId: secondId,
            placement: .after(secondId)
        ))
        XCTAssertEqual(ignoresDefault, WorkspaceSidebarFolderReorderTarget(
            targetProjectId: firstId,
            placement: .before(firstId)
        ))
    }

    func testFolderListEntriesPreviewReorderAsPlaceholder() {
        let first = sidebarFolder("project-first", displayName: "First")
        let source = sidebarFolder("project-source", displayName: "Source")
        let second = sidebarFolder("project-second", displayName: "Second")

        let entries = workspaceSidebarFolderListEntries(
            sections: [first, source, second],
            sourceProjectId: source.id,
            target: WorkspaceSidebarFolderReorderTarget(
                targetProjectId: second.id,
                placement: .after(second.id)
            )
        )

        XCTAssertEqual(entries.map(\.testDescription), [
            "folder:project-first",
            "drag-anchor:project-source",
            "folder:project-second",
            "folder-placeholder:project-source",
        ])
    }

    func testFolderReorderIsDisabledForDefaultAndEditingStates() {
        XCTAssertTrue(workspaceSidebarFolderReorderIsEnabled(
            projectId: WorkspaceProjectId("project-folder"),
            isCompact: false,
            isSearchFiltering: false,
            isRenamingWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarFolderReorderIsEnabled(
            projectId: workspaceProjectDefaultId,
            isCompact: false,
            isSearchFiltering: false,
            isRenamingWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarFolderReorderIsEnabled(
            projectId: WorkspaceProjectId("project-folder"),
            isCompact: true,
            isSearchFiltering: false,
            isRenamingWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarFolderReorderIsEnabled(
            projectId: WorkspaceProjectId("project-folder"),
            isCompact: false,
            isSearchFiltering: true,
            isRenamingWorkspace: false,
            isInteractive: true
        ))
        XCTAssertFalse(workspaceSidebarFolderReorderIsEnabled(
            projectId: WorkspaceProjectId("project-folder"),
            isCompact: false,
            isSearchFiltering: false,
            isRenamingWorkspace: true,
            isInteractive: true
        ))
    }

    func testWorkspaceReorderPreviewPlacementReflectsConcreteLandingSlot() {
        let folderId = WorkspaceProjectId("project-folder")

        XCTAssertEqual(
            workspaceSidebarWorkspaceReorderPreviewPlacement(
                sourceWorkspaceName: "source",
                target: .reorder(WorkspaceSidebarWorkspaceReorderTarget(
                    projectId: workspaceProjectDefaultId,
                    targetWorkspaceName: "target",
                    placement: .before("target")
                ))
            ),
            .before("target")
        )
        XCTAssertEqual(
            workspaceSidebarWorkspaceReorderPreviewPlacement(
                sourceWorkspaceName: "source",
                target: .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
                    projectId: folderId,
                    sourceWorkspaceName: "source"
                ))
            ),
            .intoFolder(folderId)
        )
    }

    func testWorkspaceListEntriesPreviewReorderAsRealPlaceholder() {
        let first = sidebarWorkspace("first")
        let second = sidebarWorkspace("second")
        let third = sidebarWorkspace("third")

        let entries = workspaceSidebarWorkspaceListEntries(
            workspaces: [first, second, third],
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "third",
            sourceWorkspace: third,
            target: .reorder(WorkspaceSidebarWorkspaceReorderTarget(
                projectId: workspaceProjectDefaultId,
                targetWorkspaceName: "first",
                placement: .before("first")
            ))
        )

        XCTAssertEqual(entries.map(\.testDescription), [
            "placeholder:default:third",
            "workspace:first",
            "workspace:second",
            "drag-anchor:third",
        ])
    }

    func testWorkspaceListEntriesPreviewMoveIntoFolderAsIndentedPlaceholder() {
        let folderId = WorkspaceProjectId("project-folder")
        let flat = sidebarWorkspace("flat")
        let firstFolderTab = sidebarWorkspace("folder-first", projectId: folderId)
        let secondFolderTab = sidebarWorkspace("folder-second", projectId: folderId)

        let flatEntries = workspaceSidebarWorkspaceListEntries(
            workspaces: [flat],
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "flat",
            sourceWorkspace: flat,
            target: .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
                projectId: folderId,
                sourceWorkspaceName: "flat"
            ))
        )
        let folderEntries = workspaceSidebarWorkspaceListEntries(
            workspaces: [firstFolderTab, secondFolderTab],
            projectId: folderId,
            sourceWorkspaceName: "flat",
            sourceWorkspace: flat,
            target: .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
                projectId: folderId,
                sourceWorkspaceName: "flat"
            ))
        )

        XCTAssertEqual(flatEntries.map(\.testDescription), [
            "drag-anchor:flat",
        ])
        XCTAssertEqual(folderEntries.map(\.testDescription), [
            "workspace:folder-first",
            "workspace:folder-second",
            "placeholder:project-folder:flat",
        ])
    }

    func testWorkspaceListEntriesMarksRetainedSourceAsDragAnchorWhenMovingAcrossFolders() {
        let folderId = WorkspaceProjectId("project-folder")
        let flat = sidebarWorkspace("flat")
        let folderTab = sidebarWorkspace("folder-tab", projectId: folderId)

        let flatEntries = workspaceSidebarWorkspaceListEntries(
            workspaces: [flat],
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "flat",
            sourceWorkspace: flat,
            target: .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
                projectId: folderId,
                sourceWorkspaceName: "flat"
            ))
        )
        let folderEntries = workspaceSidebarWorkspaceListEntries(
            workspaces: [folderTab],
            projectId: folderId,
            sourceWorkspaceName: "flat",
            sourceWorkspace: flat,
            target: .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
                projectId: folderId,
                sourceWorkspaceName: "flat"
            ))
        )

        XCTAssertEqual(flatEntries.map(\.testDescription), [
            "drag-anchor:flat",
        ])
        XCTAssertEqual(folderEntries.map(\.testDescription), [
            "workspace:folder-tab",
            "placeholder:project-folder:flat",
        ])
    }

    func testWorkspaceListEntriesKeepsFolderChildDragSourceMountedWhenMovingOut() {
        let folderId = WorkspaceProjectId("project-folder")
        let flat = sidebarWorkspace("flat")
        let folderChild = sidebarWorkspace("folder-child", projectId: folderId)
        let folderSibling = sidebarWorkspace("folder-sibling", projectId: folderId)

        let flatEntries = workspaceSidebarWorkspaceListEntries(
            workspaces: [flat],
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "folder-child",
            sourceWorkspace: folderChild,
            target: .reorder(WorkspaceSidebarWorkspaceReorderTarget(
                projectId: workspaceProjectDefaultId,
                targetWorkspaceName: "flat",
                placement: .before("flat")
            ))
        )
        let folderEntries = workspaceSidebarWorkspaceListEntries(
            workspaces: [folderChild, folderSibling],
            projectId: folderId,
            sourceWorkspaceName: "folder-child",
            sourceWorkspace: folderChild,
            target: .reorder(WorkspaceSidebarWorkspaceReorderTarget(
                projectId: workspaceProjectDefaultId,
                targetWorkspaceName: "flat",
                placement: .before("flat")
            ))
        )

        XCTAssertEqual(flatEntries.map(\.testDescription), [
            "placeholder:default:folder-child",
            "workspace:flat",
        ])
        XCTAssertEqual(folderEntries.map(\.testDescription), [
            "drag-anchor:folder-child",
            "workspace:folder-sibling",
        ])
    }

    func testWorkspaceListEntriesPreviewMoveOutToEmptyDefaultList() {
        let folderId = WorkspaceProjectId("project-folder")
        let folderChild = sidebarWorkspace("folder-child", projectId: folderId)

        let entries = workspaceSidebarWorkspaceListEntries(
            workspaces: [],
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "folder-child",
            sourceWorkspace: folderChild,
            target: .moveToFolder(WorkspaceSidebarWorkspaceFolderTarget(
                projectId: workspaceProjectDefaultId,
                sourceWorkspaceName: "folder-child"
            ))
        )

        XCTAssertEqual(entries.map(\.testDescription), [
            "placeholder:default:folder-child",
        ])
    }

    func testWorkspaceListEntriesKeepsSameListSourceMountedDuringReorderPreview() {
        let first = sidebarWorkspace("first")
        let second = sidebarWorkspace("second")
        let third = sidebarWorkspace("third")

        let entries = workspaceSidebarWorkspaceListEntries(
            workspaces: [first, second, third],
            projectId: workspaceProjectDefaultId,
            sourceWorkspaceName: "first",
            sourceWorkspace: first,
            target: .reorder(WorkspaceSidebarWorkspaceReorderTarget(
                projectId: workspaceProjectDefaultId,
                targetWorkspaceName: "third",
                placement: .after("third")
            ))
        )

        XCTAssertEqual(entries.map(\.testDescription), [
            "drag-anchor:first",
            "workspace:second",
            "workspace:third",
            "placeholder:default:first",
        ])
    }

    func testWorkspaceSourcePreviewUsesSingleWindowMetadata() {
        let window = WorkspaceSidebarWindowViewModel(
            windowId: 42,
            workspaceName: "research",
            appName: "Arc",
            appBundleId: "company.thebrowser.Browser",
            appBundlePath: "/Applications/Arc.app",
            title: "Design docs",
            isFocused: false
        )
        let workspace = WorkspaceSidebarWorkspaceViewModel(
            name: "research",
            projectId: workspaceProjectDefaultId,
            displayName: "Design docs",
            sidebarLabel: "",
            isGeneratedName: true,
            tabSummary: WorkspaceSidebarTabSummaryViewModel(
                title: "Design docs",
                subtitle: "Arc",
                appBundleId: "fallback.bundle",
                appBundlePath: "/Applications/Fallback.app",
                windowCount: 1,
                isEmpty: false
            ),
            monitorScopeId: workspaceSidebarDefaultScopeId,
            monitorName: nil,
            isFocused: false,
            isVisible: true,
            items: [WorkspaceSidebarItemViewModel(kind: .window(window))]
        )

        let preview = workspaceSidebarWorkspaceSourcePreview(workspace)

        XCTAssertEqual(preview.sourceWindowId, 42)
        XCTAssertEqual(preview.label, "Design docs")
        XCTAssertEqual(preview.appName, "Arc")
        XCTAssertEqual(preview.appBundleIdentifier, "company.thebrowser.Browser")
        XCTAssertEqual(preview.appBundlePath, "/Applications/Arc.app")
        XCTAssertFalse(preview.isTabGroup)
        XCTAssertEqual(preview.windowCount, 1)
        XCTAssertTrue(preview.tabItems.isEmpty)
    }

    func testWorkspaceSourcePreviewCarriesGroupedTabItemsForCursorStack() {
        let arc = WorkspaceSidebarWindowViewModel(
            windowId: 201,
            workspaceName: "research",
            appName: "Arc",
            appBundleId: "company.thebrowser.Browser",
            appBundlePath: "/Applications/Arc.app",
            title: "Browser notes",
            isFocused: false
        )
        let notes = WorkspaceSidebarWindowViewModel(
            windowId: 202,
            workspaceName: "research",
            appName: "Notes",
            appBundleId: "com.apple.Notes",
            appBundlePath: "/System/Applications/Notes.app",
            title: "Planning",
            isFocused: false
        )
        let group = WorkspaceSidebarTabGroupViewModel(
            representativeWindowId: arc.windowId,
            workspaceName: "research",
            title: "Research",
            windowCount: 2,
            isFocused: false,
            tabs: [arc, notes]
        )
        let workspace = WorkspaceSidebarWorkspaceViewModel(
            name: "research",
            projectId: workspaceProjectDefaultId,
            displayName: "Research",
            sidebarLabel: "Research",
            isGeneratedName: false,
            tabSummary: WorkspaceSidebarTabSummaryViewModel(
                title: "Research",
                subtitle: nil,
                appBundleId: "fallback.bundle",
                appBundlePath: "/Applications/Fallback.app",
                windowCount: 2,
                isEmpty: false
            ),
            monitorScopeId: workspaceSidebarDefaultScopeId,
            monitorName: nil,
            isFocused: false,
            isVisible: true,
            items: [WorkspaceSidebarItemViewModel(kind: .tabGroup(group))]
        )

        let preview = workspaceSidebarWorkspaceSourcePreview(workspace)

        XCTAssertEqual(preview.sourceWindowId, 201)
        XCTAssertEqual(preview.label, "Research")
        XCTAssertEqual(preview.appName, "Arc")
        XCTAssertTrue(preview.isTabGroup)
        XCTAssertEqual(preview.windowCount, 2)
        XCTAssertEqual(preview.tabItems.map(\.title), ["Browser notes", "Planning"])
        XCTAssertEqual(preview.tabItems.map(\.appBundleIdentifier), [
            "company.thebrowser.Browser",
            "com.apple.Notes",
        ])
    }

    func testCreateSidebarFolderFromWorkspacesCreatesAutoNamedEditableFolder() {
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
        setDefaultWorkspaceOrder([target, source])

        XCTAssertTrue(createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: source.name,
            targetWorkspaceName: target.name
        ))

        XCTAssertNotNil(Workspace.existing(byName: source.name))
        XCTAssertNotNil(Workspace.existing(byName: target.name))
        XCTAssertEqual(source.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .window(2),
        ]))
        XCTAssertEqual(target.rootTilingContainer.layoutDescription, .h_tiles([
            .window(3),
        ]))
        XCTAssertEqual(source.projectId, target.projectId)
        XCTAssertNotEqual(source.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(workspaceProjects().first { $0.id == source.projectId }?.name, "Folder 1")
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(source.projectId))
        XCTAssertEqual(projectWorkspaces(projectId: source.projectId).map(\.name), [
            target.name,
            source.name,
        ])
        XCTAssertEqual(focus.workspace, target)
    }

    func testCreateSidebarFolderFromWorkspaceMovesActiveTabIntoVisibleFolder() {
        let workspace = Workspace.get(byName: "source")
        workspace.markAsAutomaticallyNamed()
        workspace.assignProject(workspaceProjectDefaultId)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }
        XCTAssertTrue(workspace.focusWorkspace())

        let folderId = createSidebarFolderFromWorkspace(workspace.name)

        XCTAssertNotNil(folderId)
        XCTAssertEqual(workspace.projectId, folderId)
        XCTAssertNotEqual(workspace.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(workspaceProjects().first { $0.id == folderId }?.name, "Folder 1")
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(workspace.projectId))
        XCTAssertEqual(projectWorkspaces(projectId: workspace.projectId).map(\.name), [workspace.name])
        XCTAssertEqual(focus.workspace, workspace)
    }

    func testCreateSidebarFolderFromWorkspaceInsertsFolderBeforeExistingFolders() {
        let first = createWorkspaceProjectWithWindow(windowId: 31)
        let second = createWorkspaceProjectWithWindow(windowId: 32)
        let workspace = Workspace.get(byName: "source")
        workspace.markAsAutomaticallyNamed()
        workspace.assignProject(workspaceProjectDefaultId)
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: 33, parent: $0)
        }

        let folderId = createSidebarFolderFromWorkspace(workspace.name)

        guard let folderId else {
            XCTFail("Expected sidebar folder creation to succeed")
            return
        }
        XCTAssertEqual(workspaceProjects().map(\.id), [
            workspaceProjectDefaultId,
            folderId,
            first.id,
            second.id,
        ])
    }

    func testCreateSidebarFolderFromWorkspaceRejectsEmptyTab() {
        let workspace = Workspace.get(byName: "empty")
        workspace.markAsAutomaticallyNamed()
        workspace.assignProject(workspaceProjectDefaultId)
        XCTAssertTrue(workspace.focusWorkspace())

        XCTAssertNil(createSidebarFolderFromWorkspace(workspace.name))
        XCTAssertEqual(workspace.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(workspaceProjects().map(\.id), [workspaceProjectDefaultId])
    }

    func testCreateSidebarFolderFromWorkspacesMovesFlatTabsAcrossLegacyProjects() {
        let project = createWorkspaceProject()
        let source = Workspace.get(byName: "source")
        source.markAsAutomaticallyNamed()
        source.assignProject(project.id)
        source.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }
        let target = Workspace.get(byName: "target")
        target.markAsAutomaticallyNamed()
        target.assignProject(workspaceProjectDefaultId)
        target.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        XCTAssertTrue(createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: source.name,
            targetWorkspaceName: target.name
        ))

        XCTAssertNotNil(Workspace.existing(byName: source.name))
        XCTAssertEqual(source.projectId, target.projectId)
        XCTAssertNotEqual(source.projectId, project.id)
        XCTAssertNotEqual(source.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(source.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
        ]))
        XCTAssertEqual(target.rootTilingContainer.layoutDescription, .h_tiles([
            .window(2),
        ]))
    }

    func testMoveWorkspaceToSidebarFolderMovesTabWithoutComposingLayouts() {
        let folder = createWorkspaceProject()
        let folderWorkspace = Workspace.all.first { $0.projectId == folder.id }.orDie()
        folderWorkspace.markAsAutomaticallyNamed()
        folderWorkspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }

        let source = Workspace.get(byName: "source")
        source.markAsAutomaticallyNamed()
        source.assignProject(workspaceProjectDefaultId)
        source.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }

        XCTAssertTrue(moveWorkspaceToSidebarFolder(source.name, projectId: folder.id))

        XCTAssertEqual(source.projectId, folder.id)
        XCTAssertEqual(source.rootTilingContainer.layoutDescription, .h_tiles([
            .window(2),
            .window(3),
        ]))
        XCTAssertEqual(folderWorkspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
        ]))
        XCTAssertEqual(projectWorkspaces(projectId: folder.id).map(\.name), [
            folderWorkspace.name,
            source.name,
        ])
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(folder.id))
    }

    func testMoveWorkspaceToSidebarDefaultListMovesFolderChildOut() {
        let folder = createWorkspaceProject()
        let folderWorkspace = Workspace.all.first { $0.projectId == folder.id }.orDie()
        folderWorkspace.markAsAutomaticallyNamed()
        folderWorkspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }

        let folderChild = Workspace.get(byName: "folder-child")
        folderChild.markAsAutomaticallyNamed()
        folderChild.assignProject(folder.id)
        folderChild.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        let flat = Workspace.get(byName: "flat")
        flat.markAsAutomaticallyNamed()
        flat.assignProject(workspaceProjectDefaultId)
        flat.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
        }
        setProjectWorkspaceOrder(workspaceProjectDefaultId, [flat])
        setProjectWorkspaceOrder(folder.id, [folderWorkspace, folderChild])

        XCTAssertTrue(moveWorkspaceToSidebarFolder(folderChild.name, projectId: workspaceProjectDefaultId))

        XCTAssertEqual(folderChild.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            flat.name,
            folderChild.name,
        ])
        XCTAssertEqual(projectWorkspaces(projectId: folder.id).map(\.name), [
            folderWorkspace.name,
        ])
    }

    func testMoveWorkspaceToSidebarDefaultListIgnoresOtherDisplayDefaultTab() {
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

        let folder = createWorkspaceProject()
        let folderWorkspace = Workspace.all.first { $0.projectId == folder.id }.orDie()
        folderWorkspace.markAsAutomaticallyNamed()

        let folderChild = Workspace.get(byName: "folder-child")
        folderChild.markAsAutomaticallyNamed()
        folderChild.assignProject(folder.id)
        folderChild.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        let otherDisplayFlatTab = Workspace.get(byName: "other-display-flat")
        otherDisplayFlatTab.markAsAutomaticallyNamed()
        otherDisplayFlatTab.assignProject(workspaceProjectDefaultId)
        otherDisplayFlatTab.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
        }

        setProjectWorkspaceOrder(workspaceProjectDefaultId, [otherDisplayFlatTab])
        setProjectWorkspaceOrder(folder.id, [folderWorkspace, folderChild])
        XCTAssertTrue(main.setActiveWorkspace(folderChild))
        XCTAssertTrue(secondary.setActiveWorkspace(otherDisplayFlatTab))
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).compactMap(\.visibleMonitor).first?.rect.topLeftCorner, secondary.rect.topLeftCorner)

        XCTAssertTrue(moveWorkspaceToSidebarFolder(folderChild.name, projectId: workspaceProjectDefaultId))

        XCTAssertEqual(folderChild.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            otherDisplayFlatTab.name,
            folderChild.name,
        ])
    }

    func testReorderWorkspaceCanMoveFolderChildOutToFlatTabList() {
        let folder = createWorkspaceProject()
        let folderWorkspace = Workspace.all.first { $0.projectId == folder.id }.orDie()
        folderWorkspace.markAsAutomaticallyNamed()
        folderWorkspace.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }

        let folderChild = Workspace.get(byName: "folder-child")
        folderChild.markAsAutomaticallyNamed()
        folderChild.assignProject(folder.id)
        folderChild.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        let flat = Workspace.get(byName: "flat")
        flat.markAsAutomaticallyNamed()
        flat.assignProject(workspaceProjectDefaultId)
        flat.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
        }
        setProjectWorkspaceOrder(workspaceProjectDefaultId, [flat])
        setProjectWorkspaceOrder(folder.id, [folderWorkspace, folderChild])

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: folderChild.name,
            projectId: workspaceProjectDefaultId,
            placement: .before(flat.name)
        ))

        XCTAssertEqual(folderChild.projectId, workspaceProjectDefaultId)
        XCTAssertEqual(projectWorkspaces(projectId: workspaceProjectDefaultId).map(\.name), [
            folderChild.name,
            flat.name,
        ])
        XCTAssertEqual(projectWorkspaces(projectId: folder.id).map(\.name), [
            folderWorkspace.name,
        ])
    }

    func testReorderWorkspaceCanMoveFlatTabIntoFolderAtSpecificPosition() {
        let folder = createWorkspaceProject()
        let firstFolderTab = Workspace.all.first { $0.projectId == folder.id }.orDie()
        firstFolderTab.markAsAutomaticallyNamed()
        firstFolderTab.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }

        let secondFolderTab = Workspace.get(byName: "second-folder")
        secondFolderTab.markAsAutomaticallyNamed()
        secondFolderTab.assignProject(folder.id)
        secondFolderTab.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        let flat = Workspace.get(byName: "flat")
        flat.markAsAutomaticallyNamed()
        flat.assignProject(workspaceProjectDefaultId)
        flat.rootTilingContainer.apply {
            TestWindow.new(id: 3, parent: $0)
        }
        setProjectWorkspaceOrder(workspaceProjectDefaultId, [flat])
        setProjectWorkspaceOrder(folder.id, [firstFolderTab, secondFolderTab])
        setWorkspaceSidebarFolderExpanded(folder.id, isExpanded: false)

        XCTAssertTrue(reorderWorkspaceForSidebar(
            sourceWorkspaceName: flat.name,
            projectId: folder.id,
            placement: .after(firstFolderTab.name)
        ))

        XCTAssertEqual(flat.projectId, folder.id)
        XCTAssertEqual(projectWorkspaces(projectId: folder.id).map(\.name), [
            firstFolderTab.name,
            flat.name,
            secondFolderTab.name,
        ])
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(folder.id))
    }

    func testReorderWorkspaceProjectForSidebarMovesFolderBeforeTargetFolder() {
        let first = createWorkspaceProjectWithWindow(windowId: 401)
        let second = createWorkspaceProjectWithWindow(windowId: 402)
        let third = createWorkspaceProjectWithWindow(windowId: 403)

        XCTAssertTrue(reorderWorkspaceProjectForSidebar(
            sourceProjectId: third.id,
            placement: .before(first.id)
        ))

        XCTAssertEqual(workspaceProjects().map(\.id), [
            workspaceProjectDefaultId,
            third.id,
            first.id,
            second.id,
        ])
    }

    func testReorderWorkspaceProjectForSidebarRejectsDefaultFolder() {
        let folder = createWorkspaceProjectWithWindow(windowId: 411)

        XCTAssertFalse(reorderWorkspaceProjectForSidebar(
            sourceProjectId: folder.id,
            placement: .before(workspaceProjectDefaultId)
        ))
        XCTAssertFalse(reorderWorkspaceProjectForSidebar(
            sourceProjectId: workspaceProjectDefaultId,
            placement: .before(folder.id)
        ))
    }

    func testMergeWorkspaceIntoActiveViewFromSidebarUsesPointerMonitorActiveTabAndPosition() {
        let source = Workspace.get(byName: "source")
        source.markAsAutomaticallyNamed()
        source.assignProject(workspaceProjectDefaultId)
        source.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }
        let target = Workspace.get(byName: "target")
        target.markAsAutomaticallyNamed()
        target.assignProject(workspaceProjectDefaultId)
        target.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }
        XCTAssertTrue(mainMonitor.setActiveWorkspace(target))
        XCTAssertTrue(target.focusWorkspace())

        XCTAssertTrue(mergeWorkspaceIntoActiveViewFromSidebar(
            sourceWorkspaceName: source.name,
            pointer: CGPoint(
                x: mainMonitor.rect.topLeftX + (mainMonitor.rect.width / 2),
                y: mainMonitor.rect.topLeftY + (mainMonitor.rect.height / 2)
            ),
            position: .left
        ))

        XCTAssertNil(Workspace.existing(byName: source.name))
        XCTAssertEqual(target.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .window(2),
        ]))
    }

    func testMergeWorkspaceIntoActiveViewCombinesTabsDirectionallyAndRemovesSource() {
        let source = Workspace.get(byName: "source")
        source.markAsAutomaticallyNamed()
        source.assignProject(workspaceProjectDefaultId)
        source.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
        }
        let target = Workspace.get(byName: "target")
        target.markAsAutomaticallyNamed()
        target.assignProject(workspaceProjectDefaultId)
        target.rootTilingContainer.apply {
            TestWindow.new(id: 2, parent: $0)
        }

        XCTAssertTrue(mergeWorkspaceTab(
            sourceWorkspaceName: source.name,
            targetWorkspaceName: target.name,
            position: .right
        ))

        XCTAssertNil(Workspace.existing(byName: source.name))
        XCTAssertEqual(target.rootTilingContainer.layoutDescription, .h_tiles([
            .window(2),
            .window(1),
        ]))
    }

    func testCreateSidebarFolderFromWorkspacesRejectsVisibleTabsOnDifferentDisplays() {
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

        XCTAssertFalse(createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: source.name,
            targetWorkspaceName: target.name
        ))
    }

    func testWorkspaceReorderTargetIgnoresSourceAndUnreorderableFrames() {
        let frames = [
            reorderFrame("first", minY: 10, height: 30),
            reorderFrame("second", minY: 50, height: 30, isReorderable: false),
        ]

        let target = workspaceSidebarWorkspaceReorderTarget(
            sourceWorkspaceName: "first",
            sourceProjectId: workspaceProjectDefaultId,
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

    func testDraggingTabKeepsSelectedRowTreatment() {
        XCTAssertTrue(workspaceSidebarHeaderRowIsHighlighted(
            isSelected: false,
            isReorderSource: true
        ))
        XCTAssertTrue(workspaceSidebarHeaderRowIsHighlighted(
            isSelected: true,
            isReorderSource: false
        ))
        XCTAssertFalse(workspaceSidebarHeaderRowIsHighlighted(
            isSelected: false,
            isReorderSource: false
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
        setProjectWorkspaceOrder(workspaceProjectDefaultId, workspaces)
    }

    private func setProjectWorkspaceOrder(_ projectId: WorkspaceProjectId, _ workspaces: [Workspace]) {
        var project = winMuxWorkspaceState.projectsById[projectId].orDie()
        project.workspaceOrder = workspaces.map(\.id)
        winMuxWorkspaceState.projectsById[projectId] = project
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

    private func folderFrame(
        _ projectId: WorkspaceProjectId,
        minY: CGFloat,
        height: CGFloat,
        isDropTarget: Bool = true
    ) -> WorkspaceSidebarFolderReorderFrame {
        WorkspaceSidebarFolderReorderFrame(
            projectId: projectId,
            frame: CGRect(x: 0, y: minY, width: 200, height: height),
            isDropTarget: isDropTarget
        )
    }

    private func sidebarWorkspace(
        _ name: String,
        projectId: WorkspaceProjectId = workspaceProjectDefaultId
    ) -> WorkspaceSidebarWorkspaceViewModel {
        WorkspaceSidebarWorkspaceViewModel(
            name: name,
            projectId: projectId,
            displayName: name,
            sidebarLabel: name,
            isGeneratedName: false,
            tabSummary: WorkspaceSidebarTabSummaryViewModel(
                title: name,
                subtitle: nil,
                appBundleId: nil,
                appBundlePath: nil,
                windowCount: 1,
                isEmpty: false
            ),
            monitorScopeId: workspaceSidebarDefaultScopeId,
            monitorName: nil,
            isFocused: false,
            isVisible: false,
            items: []
        )
    }

    private func sidebarFolder(
        _ rawProjectId: String,
        displayName: String
    ) -> WorkspaceSidebarFolderSection {
        let projectId = WorkspaceProjectId(rawProjectId)
        return WorkspaceSidebarFolderSection(
            project: WorkspaceSidebarProjectViewModel(
                id: projectId,
                displayName: displayName,
                colorHex: nil
            ),
            workspaces: [sidebarWorkspace("\(rawProjectId)-workspace", projectId: projectId)]
        )
    }

    private func createWorkspaceProjectWithWindow(windowId: UInt32) -> WorkspaceProject {
        let project = createWorkspaceProject()
        let workspace = Workspace.all.first { $0.projectId == project.id }.orDie()
        workspace.markAsAutomaticallyNamed()
        workspace.rootTilingContainer.apply {
            TestWindow.new(id: windowId, parent: $0)
        }
        return project
    }
}

private extension WorkspaceSidebarWorkspaceListEntry {
    var testDescription: String {
        switch self {
            case .workspace(let workspace, let isDragAnchor):
                return "\(isDragAnchor ? "drag-anchor" : "workspace"):\(workspace.name)"
            case .placeholder(let workspace, let projectId):
                return "placeholder:\(projectId.rawValue):\(workspace.name)"
        }
    }
}

private extension WorkspaceSidebarFolderListEntry {
    var testDescription: String {
        switch self {
            case .folder(let section, let isDragAnchor):
                return "\(isDragAnchor ? "drag-anchor" : "folder"):\(section.id.rawValue)"
            case .placeholder(let section):
                return "folder-placeholder:\(section.id.rawValue)"
        }
    }
}
