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

struct WorkspaceSidebarWorkspaceMergeTarget: Equatable {
    let projectId: WorkspaceProjectId
    let sourceWorkspaceName: String
    let targetWorkspaceName: String
    let position: WindowStackSplitPosition
}

enum WorkspaceSidebarWorkspaceDragTarget: Equatable {
    case reorder(WorkspaceSidebarWorkspaceReorderTarget)
    case merge(WorkspaceSidebarWorkspaceMergeTarget)
}

struct WorkspaceSidebarWorkspaceReorderDragState: Equatable {
    let sourceWorkspaceName: String
    let projectId: WorkspaceProjectId
    var pointer: CGPoint
    var target: WorkspaceSidebarWorkspaceDragTarget?
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

func workspaceSidebarWorkspaceDragTarget(
    sourceWorkspaceName: String,
    projectId: WorkspaceProjectId,
    pointer: CGPoint,
    frames: [WorkspaceSidebarWorkspaceReorderFrame]
) -> WorkspaceSidebarWorkspaceDragTarget? {
    if let mergeTarget = workspaceSidebarWorkspaceMergeTarget(
        sourceWorkspaceName: sourceWorkspaceName,
        projectId: projectId,
        pointer: pointer,
        frames: frames
    ) {
        return .merge(mergeTarget)
    }
    return workspaceSidebarWorkspaceReorderTarget(
        sourceWorkspaceName: sourceWorkspaceName,
        projectId: projectId,
        pointer: pointer,
        frames: frames
    ).map(WorkspaceSidebarWorkspaceDragTarget.reorder)
}

func workspaceSidebarWorkspaceMergeTarget(
    sourceWorkspaceName: String,
    projectId: WorkspaceProjectId,
    pointer: CGPoint,
    frames: [WorkspaceSidebarWorkspaceReorderFrame]
) -> WorkspaceSidebarWorkspaceMergeTarget? {
    let candidates = frames.filter {
        $0.projectId == projectId &&
            $0.isReorderable &&
            $0.workspaceName != sourceWorkspaceName &&
            $0.frame.contains(pointer)
    }
    guard let candidate = candidates.last,
          let position = workspaceSidebarWorkspaceMergePosition(pointer: pointer, frame: candidate.frame)
    else { return nil }
    return WorkspaceSidebarWorkspaceMergeTarget(
        projectId: projectId,
        sourceWorkspaceName: sourceWorkspaceName,
        targetWorkspaceName: candidate.workspaceName,
        position: position
    )
}

func workspaceSidebarWorkspaceMergePosition(pointer: CGPoint, frame: CGRect) -> WindowStackSplitPosition? {
    guard frame.width > 0, frame.height > 0 else { return nil }
    let x = (pointer.x - frame.minX) / frame.width
    let y = (pointer.y - frame.minY) / frame.height
    let edgeBand: CGFloat = 0.28
    let distances: [(position: WindowStackSplitPosition, distance: CGFloat)] = [
        (.left, x),
        (.right, 1 - x),
        (.above, y),
        (.below, 1 - y),
    ]
    guard let nearest = distances.min(by: { $0.distance < $1.distance }),
          nearest.distance <= edgeBand
    else { return nil }
    return nearest.position
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
