@testable import AppBundle
import XCTest

final class WorkspaceSidebarWindowMenuTest: XCTestCase {
    func testBuildsMenuRowsForEveryWindowInEveryTab() {
        let first = makeWorkspace(name: "1", displayName: "ChatGPT", windowId: 11, appName: "ChatGPT")
        let second = makeWorkspace(name: "2", displayName: "Browser", windowId: 12, appName: "Safari")

        let items = workspaceSidebarTiledWindowMenuItems(workspaces: [first, second])

        XCTAssertEqual(items.map(\.menuTitle), ["ChatGPT — ChatGPT", "Safari — Browser"])
        XCTAssertEqual(items.map(\.isFloating), [false, false])
    }

    private func makeWorkspace(
        name: String,
        displayName: String,
        windowId: UInt32,
        appName: String
    ) -> WorkspaceSidebarWorkspaceViewModel {
        WorkspaceSidebarWorkspaceViewModel(
            name: name,
            projectId: workspaceProjectDefaultId,
            displayName: displayName,
            sidebarLabel: "",
            isGeneratedName: false,
            monitorScopeId: "main",
            monitorName: nil,
            isFocused: false,
            isVisible: true,
            items: [WorkspaceSidebarItemViewModel(kind: .window(WorkspaceSidebarWindowViewModel(
                windowId: windowId,
                workspaceName: name,
                appName: appName,
                appBundleId: nil,
                appBundlePath: nil,
                title: nil,
                isFocused: false
            )))]
        )
    }
}
