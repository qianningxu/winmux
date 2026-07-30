import Foundation

let sidebarDraftWorkspacePrefix = "__sidebar_draft_workspace_"
let internalAutomaticWorkspacePrefix = "__internal_auto_workspace_"
let workspaceProjectDefaultId = WorkspaceProjectId.defaultProject
let workspaceDefaultFolderDisplayName = "Unfolded"
let workspaceFolderDefaultId = WorkspaceFolderId(workspaceProjectDefaultId)

struct WorkspaceProject: Hashable, Identifiable {
    let id: WorkspaceProjectId
    let name: String
    let order: Int
    var folderOrder: [WorkspaceFolderId] = []
    /// Legacy compatibility mirror for call sites that still render folders through
    /// the old project view model. Real tab ordering lives on WorkspaceFolder.
    var workspaceOrder: [WorkspaceId] = []
    var linkedViewportIds: Set<MonitorViewportId> = []
}

struct WorkspaceFolderId: RawRepresentable, Hashable, Identifiable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
    let rawValue: String

    var id: Self { self }
    var backingProjectId: WorkspaceProjectId { WorkspaceProjectId(rawValue) }
    var description: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    init(_ backingProjectId: WorkspaceProjectId) {
        self.init(rawValue: backingProjectId.rawValue)
    }

    init(stringLiteral value: String) {
        self.init(value)
    }

    static func < (lhs: WorkspaceFolderId, rhs: WorkspaceFolderId) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct WorkspaceFolder: Hashable, Identifiable {
    let id: WorkspaceFolderId
    var projectId: WorkspaceProjectId
    var name: String
    var order: Int
    var workspaceOrder: [WorkspaceId] = []
    var linkedViewportIds: Set<MonitorViewportId> = []

    init(
        id: WorkspaceFolderId,
        projectId: WorkspaceProjectId = workspaceProjectDefaultId,
        name: String,
        order: Int,
        workspaceOrder: [WorkspaceId] = [],
        linkedViewportIds: Set<MonitorViewportId> = []
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.order = order
        self.workspaceOrder = workspaceOrder
        self.linkedViewportIds = linkedViewportIds
    }

    init(backingProject project: WorkspaceProject) {
        id = WorkspaceFolderId(project.id)
        projectId = workspaceProjectDefaultId
        name = project.name
        order = project.order
        workspaceOrder = project.workspaceOrder
        linkedViewportIds = project.linkedViewportIds
    }
}

enum WorkspaceMutationError: LocalizedError {
    case workspaceNotFound(String)
    case workspaceCannotBeDeleted(String)
    case projectNotFound(String)
    case projectCannotBeDeleted(String)
    case workspaceCloseBlocked(String, Int)
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
            case .workspaceCloseBlocked(let name, let count):
                "Tab '\(name)' was not closed because \(count) window\(count == 1 ? "" : "s") stayed open."
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
