import SwiftUI

struct WorkspaceSidebarTabGroupFolderSection: Identifiable, Equatable {
    let project: WorkspaceSidebarProjectViewModel
    let workspaces: [WorkspaceSidebarWorkspaceViewModel]

    var id: WorkspaceProjectId { project.id }
    var isDefault: Bool { project.id == workspaceProjectDefaultId }
}

func workspaceSidebarTabGroupFolderSections(
    projectId: WorkspaceProjectId,
    workspaces: [WorkspaceSidebarWorkspaceViewModel],
    projects: [WorkspaceSidebarProjectViewModel],
) -> [WorkspaceSidebarTabGroupFolderSection] {
    let projectById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    if projectId != workspaceProjectDefaultId {
        return [
            WorkspaceSidebarTabGroupFolderSection(
                project: projectById[projectId] ?? WorkspaceSidebarProjectViewModel(
                    id: projectId,
                    displayName: "Tab Group",
                    colorHex: nil,
                ),
                workspaces: workspaces,
            ),
        ]
    }

    var sections: [WorkspaceSidebarTabGroupFolderSection] = []
    var defaultWorkspaces: [WorkspaceSidebarWorkspaceViewModel] = []
    var groupedWorkspacesByProject: [WorkspaceProjectId: [WorkspaceSidebarWorkspaceViewModel]] = [:]
    for workspace in workspaces {
        if workspace.projectId == workspaceProjectDefaultId {
            defaultWorkspaces.append(workspace)
        } else {
            groupedWorkspacesByProject[workspace.projectId, default: []].append(workspace)
        }
    }

    let defaultProject = projectById[workspaceProjectDefaultId] ?? WorkspaceSidebarProjectViewModel(
        id: workspaceProjectDefaultId,
        displayName: "Tabs",
        colorHex: nil,
    )
    if !defaultWorkspaces.isEmpty {
        sections.append(WorkspaceSidebarTabGroupFolderSection(
            project: defaultProject,
            workspaces: defaultWorkspaces,
        ))
    }

    let orderedProjects = projects.filter { $0.id != workspaceProjectDefaultId }
    for project in orderedProjects {
        guard let groupedWorkspaces = groupedWorkspacesByProject.removeValue(forKey: project.id),
              !groupedWorkspaces.isEmpty
        else { continue }
        sections.append(WorkspaceSidebarTabGroupFolderSection(project: project, workspaces: groupedWorkspaces))
    }
    for projectId in groupedWorkspacesByProject.keys.sorted() {
        sections.append(WorkspaceSidebarTabGroupFolderSection(
            project: projectById[projectId] ?? WorkspaceSidebarProjectViewModel(
                id: projectId,
                displayName: "Tab Group",
                colorHex: nil,
            ),
            workspaces: groupedWorkspacesByProject[projectId] ?? [],
        ))
    }
    return sections
}

struct WorkspaceSidebarTabGroupFolder<Content: View>: View {
    let section: WorkspaceSidebarTabGroupFolderSection
    let expansionProgress: CGFloat
    let layout: WorkspaceSidebarConfiguration
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }
    private var sectionWidth: CGFloat { workspaceSidebarSectionWidth(expansionProgress, layout: layout) }
    private var groupColor: Color {
        workspaceSidebarProjectColor(projectId: section.project.id, configuredHex: section.project.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: onToggle) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9.5, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(palette.foreground(0.58))
                        .frame(width: 14, height: 18)
                    Circle()
                        .fill(groupColor.opacity(0.82))
                        .frame(width: 7, height: 7)
                    Text(section.project.displayName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(palette.foreground(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Text("\(section.workspaces.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.foreground(0.46))
                }
                .padding(.horizontal, 8)
                .frame(width: sectionWidth, height: 28, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                        .fill(isExpanded ? palette.selectedSurface() : Color.clear)
                }
                .overlay {
                    if isExpanded {
                        RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                            .strokeBorder(palette.border(0.62), lineWidth: 0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Hide tab group" : "Show tab group")

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: sectionWidth, alignment: .leading)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: isExpanded)
    }
}
