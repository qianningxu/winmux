@testable import AppBundle
import XCTest

@MainActor
final class WorkspaceSidebarProjectsDisabledTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testProjectViewModelsBackFoldersWhenProjectsDisabled() {
        let first = Workspace.get(byName: "1")
        first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 1, parent: first.rootTilingContainer)
        let second = Workspace.get(byName: "2")
        second.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 2, parent: second.rootTilingContainer)
        config.enableProjects = false

        XCTAssertTrue(createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: second.name,
            targetWorkspaceName: first.name
        ))
        let folderId = first.projectId

        XCTAssertEqual(buildWorkspaceSidebarProjectViewModels().map(\.id), [
            workspaceProjectDefaultId,
            folderId,
        ])
    }

    func testProjectsDisabledTabListFlattensFoldersButKeepsMonitorScope() {
        let mainScope = "monitor:0.0,0.0"
        let secondaryScope = "monitor:1440.0,0.0"
        let folderId = WorkspaceProjectId("project-folder")
        let workspaces = [
            sidebarWorkspace("main-default", projectId: workspaceProjectDefaultId, monitorScopeId: mainScope),
            sidebarWorkspace("main-foldered", projectId: folderId, monitorScopeId: mainScope),
            sidebarWorkspace("secondary-default", projectId: workspaceProjectDefaultId, monitorScopeId: secondaryScope),
            sidebarWorkspace("secondary-foldered", projectId: folderId, monitorScopeId: secondaryScope),
        ]

        let grouped = workspaceSidebarVisibleWorkspacesByProject(
            workspaces: workspaces,
            selectedScopeId: workspaceSidebarDefaultScopeId,
            focusedMonitorScopeId: mainScope,
            targetMonitorScopeId: secondaryScope,
            projectsEnabled: false,
        )

        XCTAssertEqual(grouped.keys.sorted(by: { $0.rawValue < $1.rawValue }), [workspaceProjectDefaultId])
        XCTAssertEqual(grouped[workspaceProjectDefaultId]?.map(\.name), [
            "secondary-default",
            "secondary-foldered",
        ])
    }

    func testSidebarModelBuildsFlatMonitorLocalTabListWhenProjectsDisabled() async {
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

        let mainDefault = Workspace.get(byName: "main-default")
        mainDefault.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 21, parent: mainDefault.rootTilingContainer)
        let secondaryDefault = Workspace.get(byName: "secondary-default")
        secondaryDefault.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 22, parent: secondaryDefault.rootTilingContainer)
        let secondaryFoldered = Workspace.get(byName: "secondary-foldered")
        secondaryFoldered.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 23, parent: secondaryFoldered.rootTilingContainer)

        let folder = createWorkspaceProject()
        secondaryFoldered.assignProject(folder.id)
        secondaryFoldered.seedMonitorIfNeeded(secondary)
        XCTAssertTrue(main.setActiveWorkspace(mainDefault))
        XCTAssertTrue(secondary.setActiveWorkspace(secondaryDefault))
        XCTAssertTrue(mainDefault.focusWorkspace())

        let state = await buildWorkspaceSidebarModelState()
        let secondaryScope = workspaceSidebarMonitorScopeId(for: secondary)
        let visibleNames = visibleWorkspaceNamesForSidebar(
            workspaces: state.workspaces,
            selectedMonitorScopeId: workspaceSidebarDefaultScopeId,
            focusedMonitorScopeId: state.focusedMonitorScopeId,
            targetMonitorScopeId: secondaryScope,
        )
        let grouped = workspaceSidebarVisibleWorkspacesByProject(
            workspaces: state.workspaces,
            selectedScopeId: workspaceSidebarDefaultScopeId,
            focusedMonitorScopeId: state.focusedMonitorScopeId,
            targetMonitorScopeId: secondaryScope,
            projectsEnabled: projectsAreEnabled(),
        )

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertEqual(state.activeProjectId, workspaceProjectDefaultId)
        XCTAssertEqual(visibleNames, [secondaryDefault.name, secondaryFoldered.name])
        XCTAssertEqual(grouped.keys.sorted(by: { $0.rawValue < $1.rawValue }), [workspaceProjectDefaultId])
        XCTAssertEqual(grouped[workspaceProjectDefaultId]?.map(\.name), [
            secondaryDefault.name,
            secondaryFoldered.name,
        ])
    }

    func testFolderMutationGateAllowsExistingFoldersWhenProjectsDisabled() {
        let first = Workspace.get(byName: "1")
        first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 1, parent: first.rootTilingContainer)
        let second = Workspace.get(byName: "2")
        second.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 2, parent: second.rootTilingContainer)
        config.enableProjects = false

        XCTAssertTrue(createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: second.name,
            targetWorkspaceName: first.name
        ))
        let folderId = first.projectId

        XCTAssertFalse(projectsAreEnabled())
        XCTAssertTrue(workspaceSidebarFolderMutationIsEnabled(folderId))
        XCTAssertFalse(workspaceSidebarFolderMutationIsEnabled(workspaceProjectDefaultId))
        XCTAssertFalse(workspaceSidebarFolderMutationIsEnabled(WorkspaceProjectId("project-missing")))
    }

    func testFolderRenameActionWorksWhenProjectsAreHardDisabled() async throws {
        let first = Workspace.get(byName: "1")
        first.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 1, parent: first.rootTilingContainer)
        let second = Workspace.get(byName: "2")
        second.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 2, parent: second.rootTilingContainer)
        config.enableProjects = false

        XCTAssertTrue(createSidebarFolderFromWorkspaces(
            sourceWorkspaceName: second.name,
            targetWorkspaceName: first.name
        ))
        let folderId = first.projectId

        handleWorkspaceSidebarAction(.renameProject(folderId, displayName: "Client"))
        for _ in 0 ..< 20 where config.workspaceSidebar.projectLabels[folderId.rawValue] != "Client" {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(config.workspaceSidebar.projectLabels[folderId.rawValue], "Client")
        XCTAssertEqual(workspaceProjectName(folderId), "Client")
    }

    func testLabelOnlyFoldersStayHiddenButPersistWhenProjectsDisabled() {
        let orphanedProjectId = WorkspaceProjectId("project-orphaned")
        config.enableProjects = false
        config.workspaceSidebar.projectLabels[orphanedProjectId.rawValue] = "Old Folder"
        config.workspaceSidebar.projectColors[orphanedProjectId.rawValue] = "#60A5FA"
        setWorkspaceSidebarFolderExpanded(orphanedProjectId, isExpanded: false)

        XCTAssertEqual(buildWorkspaceSidebarProjectViewModels().map(\.id), [workspaceProjectDefaultId])

        XCTAssertNil(winMuxWorkspaceState.projectsById[orphanedProjectId])
        XCTAssertEqual(config.workspaceSidebar.projectLabels[orphanedProjectId.rawValue], "Old Folder")
        XCTAssertEqual(config.workspaceSidebar.projectColors[orphanedProjectId.rawValue], "#60A5FA")
        XCTAssertFalse(workspaceSidebarFolderIsExpanded(orphanedProjectId))
    }

    func testFolderDissolvesWhenItsLastTabBecomesEmpty() {
        let defaultTab = Workspace.get(byName: "default")
        defaultTab.markAsAutomaticallyNamed()
        _ = TestWindow.new(id: 10, parent: defaultTab.rootTilingContainer)
        XCTAssertTrue(defaultTab.focusWorkspace())
        let groupedTab = Workspace.get(byName: "grouped")
        groupedTab.markAsAutomaticallyNamed()
        let groupedWindow = TestWindow.new(id: 11, parent: groupedTab.rootTilingContainer)
        let project = createWorkspaceProject()
        groupedTab.assignProject(project.id)
        groupedTab.seedMonitorIfNeeded(mainMonitor)
        config.workspaceSidebar.projectLabels[project.id.rawValue] = "Client"
        config.workspaceSidebar.projectColors[project.id.rawValue] = "#60A5FA"
        setWorkspaceSidebarFolderExpanded(project.id, isExpanded: false)

        groupedWindow.closeAxWindow()
        Workspace.reconcileWorkspaceState()

        XCTAssertNil(Workspace.existing(byName: groupedTab.name))
        XCTAssertNil(winMuxWorkspaceState.projectsById[project.id])
        XCTAssertNil(config.workspaceSidebar.projectLabels[project.id.rawValue])
        XCTAssertNil(config.workspaceSidebar.projectColors[project.id.rawValue])
        XCTAssertTrue(workspaceSidebarFolderIsExpanded(project.id))
        XCTAssertEqual(buildWorkspaceSidebarProjectViewModels().map(\.id), [workspaceProjectDefaultId])
    }

    private func sidebarWorkspace(
        _ name: String,
        projectId: WorkspaceProjectId,
        monitorScopeId: String
    ) -> WorkspaceSidebarWorkspaceViewModel {
        WorkspaceSidebarWorkspaceViewModel(
            name: name,
            projectId: projectId,
            displayName: name,
            sidebarLabel: "",
            isGeneratedName: true,
            monitorScopeId: monitorScopeId,
            monitorName: nil,
            isFocused: false,
            isVisible: false,
            items: []
        )
    }
}
