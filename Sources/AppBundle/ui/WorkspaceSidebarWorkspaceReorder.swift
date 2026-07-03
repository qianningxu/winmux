import SwiftUI

struct WorkspaceSidebarWorkspaceReorderFrame: Equatable {
    let workspaceName: String
    let projectId: WorkspaceProjectId
    let frame: CGRect
    let isReorderable: Bool
}

struct WorkspaceSidebarFolderReorderFrame: Equatable {
    let projectId: WorkspaceProjectId
    let frame: CGRect
    let isDropTarget: Bool
}

struct WorkspaceSidebarFolderReorderFramePreferenceKey: PreferenceKey {
    static let defaultValue: [WorkspaceSidebarFolderReorderFrame] = []

    static func reduce(
        value: inout [WorkspaceSidebarFolderReorderFrame],
        nextValue: () -> [WorkspaceSidebarFolderReorderFrame]
    ) {
        value.append(contentsOf: nextValue())
    }
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

struct WorkspaceSidebarWorkspaceFolderTarget: Equatable {
    let projectId: WorkspaceProjectId
    let sourceWorkspaceName: String
}

enum WorkspaceSidebarWorkspaceDragTarget: Equatable {
    case reorder(WorkspaceSidebarWorkspaceReorderTarget)
    case moveToFolder(WorkspaceSidebarWorkspaceFolderTarget)
}

func workspaceSidebarWorkspaceDragFinishAction(
    sourceWorkspaceName: String,
    target: WorkspaceSidebarWorkspaceDragTarget
) -> WorkspaceSidebarAction? {
    switch target {
        case .reorder(let reorderTarget):
            return .reorderWorkspace(
                sourceWorkspaceName,
                projectId: reorderTarget.projectId,
                placement: reorderTarget.placement
            )
        case .moveToFolder(let folderTarget):
            guard folderTarget.sourceWorkspaceName == sourceWorkspaceName else { return nil }
            return .moveWorkspaceToFolder(
                folderTarget.sourceWorkspaceName,
                projectId: folderTarget.projectId
            )
    }
}

struct WorkspaceSidebarWorkspaceReorderDragState: Equatable {
    let sourceWorkspaceName: String
    let projectId: WorkspaceProjectId
    var pointer: CGPoint
    var target: WorkspaceSidebarWorkspaceDragTarget?
}

enum WorkspaceSidebarWorkspaceReorderPreviewPlacement: Equatable {
    case before(String)
    case after(String)
    case intoFolder(WorkspaceProjectId)
}

enum WorkspaceSidebarWorkspaceListEntry: Identifiable, Equatable {
    case workspace(WorkspaceSidebarWorkspaceViewModel, isDragAnchor: Bool)
    case placeholder(WorkspaceSidebarWorkspaceViewModel, projectId: WorkspaceProjectId)

    var id: String {
        switch self {
            case .workspace(let workspace, _):
                return "workspace:\(workspace.name)"
            case .placeholder(let workspace, let projectId):
                return "placeholder:\(projectId.rawValue):\(workspace.name)"
        }
    }
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

func workspaceSidebarHeaderRowIsHighlighted(
    isSelected: Bool,
    isReorderSource: Bool
) -> Bool {
    isSelected || isReorderSource
}

func workspaceSidebarWorkspaceReorderTarget(
    sourceWorkspaceName: String,
    sourceProjectId: WorkspaceProjectId,
    pointer: CGPoint,
    frames: [WorkspaceSidebarWorkspaceReorderFrame]
) -> WorkspaceSidebarWorkspaceReorderTarget? {
    let candidates = frames
        .filter {
            $0.isReorderable &&
                $0.workspaceName != sourceWorkspaceName &&
                $0.frame.minX <= pointer.x &&
                pointer.x <= $0.frame.maxX
        }
        .sorted { $0.frame.midY < $1.frame.midY }

    guard !candidates.isEmpty else { return nil }

    if let containingCandidate = candidates.last(where: { $0.frame.contains(pointer) }) {
        if containingCandidate.projectId != sourceProjectId {
            return WorkspaceSidebarWorkspaceReorderTarget(
                projectId: containingCandidate.projectId,
                targetWorkspaceName: containingCandidate.workspaceName,
                placement: workspaceSidebarWorkspacePointerIsBeforeMidline(pointer, frame: containingCandidate.frame)
                    ? .before(containingCandidate.workspaceName)
                    : .after(containingCandidate.workspaceName)
            )
        }
        guard let placement = workspaceSidebarWorkspaceReorderPlacement(
            pointer,
            frame: containingCandidate.frame,
            targetWorkspaceName: containingCandidate.workspaceName
        ) else {
            return nil
        }
        return WorkspaceSidebarWorkspaceReorderTarget(
            projectId: containingCandidate.projectId,
            targetWorkspaceName: containingCandidate.workspaceName,
            placement: placement
        )
    }

    for candidate in candidates where pointer.y < candidate.frame.midY {
        return WorkspaceSidebarWorkspaceReorderTarget(
            projectId: candidate.projectId,
            targetWorkspaceName: candidate.workspaceName,
            placement: .before(candidate.workspaceName)
        )
    }

    guard let last = candidates.last else { return nil }
    return WorkspaceSidebarWorkspaceReorderTarget(
        projectId: last.projectId,
        targetWorkspaceName: last.workspaceName,
        placement: .after(last.workspaceName)
    )
}

func workspaceSidebarWorkspaceDragTarget(
    sourceWorkspaceName: String,
    sourceProjectId: WorkspaceProjectId,
    pointer: CGPoint,
    workspaceFrames: [WorkspaceSidebarWorkspaceReorderFrame],
    folderFrames: [WorkspaceSidebarFolderReorderFrame] = []
) -> WorkspaceSidebarWorkspaceDragTarget? {
    let folderTarget = workspaceSidebarWorkspaceFolderTarget(
        sourceWorkspaceName: sourceWorkspaceName,
        sourceProjectId: sourceProjectId,
        pointer: pointer,
        frames: folderFrames
    )
    if let folderTarget,
       !workspaceSidebarPointerIsOverWorkspaceRow(
        sourceWorkspaceName: sourceWorkspaceName,
        pointer: pointer,
        frames: workspaceFrames
       )
    {
        return .moveToFolder(folderTarget)
    }
    if let reorderTarget = workspaceSidebarWorkspaceReorderTarget(
        sourceWorkspaceName: sourceWorkspaceName,
        sourceProjectId: sourceProjectId,
        pointer: pointer,
        frames: workspaceFrames
    ) {
        return .reorder(reorderTarget)
    }
    if let folderTarget {
        return .moveToFolder(folderTarget)
    }
    return nil
}

private func workspaceSidebarPointerIsOverWorkspaceRow(
    sourceWorkspaceName: String,
    pointer: CGPoint,
    frames: [WorkspaceSidebarWorkspaceReorderFrame]
) -> Bool {
    frames.contains {
        $0.isReorderable &&
            $0.workspaceName != sourceWorkspaceName &&
            $0.frame.contains(pointer)
    }
}

func workspaceSidebarWorkspaceFolderTarget(
    sourceWorkspaceName: String,
    sourceProjectId: WorkspaceProjectId,
    pointer: CGPoint,
    frames: [WorkspaceSidebarFolderReorderFrame]
) -> WorkspaceSidebarWorkspaceFolderTarget? {
    guard let candidate = frames.last(where: {
        $0.isDropTarget &&
            $0.projectId != sourceProjectId &&
            $0.frame.contains(pointer)
    }) else { return nil }
    return WorkspaceSidebarWorkspaceFolderTarget(
        projectId: candidate.projectId,
        sourceWorkspaceName: sourceWorkspaceName
    )
}

func workspaceSidebarWorkspaceReorderPreviewPlacement(
    sourceWorkspaceName: String,
    target: WorkspaceSidebarWorkspaceDragTarget?
) -> WorkspaceSidebarWorkspaceReorderPreviewPlacement? {
    guard let target else { return nil }
    switch target {
        case .reorder(let reorderTarget):
            switch reorderTarget.placement {
                case .before(let workspaceName):
                    guard workspaceName != sourceWorkspaceName else { return nil }
                    return .before(workspaceName)
                case .after(let workspaceName):
                    guard workspaceName != sourceWorkspaceName else { return nil }
                    return .after(workspaceName)
            }
        case .moveToFolder(let folderTarget):
            guard folderTarget.sourceWorkspaceName == sourceWorkspaceName else { return nil }
            return .intoFolder(folderTarget.projectId)
    }
}

func workspaceSidebarWorkspaceListEntries(
    workspaces: [WorkspaceSidebarWorkspaceViewModel],
    projectId: WorkspaceProjectId,
    sourceWorkspaceName: String?,
    sourceWorkspace: WorkspaceSidebarWorkspaceViewModel?,
    target: WorkspaceSidebarWorkspaceDragTarget?
) -> [WorkspaceSidebarWorkspaceListEntry] {
    let retainsSourceGestureAnchor = sourceWorkspace?.projectId == projectId &&
        sourceWorkspaceName != nil &&
        target != nil
    let visibleWorkspaces = workspaces.filter {
        retainsSourceGestureAnchor || $0.name != sourceWorkspaceName
    }
    func workspaceEntry(_ workspace: WorkspaceSidebarWorkspaceViewModel) -> WorkspaceSidebarWorkspaceListEntry {
        .workspace(
            workspace,
            isDragAnchor: retainsSourceGestureAnchor && workspace.name == sourceWorkspaceName
        )
    }
    guard let sourceWorkspace,
          let placement = workspaceSidebarWorkspaceReorderPreviewPlacement(
            sourceWorkspaceName: sourceWorkspace.name,
            target: target
          )
    else {
        guard target != nil else {
            return workspaces.map { .workspace($0, isDragAnchor: false) }
        }
        return visibleWorkspaces.map { workspaceEntry($0) }
    }

    switch placement {
        case .before(let targetWorkspaceName):
            guard case .reorder(let reorderTarget)? = target,
                  reorderTarget.projectId == projectId
            else {
                return visibleWorkspaces.map { workspaceEntry($0) }
            }
            return workspaceSidebarWorkspaceListEntries(
                visibleWorkspaces: visibleWorkspaces,
                sourceWorkspace: sourceWorkspace,
                projectId: projectId,
                targetWorkspaceName: targetWorkspaceName,
                insertBefore: true,
                retainsSourceGestureAnchor: retainsSourceGestureAnchor
            )
        case .after(let targetWorkspaceName):
            guard case .reorder(let reorderTarget)? = target,
                  reorderTarget.projectId == projectId
            else {
                return visibleWorkspaces.map { workspaceEntry($0) }
            }
            return workspaceSidebarWorkspaceListEntries(
                visibleWorkspaces: visibleWorkspaces,
                sourceWorkspace: sourceWorkspace,
                projectId: projectId,
                targetWorkspaceName: targetWorkspaceName,
                insertBefore: false,
                retainsSourceGestureAnchor: retainsSourceGestureAnchor
            )
        case .intoFolder(let folderProjectId):
            guard folderProjectId == projectId else {
                return visibleWorkspaces.map { workspaceEntry($0) }
            }
            return visibleWorkspaces.map { workspaceEntry($0) } +
                [.placeholder(sourceWorkspace, projectId: projectId)]
    }
}

func workspaceSidebarWorkspaceSourcePreview(
    _ workspace: WorkspaceSidebarWorkspaceViewModel
) -> WorkspaceSidebarDropPreviewViewModel {
    let tabItems = workspaceSidebarWorkspaceSourcePreviewTabItems(workspace)
    let primaryItem = tabItems.first
    let windowCount = max(workspace.tabSummary.windowCount, tabItems.count, 1)
    return WorkspaceSidebarDropPreviewViewModel(
        sourceWindowId: workspaceSidebarWorkspaceSourceWindowId(workspace),
        label: workspace.displayName.isEmpty ? workspace.tabSummary.title : workspace.displayName,
        appName: primaryItem?.appName ?? workspace.tabSummary.subtitle ?? workspace.tabSummary.title,
        appBundleIdentifier: primaryItem?.appBundleIdentifier ?? workspace.tabSummary.appBundleId,
        appBundlePath: primaryItem?.appBundlePath ?? workspace.tabSummary.appBundlePath,
        targetWorkspaceName: nil,
        targetsNewWorkspace: false,
        isTabGroup: windowCount > 1,
        windowCount: windowCount,
        tabItems: windowCount > 1 ? tabItems : [],
    )
}

private func workspaceSidebarWorkspaceSourceWindowId(
    _ workspace: WorkspaceSidebarWorkspaceViewModel
) -> UInt32 {
    for item in workspace.items {
        switch item.kind {
            case .window(let window):
                return window.windowId
            case .tabGroup(let group):
                return group.representativeWindowId
        }
    }
    return 0
}

private func workspaceSidebarWorkspaceSourcePreviewTabItems(
    _ workspace: WorkspaceSidebarWorkspaceViewModel
) -> [WorkspaceSidebarDropPreviewTabItem] {
    workspace.items.flatMap { item -> [WorkspaceSidebarDropPreviewTabItem] in
        switch item.kind {
            case .window(let window):
                return [workspaceSidebarWorkspaceSourcePreviewTabItem(window)]
            case .tabGroup(let group):
                return group.tabs.map(workspaceSidebarWorkspaceSourcePreviewTabItem)
        }
    }
}

private func workspaceSidebarWorkspaceSourcePreviewTabItem(
    _ window: WorkspaceSidebarWindowViewModel
) -> WorkspaceSidebarDropPreviewTabItem {
    WorkspaceSidebarDropPreviewTabItem(
        title: window.title ?? window.appName,
        appName: window.appName,
        appBundleIdentifier: window.appBundleId,
        appBundlePath: window.appBundlePath,
    )
}

func workspaceSidebarIsProjectPreviewTarget(
    projectId: WorkspaceProjectId,
    sourceWorkspaceName: String?,
    sourceWorkspace: WorkspaceSidebarWorkspaceViewModel?,
    target: WorkspaceSidebarWorkspaceDragTarget?
) -> Bool {
    guard let sourceWorkspace,
          let placement = workspaceSidebarWorkspaceReorderPreviewPlacement(
            sourceWorkspaceName: sourceWorkspace.name,
            target: target
          )
    else { return false }
    switch placement {
        case .before, .after:
            guard case .reorder(let reorderTarget)? = target else { return false }
            return reorderTarget.projectId == projectId && sourceWorkspaceName != nil
        case .intoFolder(let folderProjectId):
            return folderProjectId == projectId && sourceWorkspaceName != nil
    }
}

private func workspaceSidebarWorkspaceListEntries(
    visibleWorkspaces: [WorkspaceSidebarWorkspaceViewModel],
    sourceWorkspace: WorkspaceSidebarWorkspaceViewModel,
    projectId: WorkspaceProjectId,
    targetWorkspaceName: String,
    insertBefore: Bool,
    retainsSourceGestureAnchor: Bool
) -> [WorkspaceSidebarWorkspaceListEntry] {
    var entries: [WorkspaceSidebarWorkspaceListEntry] = []
    var didInsertPlaceholder = false

    for workspace in visibleWorkspaces {
        if insertBefore && workspace.name == targetWorkspaceName {
            entries.append(.placeholder(sourceWorkspace, projectId: projectId))
            didInsertPlaceholder = true
        }
        entries.append(.workspace(
            workspace,
            isDragAnchor: retainsSourceGestureAnchor && workspace.name == sourceWorkspace.name
        ))
        if !insertBefore && workspace.name == targetWorkspaceName {
            entries.append(.placeholder(sourceWorkspace, projectId: projectId))
            didInsertPlaceholder = true
        }
    }

    if !didInsertPlaceholder {
        entries.append(.placeholder(sourceWorkspace, projectId: projectId))
    }
    return entries
}

func workspaceSidebarProjectFrameIsVisibleDropTarget(
    projectId: WorkspaceProjectId,
    sourceProjectId: WorkspaceProjectId?
) -> Bool {
    guard let sourceProjectId else { return false }
    return projectId != sourceProjectId
}

func workspaceSidebarWorkspacePointerIsBeforeMidline(_ pointer: CGPoint, frame: CGRect) -> Bool {
    pointer.y < frame.midY
}

func workspaceSidebarWorkspaceReorderPlacement(
    _ pointer: CGPoint,
    frame: CGRect,
    targetWorkspaceName: String
) -> WorkspaceReorderPlacement? {
    guard frame.width > 0, frame.height > 0 else { return nil }
    let y = (pointer.y - frame.minY) / frame.height
    let reorderBand: CGFloat = 0.24
    if y < reorderBand {
        return .before(targetWorkspaceName)
    }
    if y > 1 - reorderBand {
        return .after(targetWorkspaceName)
    }
    return nil
}

struct WorkspaceSidebarWorkspaceReorderGestureModifier: ViewModifier {
    let isEnabled: Bool
    let onChanged: (CGPoint) -> Void
    let onEnded: (CGPoint) -> Void
    @State private var isDragging = false

    func body(content: Content) -> some View {
        if isEnabled {
            content.highPriorityGesture(
                DragGesture(minimumDistance: workspaceSidebarDragStartDistance, coordinateSpace: .named("workspaceSidebarContent"))
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            beginWorkspaceSidebarItemDrag()
                        }
                        noteCurrentMousePointerSample()
                        onChanged(value.location)
                    }
                    .onEnded { value in
                        noteCurrentMousePointerSample()
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

struct WorkspaceSidebarWorkspaceReorderPlaceholder: View {
    let width: CGFloat
    let nestedContentIndent: CGFloat
    let previewWorkspace: WorkspaceSidebarWorkspaceViewModel?
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }
    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: workspaceSidebarAppIconTextSpacing) {
            if let previewWorkspace,
               let icon = appIconImage(
                bundleIdentifier: previewWorkspace.tabSummary.appBundleId,
                bundlePath: previewWorkspace.tabSummary.appBundlePath
               )
            {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                    .cornerRadius(4)
                    .opacity(0.92)
                    .workspaceSidebarIconStroke(palette)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.gray200(palette.isDark ? 0.86 : 0.92))
                    .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                    .workspaceSidebarIconStroke(palette)
            }

            if let previewWorkspace {
                VStack(alignment: .leading, spacing: 1) {
                    Text(previewWorkspace.displayName)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(palette.foreground(0.76))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle = previewWorkspace.tabSummary.subtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(palette.foreground(0.42))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .layoutPriority(1)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.contrastingFill(darkOpacity: 0.18, lightOpacity: 0.12))
                    .frame(width: 92, height: 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, workspaceSidebarRowHorizontalPadding)
        .frame(height: workspaceSidebarTabRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            rowShape
                .fill(palette.gray200(palette.isDark ? 0.96 : 1))
            rowShape
                .fill(palette.gray300(palette.isDark ? 0.20 : 0.32))
        }
        .overlay {
            rowShape
                .strokeBorder(palette.tabStroke(active: true), lineWidth: 0.95)
        }
        .shadow(
            color: palette.shadow(0.10, lightOpacity: 0.04),
            radius: 4,
            x: 0,
            y: 1
        )
        .padding(.leading, workspaceSidebarSectionInnerHorizontalInset + nestedContentIndent)
        .padding(.trailing, workspaceSidebarSectionInnerHorizontalInset)
        .frame(width: width, alignment: .leading)
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: nestedContentIndent)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct WorkspaceSidebarProjectedDragAnchorModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .frame(height: 1, alignment: .top)
                .clipped()
                .opacity(0.001)
                .accessibilityHidden(true)
        } else {
            content
        }
    }
}
