import Foundation

let sidebarDraftWorkspacePrefix = "__sidebar_draft_workspace_"
let internalAutomaticWorkspacePrefix = "__internal_auto_workspace_"
let workspaceProjectDefaultId = WorkspaceProjectId.defaultProject

struct WorkspaceProject: Hashable, Identifiable {
    let id: WorkspaceProjectId
    let name: String
    let order: Int
    var workspaceOrder: [WorkspaceId] = []
    var linkedViewportIds: Set<MonitorViewportId> = []
}

enum WorkspaceMutationError: LocalizedError {
    case workspaceNotFound(String)
    case workspaceCannotBeDeleted(String)
    case projectNotFound(String)
    case projectCannotBeDeleted(String)
    case projectCloseBlocked(String, Int)
    case emptyName
    case duplicateProjectName(String)

    var errorDescription: String? {
        switch self {
            case .workspaceNotFound(let name):
                "Tab '\(name)' no longer exists."
            case .workspaceCannotBeDeleted(let name):
                "Tab '\(name)' cannot be deleted."
            case .projectNotFound(let id):
                "Folder '\(id)' no longer exists."
            case .projectCannotBeDeleted(let name):
                "Folder '\(name)' cannot be deleted."
            case .projectCloseBlocked(let name, let count):
                "Folder '\(name)' was not deleted because \(count) window\(count == 1 ? "" : "s") stayed open."
            case .emptyName:
                "Name cannot be empty."
            case .duplicateProjectName(let name):
                "A folder named '\(name)' already exists."
        }
    }
}

enum WorkspaceNamingStyle: String, Codable, Sendable {
    case explicit
    case automatic
}

enum WorkspaceReorderPlacement: Equatable {
    case before(String)
    case after(String)

    var targetWorkspaceName: String {
        switch self {
            case .before(let name), .after(let name): name
        }
    }
}

enum WorkspaceOrderDestination: Equatable {
    case before(WorkspaceId)
    case after(WorkspaceId)

    var targetWorkspaceId: WorkspaceId {
        switch self {
            case .before(let id), .after(let id): id
        }
    }
}
