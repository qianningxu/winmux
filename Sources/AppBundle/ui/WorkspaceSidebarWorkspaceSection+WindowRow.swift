import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    func workspaceWindowButton(
        _ window: WorkspaceSidebarWindowViewModel,
        allowsDrag: Bool,
        subject: WindowDragSubject = .window,
        leadingHitInset: CGFloat = 0,
    ) -> some View {
        let isRowHovered = hoveredWindowId == window.windowId || selectedSearchTarget == .window(window.windowId)
        return ZStack(alignment: .trailing) {
            Button {
                guard allowsWorkspaceActivation else { return }
                guard shouldHandleWorkspaceSidebarActivation(isEditing: false, isSidebarDragInProgress: isWorkspaceSidebarDragInProgress()) else { return }
                if isInUseOnOtherDisplay {
                    activeInUseOverrideWorkspaceName = workspace.name
                    return
                }
                activeInUseOverrideWorkspaceName = nil
                actions.send(.selectWindow(window.windowId))
            } label: {
                WorkspaceSidebarWindowRow(
                    title: window.title ?? window.appName,
                    badge: nil,
                    isFocused: window.isFocused,
                    suppressFocusedStyle: isSearchFiltering,
                    rowHeight: rowHeight,
                    isHovered: isRowHovered,
                    style: leadingHitInset > 0 ? .tabGroupChild : .window,
                    appBundleIds: [window.appBundleId],
                    appBundlePaths: [window.appBundlePath],
                    reservesCloseButtonSpace: true,
                )
                .padding(.leading, leadingHitInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .modifier(WorkspaceSidebarOptionalDragModifier(
                isEnabled: allowsDrag,
                onChanged: { pointer in
                    if subject == .group {
                        actions.tabGroupDragChanged(window.windowId, pointer)
                    } else {
                        actions.windowDragChanged(window.windowId, pointer)
                    }
                },
                onEnded: { pointer in
                    if subject == .group {
                        actions.tabGroupDragEnded(window.windowId, pointer)
                    } else {
                        actions.windowDragEnded(window.windowId, pointer)
                    }
                },
            ))
            .workspaceSidebarDrag(enabled: allowsDrag) {
                WorkspaceSidebarDragPayload.window(window.windowId).itemProvider
            }

            workspaceWindowCloseButton(window, isEmphasized: isRowHovered || window.isFocused)
                .padding(.trailing, workspaceSidebarWindowCloseButtonTrailingInset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hover in
            hoveredWindowId = nextWorkspaceSidebarHoveredWindowId(
                currentHoveredWindowId: hoveredWindowId,
                windowId: window.windowId,
                isHovering: hover,
            )
        }
        .opacity(1)
        .animation(.spring(response: 0.2, dampingFraction: 0.78), value: activeSidebarDragSourceWindowId == window.windowId)
    }

    private func workspaceWindowCloseButton(
        _ window: WorkspaceSidebarWindowViewModel,
        isEmphasized: Bool,
    ) -> some View {
        Button {
            actions.send(.closeWindow(window.windowId))
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(isEmphasized ? 0.78 : 0.42))
                .frame(width: workspaceSidebarWindowCloseButtonSize, height: workspaceSidebarWindowCloseButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close \(window.title ?? window.appName)")
        .accessibilityLabel("Close \(window.title ?? window.appName)")
    }
}
