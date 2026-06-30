import AppKit
import SwiftUI

extension WindowTabStripView {
    func tabItem(
        _ tab: WindowTabItemViewModel,
        context: WindowTabStripLayoutContext,
        itemHeight: CGFloat,
    ) -> some View {
        let isHovered = hoveredTabId == tab.windowId
        let isEditing = editingTabId == tab.windowId
        return ZStack(alignment: .trailing) {
            if isEditing {
                tabRenameEditor(tab, context: context, itemHeight: itemHeight)
            } else {
                tabButton(tab, context: context, itemHeight: itemHeight, isHovered: isHovered)
            }

            if isHovered && draggingTabId == nil && !isEditing {
                tabCloseButton(tab)
                    .padding(.trailing, windowTabStripCloseButtonTrailingInset)
                    .transition(.opacity)
            }
        }
        .frame(width: context.tabWidth, height: itemHeight, alignment: .leading)
        .offset(x: tabVisualOffset(for: tab, context: context))
        .zIndex(draggingTabId == tab.windowId || isEditing ? 1 : 0)
        .shadow(
            color: draggingTabId == tab.windowId ? winMuxOverlayShadow(darkOpacity: 0.18, lightOpacity: 0.12) : Color.clear,
            radius: draggingTabId == tab.windowId ? 7 : 0,
            y: draggingTabId == tab.windowId ? 2 : 0,
        )
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: reorderTargetIndex(context: context))
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: trayModel.windowTabReentryPreview?.targetIndex)
        .animation(nil, value: trayModel.windowTabReentryPreview?.sourceVisualOffset)
        .onHover { hovering in
            updateHoveredTab(tab.windowId, hovering: hovering)
        }
        .contextMenu {
            Button("Rename Tab") {
                beginRenamingTab(tab)
            }
            Button("Close Tab") {
                closeWindowFromTabStrip(tab.windowId, fallbackWorkspace: tab.workspaceName)
            }
            Button("Move Window Out") {
                removeWindowFromTabStrip(tab.windowId, fallbackWorkspace: tab.workspaceName)
            }
        }
    }

    private func tabButton(
        _ tab: WindowTabItemViewModel,
        context: WindowTabStripLayoutContext,
        itemHeight: CGFloat,
        isHovered: Bool,
    ) -> some View {
        Button {
            guard !isWindowTabStripDragInProgress() else { return }
            focusWindowFromTabStripClick(tab.windowId, fallbackWorkspace: tab.workspaceName)
        } label: {
            WindowTabItemView(
                tab: tab,
                width: context.tabWidth,
                height: itemHeight,
                isDragSource: draggingTabId == tab.windowId,
                isHovered: isHovered,
                reservesCloseButtonSpace: true
            )
        }
        .buttonStyle(.plain)
        .highPriorityGesture(tabDragGesture(for: tab, context: context))
        .onTapGesture(count: 2) {
            beginRenamingTab(tab)
        }
    }

    private func tabRenameEditor(
        _ tab: WindowTabItemViewModel,
        context: WindowTabStripLayoutContext,
        itemHeight: CGFloat,
    ) -> some View {
        ZStack(alignment: .leading) {
            WindowTabItemView(
                tab: tab,
                width: context.tabWidth,
                height: itemHeight,
                isDragSource: false,
                isHovered: true,
                reservesCloseButtonSpace: false
            )
            WindowTabRenameTextField(
                text: $editingTabTitle,
                onCommit: { commitRenamingTab(tab) },
                onCancel: cancelRenamingTab,
            )
            .padding(.leading, 30)
            .padding(.trailing, 10)
            .frame(width: context.tabWidth, height: itemHeight, alignment: .leading)
        }
    }

    func beginRenamingTab(_ tab: WindowTabItemViewModel) {
        guard !isWindowTabStripDragInProgress(), draggingTabId == nil else { return }
        editingTabId = tab.windowId
        editingTabTitle = tab.title
    }

    func commitRenamingTab(_ tab: WindowTabItemViewModel) {
        let nextTitle = editingTabTitle
        editingTabId = nil
        editingTabTitle = ""
        renameWindowTabFromTabStrip(tab.windowId, displayName: nextTitle, fallbackWorkspace: tab.workspaceName)
    }

    func cancelRenamingTab() {
        editingTabId = nil
        editingTabTitle = ""
    }

    private func tabCloseButton(_ tab: WindowTabItemViewModel) -> some View {
        Button {
            closeWindowFromTabStrip(tab.windowId, fallbackWorkspace: tab.workspaceName)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(winMuxOverlayForeground(0.78))
                .frame(width: windowTabStripCloseButtonSize, height: windowTabStripCloseButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close \(tab.title)")
        .accessibilityLabel("Close \(tab.title)")
    }
}
