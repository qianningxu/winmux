import SwiftUI

struct WorkspaceSidebarWidgetStack: View {
    let widgets: [WorkspaceSidebarWidgetConfig]
    let sectionWidth: CGFloat
    let isCompact: Bool

    private var enabledWidgets: [WorkspaceSidebarWidgetConfig] {
        widgets.filter(\.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(enabledWidgets, id: \.id) { widget in
                switch widget.type {
                    case .builtInTimeDate:
                        WorkspaceSidebarTimeDateWidget(
                            id: widget.id,
                            sectionWidth: sectionWidth,
                            isCompact: isCompact,
                            showsDate: widget.showDate,
                        )
                    case .builtInTogglProjects:
                        WorkspaceSidebarTogglProjectsWidget(
                            id: widget.id,
                            sectionWidth: sectionWidth,
                            isCompact: isCompact,
                            entriesPath: widget.entriesPath ?? defaultWorkspaceSidebarTogglEntriesPath,
                            days: widget.days ?? defaultWorkspaceSidebarTogglDays,
                        )
                    case .builtInSpendingCategories:
                        WorkspaceSidebarSpendingCategoriesWidget(
                            id: widget.id,
                            sectionWidth: sectionWidth,
                            isCompact: isCompact,
                            entriesPath: widget.entriesPath ?? defaultWorkspaceSidebarSpendingEntriesPath,
                            days: widget.days ?? defaultWorkspaceSidebarSpendingDays,
                        )
                    case .plugin:
                        WorkspaceSidebarPluginWidget(
                            config: widget,
                            sectionWidth: sectionWidth,
                            isCompact: isCompact,
                        )
                }
            }
        }
        .frame(width: sectionWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.16), value: isCompact)
    }
}
