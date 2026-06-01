import SwiftUI

struct WorkspaceSidebarWorkspaceReorderFrame: Equatable {
    let workspaceName: String
    let projectId: WorkspaceProjectId
    let frame: CGRect
    let isReorderable: Bool
}

struct WorkspaceSidebarWorkspaceReorderFramePreferenceKey: PreferenceKey {
    static let defaultValue: [WorkspaceSidebarWorkspaceReorderFrame] = []

    static func reduce(
        value: inout [WorkspaceSidebarWorkspaceReorderFrame],
        nextValue: () -> [WorkspaceSidebarWorkspaceReorderFrame]
    ) {
        value.append(contentsOf: nextValue())
    }
}

struct WorkspaceSidebarWorkspaceReorderTarget: Equatable {
    let projectId: WorkspaceProjectId
    let targetWorkspaceName: String
    let placement: WorkspaceReorderPlacement
}

struct WorkspaceSidebarWorkspaceReorderDragState: Equatable {
    let sourceWorkspaceName: String
    let projectId: WorkspaceProjectId
    var pointer: CGPoint
    var target: WorkspaceSidebarWorkspaceReorderTarget?
}

func workspaceSidebarWorkspaceReorderIsEnabled(
    isCompact: Bool,
    isSearchFiltering: Bool,
    isRenamingWorkspace: Bool,
    isPinnedActiveWorkspace: Bool,
    isInteractive: Bool
) -> Bool {
    !isCompact &&
        !isSearchFiltering &&
        !isRenamingWorkspace &&
        !isPinnedActiveWorkspace &&
        isInteractive
}

func workspaceSidebarWorkspaceReorderTarget(
    sourceWorkspaceName: String,
    projectId: WorkspaceProjectId,
    pointer: CGPoint,
    frames: [WorkspaceSidebarWorkspaceReorderFrame]
) -> WorkspaceSidebarWorkspaceReorderTarget? {
    let candidates = frames
        .filter {
            $0.projectId == projectId &&
                $0.isReorderable &&
                $0.workspaceName != sourceWorkspaceName
        }
        .sorted { $0.frame.midY < $1.frame.midY }

    guard !candidates.isEmpty else { return nil }

    for candidate in candidates where pointer.y < candidate.frame.midY {
        return WorkspaceSidebarWorkspaceReorderTarget(
            projectId: projectId,
            targetWorkspaceName: candidate.workspaceName,
            placement: .before(candidate.workspaceName)
        )
    }

    guard let last = candidates.last else { return nil }
    return WorkspaceSidebarWorkspaceReorderTarget(
        projectId: projectId,
        targetWorkspaceName: last.workspaceName,
        placement: .after(last.workspaceName)
    )
}

struct WorkspaceSidebarWorkspaceReorderGestureModifier: ViewModifier {
    let isEnabled: Bool
    let onChanged: (CGPoint) -> Void
    let onEnded: (CGPoint) -> Void
    @State private var isDragging = false

    func body(content: Content) -> some View {
        if isEnabled {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named("workspaceSidebarContent"))
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            beginWorkspaceSidebarItemDrag()
                        }
                        onChanged(value.location)
                    }
                    .onEnded { value in
                        onEnded(value.location)
                        if isDragging {
                            isDragging = false
                            endWorkspaceSidebarItemDrag()
                        }
                    },
            )
        } else {
            content
        }
    }
}

struct WorkspaceSidebarWorkspaceReorderIndicator: View {
    let width: CGFloat

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.accentColor.opacity(0.88))
            .frame(width: max(width - 16, 0), height: 2)
            .padding(.leading, 8)
            .padding(.vertical, 2)
            .frame(width: width, alignment: .leading)
            .allowsHitTesting(false)
    }
}
