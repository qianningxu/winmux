import SwiftUI

extension WorkspaceSidebarProjectPopup {
    @ViewBuilder
    func projectContextMenuItems(for project: WorkspaceSidebarProjectViewModel) -> some View {
        Button("Rename Folder") {
            onRename(project)
        }
        if projectsAreEnabled() {
            Menu("Color") {
                Button("Auto") {
                    onSetColor(project, nil)
                }
                Divider()
                ForEach(workspaceSidebarProjectColorPresets) { preset in
                    Button(preset.name) {
                        onSetColor(project, preset.hex)
                    }
                }
            }
        }
        Button(role: .destructive) {
            onDelete(project)
        } label: {
            Text("Delete Folder")
        }
        .disabled(!canDeleteWorkspaceProject(project.id))
    }
}
