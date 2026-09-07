import AppKit
import SwiftUI

struct WorkspaceSidebarHorizontalTabFrame: Equatable {
    let workspaceName: String
    let folderId: WorkspaceFolderId
    let frame: CGRect
}

struct WorkspaceSidebarHorizontalTabFramePreferenceKey: PreferenceKey {
    static let defaultValue: [WorkspaceSidebarHorizontalTabFrame] = []

    static func reduce(
        value: inout [WorkspaceSidebarHorizontalTabFrame],
        nextValue: () -> [WorkspaceSidebarHorizontalTabFrame]
    ) {
        value.append(contentsOf: nextValue())
    }
}

struct WorkspaceSidebarHorizontalReorderTarget: Equatable {
    let workspaceName: String
    let folderId: WorkspaceFolderId
    let placement: WorkspaceReorderPlacement
}

func workspaceSidebarHorizontalReorderTarget(
    sourceWorkspaceName: String,
    pointer: CGPoint,
    frames: [WorkspaceSidebarHorizontalTabFrame]
) -> WorkspaceSidebarHorizontalReorderTarget? {
    let orderedFrames = frames.sorted { $0.frame.minX < $1.frame.minX }
    guard let sourceIndex = orderedFrames.firstIndex(where: { $0.workspaceName == sourceWorkspaceName }) else {
        return nil
    }

    let candidates = orderedFrames.filter { $0.workspaceName != sourceWorkspaceName }
    if let containing = candidates.last(where: { $0.frame.contains(pointer) }) {
        return WorkspaceSidebarHorizontalReorderTarget(
            workspaceName: containing.workspaceName,
            folderId: containing.folderId,
            placement: pointer.x < containing.frame.midX
                ? .before(containing.workspaceName)
                : .after(containing.workspaceName),
        )
    }

    let insertionIndex = orderedFrames.firstIndex { pointer.x < $0.frame.midX } ?? orderedFrames.count
    let destinationIndex = insertionIndex > sourceIndex ? insertionIndex - 1 : insertionIndex
    guard orderedFrames.indices.contains(destinationIndex), destinationIndex != sourceIndex else {
        return nil
    }

    let target = orderedFrames[destinationIndex]
    return WorkspaceSidebarHorizontalReorderTarget(
        workspaceName: target.workspaceName,
        folderId: target.folderId,
        placement: destinationIndex < sourceIndex
            ? .before(target.workspaceName)
            : .after(target.workspaceName),
    )
}

func workspaceSidebarHorizontalVisibleWorkspaces(
    in snapshot: WorkspaceSidebarSnapshot
) -> [WorkspaceSidebarWorkspaceViewModel] {
    workspaceSidebarVisibleWorkspacesByProject(
        workspaces: snapshot.workspaces,
        selectedScopeId: snapshot.selectedMonitorScopeId,
        focusedMonitorScopeId: snapshot.focusedMonitorScopeId,
        targetMonitorScopeId: snapshot.targetMonitorScopeId,
        browsedProjectId: nil,
        projectsEnabled: true,
    )[snapshot.activeProjectId] ?? []
}

func workspaceSidebarHorizontalProjectPopupHeight(
    projectCount: Int,
    showsCreateAction: Bool = true
) -> CGFloat {
    let rowCount = max(projectCount, 0) + (showsCreateAction ? 1 : 0)
    guard rowCount > 0 else { return standardGap * 4 }
    let rowSpacing = CGFloat(max(rowCount - 1, 0)) * standardGap * 0.5
    let dividerHeight = showsCreateAction ? 0.5 + standardGap : 0
    return CGFloat(rowCount) * workspaceSidebarProjectPopupRowHeight + rowSpacing + dividerHeight + standardGap * 4
}

struct WorkspaceSidebarHorizontalBar: View {
    let snapshot: WorkspaceSidebarSnapshot
    let actions: WorkspaceSidebarActions

    @State private var renamingProjectId: WorkspaceProjectId?
    @State private var renamingProjectText = ""
    @State private var renamingWorkspaceName: String?
    @State private var renamingWorkspaceText = ""
    @State private var activeInUseOverrideWorkspaceName: String?
    @State private var hoveredWorkspaceName: String?
    @State private var workspaceReorderFrames: [WorkspaceSidebarHorizontalTabFrame] = []
    @StateObject private var workspaceDragDriver = WorkspaceSidebarWorkspaceReorderDriver()
    @State private var workspaceReorderSourceName: String?
    @State private var workspaceReorderTarget: WorkspaceSidebarHorizontalReorderTarget?

    @Environment(\.colorScheme) private var colorScheme

    private var activeProject: WorkspaceSidebarProjectViewModel? {
        snapshot.projects.first { $0.id == snapshot.activeProjectId }
            ?? snapshot.projects.first
    }

    private var projectWorkspaces: [WorkspaceSidebarWorkspaceViewModel] {
        workspaceSidebarHorizontalVisibleWorkspaces(in: snapshot)
    }

    private var palette: WinMuxOverlayPalette {
        WinMuxOverlayPalette(
            colorScheme: colorScheme,
            projectThemeFamily: workspaceSidebarProjectThemeFamily(
                projects: snapshot.projects,
                activeProjectId: snapshot.activeProjectId,
            ),
        )
    }

    private var currentPanel: WorkspaceSidebarPanel? {
        WorkspaceSidebarPanel.panel(for: snapshot.targetMonitorScopeId)
    }

    var body: some View {
        GeometryReader { geometry in
            let surfaceHeight = max(geometry.size.height - menuBarContentTopInset, 1)
            let contentHeight = surfaceHeight
            let surfaceWidth = max(geometry.size.width - menuBarSurfaceHorizontalInset * 2, 1)

            ZStack(alignment: .topLeading) {
                barSurface
                    .frame(height: surfaceHeight, alignment: .top)

                HStack(spacing: 0) {
                    projectControl(contentHeight: contentHeight)

                    WinMuxBarDivider(height: contentHeight * 0.5, palette: palette)

                    workspaceTabStrip(contentHeight: contentHeight)
                }
                .frame(width: surfaceWidth, height: surfaceHeight, alignment: .center)
            }
            .winMuxBarSurface(palette, cornerStyle: .circular, cornerRadius: WinMuxBarStyle.topBarCornerRadius)
            .padding(.horizontal, menuBarSurfaceHorizontalInset)
            .padding(.top, menuBarContentTopInset)
            .coordinateSpace(name: "workspaceSidebarContent")
            .onPreferenceChange(WorkspaceSidebarHorizontalTabFramePreferenceKey.self) { frames in
                workspaceReorderFrames = frames
            }
            .onPreferenceChange(WorkspaceSidebarDropTargetPreferenceKey.self) { frames in
                actions.setDropTargets(frames)
            }
            .onAppear {
                actions.setDropTargets([])
            }
        }
        .background(WinMuxDesignTokens.transparent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
        .onDisappear { clearWorkspaceReorderState() }
        .environment(\.workspaceSidebarProjectThemeFamily, workspaceSidebarProjectThemeFamily(
            projects: snapshot.projects,
            activeProjectId: snapshot.activeProjectId,
        ))
        .onChange(of: snapshot.activeProjectId) { _ in
            finishProjectRename(cancelled: true)
            finishWorkspaceRename(cancelled: true)
            activeInUseOverrideWorkspaceName = nil
            clearWorkspaceReorderState()
        }
        .onChange(of: snapshot.projects) { projects in
            if let renamingProjectId,
               !projects.contains(where: { $0.id == renamingProjectId })
            {
                finishProjectRename(cancelled: true)
            }
        }
        .onChange(of: snapshot.workspaces) { _ in
            if let renamingWorkspaceName,
               !snapshot.workspaces.contains(where: { $0.name == renamingWorkspaceName })
            {
                finishWorkspaceRename(cancelled: true)
            }
        }
    }

    private var barSurface: some View {
        Rectangle().fill(palette.color(.gray, .color5))
    }

    @ViewBuilder
    private func projectControl(contentHeight: CGFloat) -> some View {
        let project = activeProject
        let name = project?.displayName ?? "Main"
        let textWidth = (name as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: workspaceSidebarProjectLabelFontSize, weight: .semibold)
        ]).width
        let controlWidth = min(max(ceil(textWidth) + standardGap * 11.5, standardGap * 23), standardGap * 34)

        if let renamingProjectId,
           let renamingProject = snapshot.projects.first(where: { $0.id == renamingProjectId }) {
            WorkspaceSidebarProjectRenameField(
                project: renamingProject,
                text: $renamingProjectText,
                onCommit: { finishProjectRename() },
                onCancel: { finishProjectRename(cancelled: true) },
                showsPlate: false,
                font: .systemFont(ofSize: workspaceSidebarProjectLabelFontSize, weight: .semibold)
            )
            .frame(width: controlWidth, height: contentHeight)
        } else {
            Menu {
                ForEach(snapshot.projects) { project in
                    Menu {
                        Button("Switch Theme") {
                            toggleWorkspaceSidebarAppearance()
                        }
                        if projectsAreEnabled() {
                            Divider()
                            projectActions(for: project)
                        }
                    } label: {
                        if project.id == snapshot.activeProjectId {
                            Label(project.displayName, systemImage: "checkmark")
                        } else {
                            Text(project.displayName)
                        }
                    } primaryAction: {
                        actions.send(.selectProject(project.id))
                    }
                }
                if projectsAreEnabled() {
                    Divider()
                    Button("New Project") {
                        actions.send(.createProject(displayName: nil))
                    }
                }
            } label: {
                HStack(spacing: standardGap * 1.5) {
                    Text(name)
                        .font(.system(size: workspaceSidebarProjectLabelFontSize, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .foregroundStyle(palette.content(.primary))
                .frame(width: max(controlWidth - WinMuxBarStyle.contentInset * 2, 0), height: contentHeight)
                .padding(.horizontal, WinMuxBarStyle.contentInset)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .layoutPriority(1)
            .help("Switch Project")
            .accessibilityLabel("Project: \(name)")
        }
    }

    @ViewBuilder
    private func projectActions(for project: WorkspaceSidebarProjectViewModel) -> some View {
        Button("Rename Project") {
            beginProjectRename(project)
        }
        Menu("Project Color") {
            Button("Automatic") { actions.send(.setProjectColor(project.id, colorHex: nil)) }
            ForEach(workspaceSidebarProjectColorPresets) { preset in
                Button(preset.name) { actions.send(.setProjectColor(project.id, colorHex: preset.hex)) }
            }
        }
        Button("Delete Project", role: .destructive) {
            actions.send(.deleteProject(project.id))
        }
        .disabled(!canDeleteWorkspaceProject(project.id))
    }

    private func workspaceTabStrip(contentHeight: CGFloat) -> some View {
        GeometryReader { geometry in
            let count = projectWorkspaces.count
            let spacing = min(standardGap, geometry.size.width / CGFloat(max(count, 1)))
            let tabWidth = max(0, (geometry.size.width - spacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1)))
            HStack(spacing: spacing) {
                ForEach(Array(projectWorkspaces.enumerated()), id: \.element.id) { index, workspace in
                    workspaceTab(workspace, contentHeight: contentHeight)
                        .frame(width: tabWidth, height: contentHeight)
                        .clipped()
                        .overlay(alignment: .trailing) {
                            if index + 1 < count,
                               !(workspace.isVisible && workspace.monitorScopeId == snapshot.targetMonitorScopeId),
                               !(projectWorkspaces[index + 1].isVisible && projectWorkspaces[index + 1].monitorScopeId == snapshot.targetMonitorScopeId) {
                                WinMuxBarDivider(height: contentHeight * 0.5, palette: palette)
                                    .offset(x: spacing / 2)
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: contentHeight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: contentHeight)
    }

    private func workspaceTab(
        _ workspace: WorkspaceSidebarWorkspaceViewModel,
        contentHeight: CGFloat,
    ) -> some View {
        let isActive = workspace.isVisible && workspace.monitorScopeId == snapshot.targetMonitorScopeId
        let isInUseOnOtherDisplay = workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
            workspace,
            selectedScopeId: snapshot.targetMonitorScopeId,
        )
        let isDropTarget = snapshot.dropPreview?.targetWorkspaceName == workspace.name
        let isReorderTarget = workspaceReorderTarget?.workspaceName == workspace.name
        let isReorderSource = workspaceReorderSourceName == workspace.name

        return WorkspaceSidebarHorizontalWorkspaceTab(
            workspace: workspace,
            contentHeight: contentHeight,
            isActive: isActive,
            isInUseOnOtherDisplay: isInUseOnOtherDisplay,
            isDropTarget: isDropTarget,
            isReorderTarget: isReorderTarget,
            isReorderSource: isReorderSource,
            isRenaming: renamingWorkspaceName == workspace.name,
            renamingText: $renamingWorkspaceText,
            activeInUseOverrideWorkspaceName: $activeInUseOverrideWorkspaceName,
            hoveredWorkspaceName: $hoveredWorkspaceName,
            actions: actions,
            onSelect: {
                selectWorkspace(workspace)
            },
            onBeginRename: {
                beginWorkspaceRename(workspace)
            },
            onCommitRename: {
                finishWorkspaceRename()
            },
            onCancelRename: {
                finishWorkspaceRename(cancelled: true)
            },
            onClose: {
                actions.send(.closeWorkspace(workspace.name))
            },
            onReorderChanged: { pointer in
                updateWorkspaceReorder(workspace, pointer: pointer)
            },
            onReorderEnded: { _ in
                finishWorkspaceReorder(workspace)
            },
        )
        .background {
            GeometryReader { geometry in
                WinMuxDesignTokens.transparent.preference(
                    key: WorkspaceSidebarHorizontalTabFramePreferenceKey.self,
                    value: [WorkspaceSidebarHorizontalTabFrame(
                        workspaceName: workspace.name,
                        folderId: workspace.folderId,
                        frame: geometry.frame(in: .named("workspaceSidebarContent")),
                    )],
                )
                .preference(
                    key: WorkspaceSidebarDropTargetPreferenceKey.self,
                    value: [WorkspaceSidebarDropTargetFrame(
                        kind: .workspace(workspace.name),
                        frame: geometry.frame(in: .named("workspaceSidebarContent")),
                    )],
                )
            }
        }
        .frame(height: contentHeight)
    }

    private func selectWorkspace(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
        guard shouldHandleWorkspaceSidebarActivation(
            isEditing: renamingWorkspaceName != nil || renamingProjectId != nil,
            isSidebarDragInProgress: isWorkspaceSidebarDragInProgress(),
        ) else { return }
        if workspaceSidebarWorkspaceIsInUseOnOtherDisplay(
            workspace,
            selectedScopeId: snapshot.targetMonitorScopeId,
        ) {
            activeInUseOverrideWorkspaceName = workspace.name
            return
        }
        activeInUseOverrideWorkspaceName = nil
        actions.send(.selectWorkspace(workspace.name))
    }

    private func beginProjectRename(_ project: WorkspaceSidebarProjectViewModel) {
        finishWorkspaceRename(cancelled: true)
        renamingProjectId = project.id
        renamingProjectText = project.displayName
        currentPanel?.prepareForInlineTextEditing()
    }

    private func finishProjectRename(cancelled: Bool = false) {
        guard let projectId = renamingProjectId else { return }
        let displayName = renamingProjectText.trimmingCharacters(in: .whitespacesAndNewlines)
        renamingProjectId = nil
        renamingProjectText = ""
        currentPanel?.endInlineTextEditing()
        guard !cancelled, !displayName.isEmpty else { return }
        actions.send(.renameProject(projectId, displayName: displayName))
    }

    private func beginWorkspaceRename(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
        finishProjectRename(cancelled: true)
        renamingWorkspaceName = workspace.name
        renamingWorkspaceText = workspace.displayName
        currentPanel?.prepareForInlineTextEditing()
    }

    private func finishWorkspaceRename(cancelled: Bool = false) {
        guard let workspaceName = renamingWorkspaceName else { return }
        let displayName = renamingWorkspaceText.trimmingCharacters(in: .whitespacesAndNewlines)
        renamingWorkspaceName = nil
        renamingWorkspaceText = ""
        currentPanel?.endInlineTextEditing()
        guard !cancelled, !displayName.isEmpty else { return }
        actions.send(.renameWorkspace(workspaceName, displayName: displayName))
    }

    private func updateWorkspaceReorder(
        _ workspace: WorkspaceSidebarWorkspaceViewModel,
        pointer: CGPoint,
    ) {
        guard renamingWorkspaceName == nil, renamingProjectId == nil else { return }
        if workspaceReorderSourceName == nil {
            workspaceReorderSourceName = workspace.name
            beginWorkspaceSidebarItemDrag()
            workspaceDragDriver.start(
                sourceWorkspaceName: workspace.name,
                projectId: workspace.projectId,
                onTick: { updateWorkspaceDragFromScreen(workspace) },
                onPointer: { _ in updateWorkspaceDragFromScreen(workspace) },
                onFinish: { finishWorkspaceReorder(workspace) }
            )
        }
        let screenPoint = normalizeAppKitScreenPoint(NSEvent.mouseLocation)
        guard currentPanel?.frame.contains(NSEvent.mouseLocation) == true else {
            workspaceReorderTarget = nil
            if let intent = workspaceCanvasDropIntent(sourceWorkspaceName: workspace.name, screenPoint: screenPoint) {
                WindowDropIntentOverlayPanelController.shared.show(intent.overlay)
            } else {
                WindowDropIntentOverlayPanelController.shared.hide()
            }
            return
        }
        WindowDropIntentOverlayPanelController.shared.hide()
        workspaceReorderTarget = workspaceSidebarHorizontalReorderTarget(
            sourceWorkspaceName: workspace.name,
            pointer: pointer,
            frames: workspaceReorderFrames,
        )
    }

    private func updateWorkspaceDragFromScreen(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
        guard workspaceReorderSourceName == workspace.name,
              let pointer = currentPanel?.convertScreenPointToSidebarContentPoint(NSEvent.mouseLocation)
        else { return }
        updateWorkspaceReorder(workspace, pointer: pointer)
    }

    private func finishWorkspaceReorder(_ workspace: WorkspaceSidebarWorkspaceViewModel) {
        guard workspaceReorderSourceName == workspace.name else { return }
        defer { clearWorkspaceReorderState() }
        let screenPoint = normalizeAppKitScreenPoint(NSEvent.mouseLocation)
        if currentPanel?.frame.contains(NSEvent.mouseLocation) != true {
            guard let intent = workspaceCanvasDropIntent(sourceWorkspaceName: workspace.name, screenPoint: screenPoint),
                  let action = intent.action else { return }
            switch action {
                case .tabStack(let targetWindowId):
                    mergeWorkspaceIntoActiveTabGroupFromSidebarIfPossible(
                        sourceWorkspaceName: workspace.name, pointer: screenPoint, targetWindowId: targetWindowId
                    )
                case .split(let position):
                    mergeWorkspaceIntoActiveViewFromSidebarIfPossible(
                        sourceWorkspaceName: workspace.name, pointer: screenPoint, position: position
                    )
            }
            return
        }
        guard let target = workspaceReorderTarget,
              target.workspaceName != workspace.name
        else { return }
        actions.send(.reorderWorkspace(
            workspace.name,
            folderId: target.folderId,
            placement: target.placement,
        ))
    }

    private func clearWorkspaceReorderState() {
        workspaceDragDriver.stop()
        WindowDropIntentOverlayPanelController.shared.hide()
        if workspaceReorderSourceName != nil { endWorkspaceSidebarItemDrag() }
        workspaceReorderSourceName = nil
        workspaceReorderTarget = nil
    }
}

private struct WorkspaceSidebarHorizontalWorkspaceTab: View {
    let workspace: WorkspaceSidebarWorkspaceViewModel
    let contentHeight: CGFloat
    let isActive: Bool
    let isInUseOnOtherDisplay: Bool
    let isDropTarget: Bool
    let isReorderTarget: Bool
    let isReorderSource: Bool
    let isRenaming: Bool
    @Binding var renamingText: String
    @Binding var activeInUseOverrideWorkspaceName: String?
    @Binding var hoveredWorkspaceName: String?
    let actions: WorkspaceSidebarActions
    let onSelect: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onClose: () -> Void
    let onReorderChanged: (CGPoint) -> Void
    let onReorderEnded: (CGPoint) -> Void

    @State private var isDropTargeted = false
    @State private var isDropSettling = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.workspaceSidebarProjectThemeFamily) private var projectThemeFamily

    private var palette: WinMuxOverlayPalette {
        WinMuxOverlayPalette(colorScheme: colorScheme, projectThemeFamily: projectThemeFamily)
    }

    private var isHovered: Bool {
        hoveredWorkspaceName == workspace.name
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if isRenaming {
                WorkspaceSidebarWorkspaceRenameField(
                    text: $renamingText,
                    workspaceName: workspace.name,
                    onCommit: onCommitRename,
                    onCancel: onCancelRename,
                    font: .systemFont(ofSize: 12.5, weight: .medium),
                )
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            } else {
                Button(action: onSelect) {
                    HStack(spacing: WinMuxBarStyle.iconSpacing) {
                        workspaceIcon
                        Text(workspace.displayName)
                            .font(.system(size: WinMuxBarStyle.fontSize, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(palette.content(isActive ? .primary : .secondary))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, WinMuxBarStyle.contentInset)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: contentHeight,
                        maxHeight: contentHeight,
                        alignment: .leading,
                    )
                    .winMuxBarSegment(
                        palette,
                        isSelected: isActive || isDropTarget || isReorderTarget || isReorderSource,
                        isHovered: isHovered
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WinMuxBarStyle.topBarCornerRadius, style: .circular))
                    .overlay {
                        if isActive {
                            RoundedRectangle(cornerRadius: WinMuxBarStyle.topBarCornerRadius, style: .circular)
                                .strokeBorder(palette.color(.gray, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isHovered && !isRenaming && workspace.tabSummary.windowCount > 0 {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(palette.content(.secondary))
                        .frame(width: workspaceSidebarWindowCloseButtonSize, height: workspaceSidebarWindowCloseButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredWorkspaceName = hovering ? workspace.name : nil
            actions.hoverWorkspace(workspace.name, hovering)
        }
        .contextMenu {
            Button("Rename Tab", action: onBeginRename)
            Divider()
            Button(role: .destructive, action: onClose) {
                Text("Close Tab")
            }
        }
        .modifier(WorkspaceSidebarWorkspaceReorderGestureModifier(
            isEnabled: !isRenaming,
            onChanged: onReorderChanged,
            onEnded: onReorderEnded,
        ))
        .onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
            target: .workspace(workspace.name),
            actions: actions,
            performPayloadDrop: handlePayloadDrop,
            isTargeted: $isDropTargeted,
            isSettling: $isDropSettling,
        ))
        .overlay {
            if activeInUseOverrideWorkspaceName == workspace.name {
                WorkspaceSidebarInUseOverrideOverlay(text: inUseOverrideText) {
                    activeInUseOverrideWorkspaceName = nil
                    actions.send(.overrideWorkspaceInUse(workspace.name))
                }
            }
        }
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }

    @ViewBuilder
    private var workspaceIcon: some View {
        if let icon = appIconImage(
            bundleIdentifier: workspace.tabSummary.appBundleId,
            bundlePath: workspace.tabSummary.appBundlePath,
        ) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                .cornerRadius(4)
        } else {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.content(.secondary))
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
        }
    }

    private var inUseOverrideText: String {
        if let monitorName = workspace.monitorName, !monitorName.isEmpty {
            return "In use on \(monitorName)"
        }
        return "In use on another display"
    }

    private func handlePayloadDrop(_ payload: WorkspaceSidebarDragPayload) {
        guard workspaceSidebarPayloadSourceWorkspaceName(payload) != workspace.name else {
            actions.send(.clearDropPreview)
            WindowDragCursorProxyPanel.shared.hide()
            return
        }
        switch payload {
            case .window(let windowId):
                actions.send(.moveWindow(windowId, toWorkspace: workspace.name))
            case .tabGroup(let representativeWindowId):
                actions.send(.moveTabGroup(representativeWindowId, toWorkspace: workspace.name))
        }
    }
}

