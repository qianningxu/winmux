import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    func handleSectionClick() {
        guard allowsWorkspaceActivation else { return }
        if isInUseOnOtherDisplay {
            activeInUseOverrideWorkspaceName = workspace.name
            return
        }
        if shouldHandleWorkspaceSidebarActivation(
            isEditing: false,
            isSidebarDragInProgress: isWorkspaceSidebarDragInProgress()
        ) {
            activeInUseOverrideWorkspaceName = nil
            onBeginWorkspaceActivation(workspace.name)
            actions.send(.selectWorkspace(workspace.name))
        }
    }

    func handlePayloadDrop(_ payload: WorkspaceSidebarDragPayload) {
        guard !workspaceSidebarPayload(payload, comesFromWorkspace: workspace.name) else {
            actions.send(.clearDropPreview)
            WindowDragCursorProxyPanel.shared.hide()
            return
        }
        switch payload {
            case .window(let windowId):
                actions.send(.moveWindow(windowId, toWorkspace: workspace.name))
            case .tabGroup:
                guard let sourceWorkspaceName = workspaceSidebarPayloadSourceWorkspaceName(payload),
                      sourceWorkspaceName != workspace.name
                else {
                    actions.send(.clearDropPreview)
                    WindowDragCursorProxyPanel.shared.hide()
                    return
                }
                actions.send(.createFolderFromWorkspaces(sourceWorkspaceName, withWorkspace: workspace.name))
        }
    }
}

@MainActor
private func workspaceSidebarPayload(_ payload: WorkspaceSidebarDragPayload, comesFromWorkspace workspaceName: String) -> Bool {
    workspaceSidebarPayloadSourceWorkspaceName(payload) == workspaceName
}

@MainActor
func workspaceSidebarPayloadSourceWorkspaceName(_ payload: WorkspaceSidebarDragPayload) -> String? {
    switch payload {
        case .window(let windowId):
            return Window.get(byId: windowId)?.nodeWorkspace?.name
        case .tabGroup(let representativeWindowId):
            guard let window = Window.get(byId: representativeWindowId) else { return nil }
            return dragSubjectNode(for: window, subject: .group).nodeWorkspace?.name
    }
}
