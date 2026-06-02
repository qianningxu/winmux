@testable import AppBundle
import XCTest

@MainActor
final class WorkspaceSidebarProjectsDisabledTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testProjectViewModelsAreHiddenWhenProjectsDisabled() {
        _ = createWorkspaceProject()
        config.enableProjects = false

        XCTAssertEqual(buildWorkspaceSidebarProjectViewModels(), [])
    }
}
