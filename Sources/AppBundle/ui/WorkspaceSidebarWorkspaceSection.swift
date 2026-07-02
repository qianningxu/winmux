import AppKit
import Common
import SwiftUI

struct WorkspaceSidebarWorkspaceSection: View {
    let workspace: WorkspaceSidebarWorkspaceViewModel
    let dragPreview: WorkspaceSidebarDropPreviewViewModel?
    let expansionProgress: CGFloat
    let layout: WorkspaceSidebarConfiguration
    let emitsDropTarget: Bool
    let isFromOtherDisplay: Bool
    let isInUseOnOtherDisplay: Bool
    let isOnFocusedMonitor: Bool
    let allowsWorkspaceActivation: Bool
    let isPinnedActiveWorkspace: Bool
    let isActiveOnTargetMonitor: Bool
    let isPendingActivationOnTargetMonitor: Bool
    let projectContextLabel: String?
    let projectContextColor: Color?
    let nestedContentIndent: CGFloat
    @Binding var renamingWorkspaceName: String?
    @Binding var renamingWorkspaceText: String
    let onBeginRenameWorkspace: @MainActor () -> Void
    let onCommitRenameWorkspace: @MainActor () -> Void
    let onCancelRenameWorkspace: @MainActor () -> Void
    let selectedSearchTarget: WorkspaceSidebarSearchSelection?
    let isSearchFiltering: Bool
    let isWorkspaceReorderEnabled: Bool
    let isWorkspaceReorderSource: Bool
    let onWorkspaceReorderDragChanged: (CGPoint) -> Void
    let onWorkspaceReorderDragEnded: (CGPoint) -> Void
    @Binding var activeInUseOverrideWorkspaceName: String?
    let onBeginWorkspaceActivation: @MainActor (String) -> Void
    let actions: WorkspaceSidebarActions

    @State var isHovered = false
    @State var hoveredWindowId: UInt32? = nil
    @State var hoveredTabGroupId: UInt32? = nil
    @State var isDropTargeted = false
    @State var isDropSettling = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme

    let headerHeight: CGFloat = workspaceSidebarWorkspaceSectionHeaderHeight
    let rowHeight: CGFloat = workspaceSidebarWorkspaceRowHeight

    var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }
    var contentWidth: CGFloat { workspaceSidebarContentWidth(expansionProgress, layout: layout) }
    var sectionWidth: CGFloat { workspaceSidebarSectionWidth(expansionProgress, layout: layout) }
    var isCompact: Bool { expansionProgress < workspaceSidebarRowsRevealProgress }
    var showsWindowRows: Bool { !isCompact && workspace.items.count > 1 }
    var sectionMinHeight: CGFloat? {
        if !isCompact, allowsWorkspaceActivation, isInUseOnOtherDisplay, workspace.items.isEmpty {
            return workspaceSidebarInUseOverrideEmptySectionMinHeight
        }
        return nil
    }
    var isDropTarget: Bool { dragPreview?.targetWorkspaceName == workspace.name }
    var activeSidebarDragSourceWindowId: UInt32? { dragPreview?.sourceWindowId }
    var isShowingInUseOverlay: Bool { activeInUseOverrideWorkspaceName == workspace.name }
    var isSearchSelectedWorkspace: Bool { selectedSearchTarget == .workspace(workspace.name) }
    var isRenamingWorkspace: Bool { renamingWorkspaceName == workspace.name }
    var isVisuallyActiveOnTargetMonitor: Bool {
        isActiveOnTargetMonitor || isPendingActivationOnTargetMonitor
    }
    var inUseOverrideText: String {
        if let monitorName = workspace.monitorName, !monitorName.isEmpty {
            return "In use on \(monitorName)"
        }
        return "In use on another display"
    }
    var sectionShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: workspaceSidebarSectionCornerRadius, style: .continuous)
    }

    var body: some View {
        interactiveSectionContent
            .padding(.vertical, isCompact ? 3 : 0)
            .padding(.horizontal, workspaceSidebarSectionInnerHorizontalInset)
            .frame(width: sectionWidth, alignment: .leading)
            .frame(minHeight: sectionMinHeight, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .opacity(compactFocusOpacity * (isWorkspaceReorderSource ? 0.16 : 1))
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    debugWorkspaceSidebarRenameLog("workspaceContextRename workspace=\(workspace.name) displayName=\(workspace.displayName) compact=\(isCompact)")
                    onBeginRenameWorkspace()
                } label: {
                    Text("Rename Tab")
                }
                Divider()
                Button(role: .destructive) {
                    actions.send(.deleteWorkspace(workspace.name))
                } label: {
                    Text("Delete Tab")
                }
            }
            .onHover { hover in
                isHovered = hover
                actions.hoverWorkspace(workspace.name, hover)
            }
            .onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
                target: .workspace(workspace.name),
                actions: actions,
                performPayloadDrop: handlePayloadDrop,
                isTargeted: $isDropTargeted,
                isSettling: $isDropSettling,
            ))
            .help(isInUseOnOtherDisplay ? inUseOverrideText : workspace.displayName)
            .zIndex(isDropTarget ? 1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: dragPreview)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: expansionProgress)
            .animation(reduceMotion ? workspaceSidebarReducedMotionHoverAnimation : workspaceSidebarHoverAnimation, value: isHovered)
            .animation(reduceMotion ? workspaceSidebarReducedMotionHoverAnimation : workspaceSidebarHoverAnimation, value: hoveredWindowId)
            .animation(reduceMotion ? workspaceSidebarReducedMotionHoverAnimation : workspaceSidebarHoverAnimation, value: hoveredTabGroupId)
            .animation(reduceMotion ? workspaceSidebarReducedMotionHoverAnimation : workspaceSidebarHoverAnimation, value: isOnFocusedMonitor)
            .background {
                sectionBackground
            }
            .overlay(alignment: .center) {
                inUseOverrideOverlay
                    .opacity(allowsWorkspaceActivation && isShowingInUseOverlay ? 1 : 0)
                    .allowsHitTesting(allowsWorkspaceActivation && isShowingInUseOverlay)
                    .zIndex(5)
            }
            .shadow(
                color: isDropTarget ? palette.shadow(0.12, lightOpacity: 0.045) : .clear,
                radius: isDropTarget ? 5 : 0,
                x: 0,
                y: isDropTarget ? 2 : 0
            )
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: WorkspaceSidebarDropTargetPreferenceKey.self,
                        value: emitsDropTarget ? [WorkspaceSidebarDropTargetFrame(
                            kind: .workspace(workspace.name),
                            frame: geometry.frame(in: .named("workspaceSidebarContent")),
                        )] : [],
                    )
                    .preference(
                        key: WorkspaceSidebarWorkspaceReorderFramePreferenceKey.self,
                        value: [WorkspaceSidebarWorkspaceReorderFrame(
                            workspaceName: workspace.name,
                            projectId: workspace.projectId,
                            frame: geometry.frame(in: .named("workspaceSidebarContent")),
                            isReorderable: isWorkspaceReorderEnabled,
                        )]
                    )
                }
            }
    }
}
