import AppKit
@testable import AppBundle
import XCTest

final class WorkspaceSidebarHorizontalBarTest: XCTestCase {
    func testNotchedDisplayUsesFullWidthWidgetAndProjectRows() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let leftSafeArea = NSRect(x: 0, y: 1085, width: 771, height: 32)
        let rightSafeArea = NSRect(x: 957, y: 1085, width: 771, height: 32)

        let left = workspaceSidebarTopBarRegionFrame(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftSafeArea,
            barHeight: 32,
        )
        let right = menuBarStatusWidgetRegionFrame(
            screenFrame: screenFrame,
            auxiliaryTopRightArea: rightSafeArea,
            barHeight: 32,
        )
        let panel = workspaceSidebarTopBarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: NSRect(x: 0, y: 0, width: 1728, height: 1085),
            auxiliaryTopLeftArea: leftSafeArea,
            auxiliaryTopRightArea: rightSafeArea,
            barHeight: 32,
            extraWidth: 400,
        )

        XCTAssertEqual(left, NSRect(x: 0, y: 1041, width: 1728, height: 44))
        XCTAssertEqual(right, NSRect(x: 0, y: 1085, width: 1728, height: 32))
        XCTAssertEqual(panel.minX, left.minX)
        XCTAssertEqual(panel.maxY, right.minY)
        XCTAssertEqual(panel.maxX, screenFrame.maxX)
    }

    func testNonNotchedDisplayUsesTwoFullWidthRows() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let left = workspaceSidebarTopBarRegionFrame(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: nil,
            barHeight: 32,
        )
        let right = menuBarStatusWidgetRegionFrame(
            screenFrame: screenFrame,
            auxiliaryTopRightArea: nil,
            barHeight: 32,
        )

        XCTAssertEqual(left.minX, screenFrame.minX)
        XCTAssertEqual(right.maxX, screenFrame.maxX)
        XCTAssertEqual(left.maxX, right.maxX)
        XCTAssertEqual(left.maxY, right.minY)
        XCTAssertGreaterThan(left.width, 0)
        XCTAssertGreaterThan(right.width, 0)
    }

    func testSecondaryDisplayKeepsNegativeScreenOrigin() {
        let screenFrame = NSRect(x: -1440, y: 120, width: 1440, height: 900)
        let leftSafeArea = NSRect(x: -1432, y: 990, width: 420, height: 30)
        let rightSafeArea = NSRect(x: -920, y: 990, width: 480, height: 30)

        let panel = workspaceSidebarTopBarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: NSRect(x: -1432, y: 145, width: 1432, height: 875),
            auxiliaryTopLeftArea: leftSafeArea,
            auxiliaryTopRightArea: rightSafeArea,
            barHeight: 30,
        )

        XCTAssertEqual(panel.minX, -1440)
        XCTAssertEqual(panel.maxY, screenFrame.maxY - 30)
        XCTAssertEqual(panel.maxX, screenFrame.maxX)
    }

    func testHorizontalReorderUsesTabMidpointsAndKeepsFolderDestination() {
        let folder = WorkspaceFolderId("folder-a")
        let frames = [
            WorkspaceSidebarHorizontalTabFrame(
                workspaceName: "first",
                folderId: folder,
                frame: CGRect(x: 0, y: 0, width: 100, height: 32),
            ),
            WorkspaceSidebarHorizontalTabFrame(
                workspaceName: "second",
                folderId: WorkspaceFolderId("folder-b"),
                frame: CGRect(x: 108, y: 0, width: 100, height: 32),
            ),
            WorkspaceSidebarHorizontalTabFrame(
                workspaceName: "third",
                folderId: WorkspaceFolderId("folder-c"),
                frame: CGRect(x: 216, y: 0, width: 100, height: 32),
            ),
        ]

        let before = workspaceSidebarHorizontalReorderTarget(
            sourceWorkspaceName: "first",
            pointer: CGPoint(x: 120, y: 16),
            frames: frames,
        )
        let after = workspaceSidebarHorizontalReorderTarget(
            sourceWorkspaceName: "first",
            pointer: CGPoint(x: 180, y: 16),
            frames: frames,
        )

        XCTAssertEqual(before, WorkspaceSidebarHorizontalReorderTarget(
            workspaceName: "second",
            folderId: WorkspaceFolderId("folder-b"),
            placement: .before("second"),
        ))
        XCTAssertEqual(after, WorkspaceSidebarHorizontalReorderTarget(
            workspaceName: "second",
            folderId: WorkspaceFolderId("folder-b"),
            placement: .after("second"),
        ))
    }

    func testHorizontalProjectionShowsOnlyActiveProjectAsOneTabPerWorkspace() {
        let activeProject = workspaceProjectDefaultId
        let otherProject = WorkspaceProjectId("other")
        let childWindow = WorkspaceSidebarWindowViewModel(
            windowId: 101,
            workspaceName: "composed",
            appName: "Safari",
            appBundleId: "com.apple.Safari",
            appBundlePath: "/Applications/Safari.app",
            title: "Docs",
            isFocused: false,
        )
        let childGroup = WorkspaceSidebarTabGroupViewModel(
            representativeWindowId: 101,
            workspaceName: "composed",
            title: "Docs",
            windowCount: 2,
            isFocused: false,
            tabs: [childWindow],
        )
        let workspaces = [
            makeWorkspace(name: "other-project", projectId: otherProject),
            makeWorkspace(name: "first", projectId: activeProject),
            WorkspaceSidebarWorkspaceViewModel(
                name: "composed",
                projectId: activeProject,
                displayName: "Composed",
                sidebarLabel: "Composed",
                isGeneratedName: false,
                tabSummary: WorkspaceSidebarTabSummaryViewModel(
                    title: "Docs & Notes",
                    subtitle: nil,
                    appBundleId: "com.apple.Safari",
                    appBundlePath: "/Applications/Safari.app",
                    windowCount: 2,
                    isEmpty: false,
                ),
                monitorScopeId: workspaceSidebarDefaultScopeId,
                monitorName: nil,
                isFocused: false,
                isVisible: true,
                items: [
                    WorkspaceSidebarItemViewModel(kind: .window(childWindow)),
                    WorkspaceSidebarItemViewModel(kind: .tabGroup(childGroup)),
                ],
            ),
        ]
        let snapshot = WorkspaceSidebarSnapshot(
            workspaces: workspaces,
            projects: [
                WorkspaceSidebarProjectViewModel(id: activeProject, displayName: "Main", colorHex: nil),
                WorkspaceSidebarProjectViewModel(id: otherProject, displayName: "Other", colorHex: nil),
            ],
            folders: [
                WorkspaceSidebarFolderViewModel(
                    id: WorkspaceFolderId("folder-hidden"),
                    projectId: activeProject,
                    displayName: "Hidden Folder",
                    colorHex: nil,
                    isUnfolded: true,
                ),
            ],
            activeProjectId: activeProject,
            monitorScopes: [],
            selectedMonitorScopeId: workspaceSidebarDefaultScopeId,
            targetMonitorScopeId: workspaceSidebarDefaultScopeId,
            focusedMonitorScopeId: workspaceSidebarDefaultScopeId,
            visibleWidth: 240,
            isPinnedExpanded: true,
            hoveredWorkspaceName: nil,
            dropPreview: nil,
            configuration: WorkspaceSidebarConfiguration(
                collapsedWidth: 44,
                expandedWidth: 240,
                topPadding: 8,
                showMonitorSelector: true,
                showsDate: true,
                showsStatusPills: true,
                widgets: [WorkspaceSidebarWidgetConfig(id: "ignored-widget")],
            ),
        )

        let visible = workspaceSidebarHorizontalVisibleWorkspaces(in: snapshot)

        XCTAssertEqual(visible.map(\.name), ["first", "composed"])
        XCTAssertEqual(visible.filter { $0.name == "composed" }.count, 1)
        XCTAssertEqual(visible.first(where: { $0.name == "composed" })?.items.count, 2)
        XCTAssertFalse(visible.map(\.name).contains("other-project"))
    }

    func testPopupHeightIsPositiveAndFiveMinuteRotationRemainsConfigured() {
        XCTAssertGreaterThan(
            workspaceSidebarHorizontalProjectPopupHeight(projectCount: 3),
            workspaceSidebarProjectPopupRowHeight,
        )
        XCTAssertEqual(menuBarProjectProgressRotationInterval, 5 * 60)
    }

    func testTopBarProjectDestinationsExcludeCurrentProject() {
        let current = WorkspaceSidebarProjectViewModel(
            id: "current",
            displayName: "Current",
            colorHex: nil,
        )
        let destination = WorkspaceSidebarProjectViewModel(
            id: "destination",
            displayName: "Destination",
            colorHex: nil,
        )

        XCTAssertEqual(
            workspaceSidebarProjectDestinations(
                projects: [current, destination],
                currentProjectId: current.id,
            ).map(\.id),
            [destination.id],
        )
    }

    private func makeWorkspace(
        name: String,
        projectId: WorkspaceProjectId,
    ) -> WorkspaceSidebarWorkspaceViewModel {
        WorkspaceSidebarWorkspaceViewModel(
            name: name,
            projectId: projectId,
            displayName: name.capitalized,
            sidebarLabel: name,
            isGeneratedName: false,
            monitorScopeId: workspaceSidebarDefaultScopeId,
            monitorName: nil,
            isFocused: false,
            isVisible: true,
            items: [],
        )
    }
}
