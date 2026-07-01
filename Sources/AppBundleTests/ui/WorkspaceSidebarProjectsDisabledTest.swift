@testable import AppBundle
import XCTest

@MainActor
final class WorkspaceSidebarProjectsDisabledTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testProjectViewModelsBackTabGroupsWhenProjectsDisabled() {
        let project = createWorkspaceProject()
        config.enableProjects = false

        XCTAssertEqual(buildWorkspaceSidebarProjectViewModels().map(\.id), [
            workspaceProjectDefaultId,
            project.id,
        ])
    }
}
