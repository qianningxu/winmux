import SwiftUI

struct WorkspaceSidebarFolderSection: Identifiable, Equatable {
    let project: WorkspaceSidebarProjectViewModel
    let workspaces: [WorkspaceSidebarWorkspaceViewModel]

    var id: WorkspaceProjectId { project.id }
    var isDefault: Bool { project.id == workspaceProjectDefaultId }
}

struct WorkspaceSidebarProjectReorderDropArea<Content: View>: View {
    let projectId: WorkspaceProjectId
    let isDropTarget: Bool
    let minimumHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(minHeight: minimumHeight, alignment: .topLeading)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: WorkspaceSidebarFolderReorderFramePreferenceKey.self,
                        value: [WorkspaceSidebarFolderReorderFrame(
                            projectId: projectId,
                            frame: geometry.frame(in: .named("workspaceSidebarContent")),
                            isDropTarget: isDropTarget,
                        )]
                    )
                }
            }
    }
}

func workspaceSidebarFolderSections(
    projectId: WorkspaceProjectId,
    workspaces: [WorkspaceSidebarWorkspaceViewModel],
    projects: [WorkspaceSidebarProjectViewModel],
) -> [WorkspaceSidebarFolderSection] {
    let projectById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    if projectId != workspaceProjectDefaultId {
        let visibleFolderWorkspaces = workspaceSidebarNonEmptyFolderWorkspaces(workspaces)
        guard !visibleFolderWorkspaces.isEmpty else { return [] }
        return [
            WorkspaceSidebarFolderSection(
                project: projectById[projectId] ?? WorkspaceSidebarProjectViewModel(
                    id: projectId,
                    displayName: "Folder",
                    colorHex: nil,
                ),
                workspaces: visibleFolderWorkspaces,
            ),
        ]
    }

    var sections: [WorkspaceSidebarFolderSection] = []
    var defaultWorkspaces: [WorkspaceSidebarWorkspaceViewModel] = []
    var folderWorkspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]] = [:]
    for workspace in workspaces {
        if workspace.projectId == workspaceProjectDefaultId {
            defaultWorkspaces.append(workspace)
        } else {
            folderWorkspacesByProject[workspace.projectId, default: []].append(workspace)
        }
    }

    let defaultProject = projectById[workspaceProjectDefaultId] ?? WorkspaceSidebarProjectViewModel(
        id: workspaceProjectDefaultId,
        displayName: "Tabs",
        colorHex: nil,
    )
    let visibleDefaultWorkspaces = workspaceSidebarNonEmptyFolderWorkspaces(defaultWorkspaces)
    if !visibleDefaultWorkspaces.isEmpty {
        sections.append(WorkspaceSidebarFolderSection(
            project: defaultProject,
            workspaces: visibleDefaultWorkspaces,
        ))
    }

    let orderedProjects = projects.filter { $0.id != workspaceProjectDefaultId }
    for project in orderedProjects {
        guard let folderWorkspaces = folderWorkspacesByProject.removeValue(forKey: project.id)
        else { continue }
        let visibleFolderWorkspaces = workspaceSidebarNonEmptyFolderWorkspaces(folderWorkspaces)
        guard !visibleFolderWorkspaces.isEmpty else { continue }
        sections.append(WorkspaceSidebarFolderSection(project: project, workspaces: visibleFolderWorkspaces))
    }
    for projectId in folderWorkspacesByProject.keys.sorted() {
        let visibleFolderWorkspaces = workspaceSidebarNonEmptyFolderWorkspaces(
            folderWorkspacesByProject[projectId] ?? []
        )
        guard !visibleFolderWorkspaces.isEmpty else { continue }
        sections.append(WorkspaceSidebarFolderSection(
            project: projectById[projectId] ?? WorkspaceSidebarProjectViewModel(
                id: projectId,
                displayName: "Folder",
                colorHex: nil,
            ),
            workspaces: visibleFolderWorkspaces,
        ))
    }
    return sections
}

func workspaceSidebarNonEmptyFolderWorkspaces(
    _ workspaces: [WorkspaceSidebarWorkspaceViewModel]
) -> [WorkspaceSidebarWorkspaceViewModel] {
    workspaces.filter { !$0.tabSummary.isEmpty || !$0.items.isEmpty }
}

struct WorkspaceSidebarFolder<Content: View>: View {
    let section: WorkspaceSidebarFolderSection
    let expansionProgress: CGFloat
    let layout: WorkspaceSidebarConfiguration
    let monitorScopeId: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDropPayload: @MainActor (WorkspaceSidebarDragPayload) -> Void
    let actions: WorkspaceSidebarActions
    let emitsDropTarget: Bool
    let dropPreview: WorkspaceSidebarDropPreviewViewModel?
    let isWorkspaceDragTargeted: Bool
    let isShowingProjectedContent: Bool
    let isFolderReorderEnabled: Bool
    let isFolderReorderSource: Bool
    @Binding var renamingProjectId: WorkspaceProjectId?
    @Binding var renamingProjectText: String
    let onBeginRenameProject: @MainActor (WorkspaceSidebarProjectViewModel) -> Void
    let onCommitRenameProject: @MainActor () -> Void
    let onCancelRenameProject: @MainActor () -> Void
    let onFolderReorderDragChanged: (CGPoint) -> Void
    let onFolderReorderDragEnded: (CGPoint) -> Void
    @ViewBuilder let content: () -> Content

    @State private var isDropTargeted = false
    @State private var isDropSettling = false
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }
    private var sectionWidth: CGFloat { workspaceSidebarSectionWidth(expansionProgress, layout: layout) }

    var body: some View {
        VStack(alignment: .leading, spacing: workspaceSidebarNestedRowSpacing) {
            folderHeader

            if showsFolderContent {
                if isExpanded || isShowingProjectedContent {
                    folderContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if isWorkspaceDragTargeted {
                    folderContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.vertical, showsFolderContent ? 4 : 0)
        .frame(width: sectionWidth, alignment: .leading)
        .background {
            GeometryReader { geometry in
                let frame = geometry.frame(in: .named("workspaceSidebarContent"))
                Color.clear
                    .preference(
                        key: WorkspaceSidebarDropTargetPreferenceKey.self,
                        value: emitsDropTarget ? [WorkspaceSidebarDropTargetFrame(
                            kind: .folder(section.project.id, monitorScopeId: monitorScopeId),
                            frame: frame,
                        )] : [],
                    )
                    .preference(
                        key: WorkspaceSidebarFolderReorderFramePreferenceKey.self,
                        value: [WorkspaceSidebarFolderReorderFrame(
                            projectId: section.project.id,
                            frame: frame,
                            isDropTarget: emitsDropTarget,
                        )]
                    )
            }
        }
        .background {
            RoundedRectangle(cornerRadius: workspaceSidebarSectionCornerRadius, style: .continuous)
                .fill(folderBlockFill)
        }
        .overlay {
            if showsFolderContent || isFolderInteractionActive {
                RoundedRectangle(cornerRadius: workspaceSidebarSectionCornerRadius, style: .continuous)
                    .strokeBorder(folderBlockBorder, lineWidth: isFolderTargeted ? 0.9 : 0.7)
            }
        }
        .shadow(
            color: folderBlockShadowColor,
            radius: folderBlockShadowRadius,
            x: 0,
            y: folderBlockShadowYOffset
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onDrop(of: [workspaceSidebarDragPayloadType], delegate: WorkspaceSidebarDropDelegate(
            target: .folder(section.project.id, monitorScopeId: monitorScopeId),
            actions: actions,
            performPayloadDrop: onDropPayload,
            isTargeted: $isDropTargeted,
            isSettling: $isDropSettling,
        ))
        .contextMenu {
            if workspaceSidebarFolderMutationIsEnabled(section.project.id) {
                Button("Rename Folder") {
                    onBeginRenameProject(section.project)
                }
                Button(role: .destructive) {
                    actions.send(.deleteProject(section.project.id))
                } label: {
                    Text("Delete Folder")
                }
                .disabled(!canDeleteWorkspaceProject(section.project.id))
            }
        }
        .modifier(WorkspaceSidebarProjectedDragAnchorModifier(isActive: isFolderReorderSource))
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: showsFolderContent)
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.86), value: isFolderInteractionActive)
    }

    private var isRenamingProject: Bool {
        renamingProjectId == section.project.id
    }

    private var folderHeader: some View {
        Group {
            if isRenamingProject {
                folderHeaderContent
            } else {
                Button(action: onToggle) {
                    folderHeaderContent
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: sectionWidth, height: workspaceSidebarWorkspaceSectionHeaderHeight, alignment: .leading)
        .contentShape(Rectangle())
        .modifier(WorkspaceSidebarWorkspaceReorderGestureModifier(
            isEnabled: isFolderReorderEnabled,
            onChanged: onFolderReorderDragChanged,
            onEnded: onFolderReorderDragEnded
        ))
        .help(isExpanded ? "Hide folder" : "Show folder")
    }

    private var folderHeaderContent: some View {
        HStack(spacing: workspaceSidebarHeaderSpacing) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.foreground(0.50))
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
            if isRenamingProject {
                WorkspaceSidebarProjectRenameField(
                    project: section.project,
                    text: $renamingProjectText,
                    onCommit: onCommitRenameProject,
                    onCancel: onCancelRenameProject,
                    showsPlate: false,
                    font: .systemFont(ofSize: 13.5, weight: .semibold),
                )
                .layoutPriority(1)
            } else {
                Text(section.project.displayName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.foreground(0.78))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(palette.foreground(0.54))
                    .frame(width: 10, height: 18)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, workspaceSidebarHeaderRowLeadingPadding)
        .padding(.trailing, workspaceSidebarRowHorizontalPadding)
        .frame(height: workspaceSidebarWorkspaceSectionHeaderHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var folderContent: some View {
        VStack(alignment: .leading, spacing: workspaceSidebarNestedRowSpacing) {
            content()
        }
        .padding(.top, 1)
        .padding(.bottom, 2)
        .frame(width: sectionWidth, alignment: .leading)
    }

    private var showsFolderContent: Bool {
        isExpanded || isWorkspaceDragTargeted || isShowingProjectedContent
    }

    private var isFolderTargeted: Bool {
        isDropTargeted || isWorkspaceDragTargeted || isShowingProjectedContent
    }

    private var isFolderInteractionActive: Bool {
        isFolderTargeted || isHovered
    }

    private var folderBlockFill: Color {
        if isFolderTargeted {
            return palette.contrastingFill(darkOpacity: 0.18, lightOpacity: 0.15)
        }
        if isHovered {
            return palette.contrastingFill(darkOpacity: 0.14, lightOpacity: 0.12)
        }
        return palette.contrastingFill(darkOpacity: 0.095, lightOpacity: 0.08)
    }

    private var folderBlockBorder: Color {
        if isFolderTargeted {
            return palette.tabStroke(active: true)
        }
        if isHovered {
            return palette.contrastingFill(darkOpacity: 0.18, lightOpacity: 0.16)
        }
        return palette.contrastingFill(darkOpacity: 0.10, lightOpacity: 0.12)
    }

    private var folderBlockShadowColor: Color {
        if isFolderTargeted {
            return palette.shadow(0.12, lightOpacity: 0.065)
        }
        guard isHovered else { return Color.clear }
        return palette.shadow(0.08, lightOpacity: 0.045)
    }

    private var folderBlockShadowRadius: CGFloat {
        isFolderTargeted ? 7 : (isHovered ? 5 : 0)
    }

    private var folderBlockShadowYOffset: CGFloat {
        isFolderTargeted ? 2 : (isHovered ? 1 : 0)
    }
}
