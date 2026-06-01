import AppKit
import SwiftUI

extension WindowTabStripView {
    func tabItem(
        _ tab: WindowTabItemViewModel,
        context: WindowTabStripLayoutContext,
        itemHeight: CGFloat,
    ) -> some View {
        let isHovered = hoveredTabId == tab.windowId
        return ZStack(alignment: .trailing) {
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

            if isHovered && draggingTabId == nil {
                tabCloseButton(tab)
                    .padding(.trailing, windowTabStripCloseButtonTrailingInset)
                    .transition(.opacity)
            }
        }
        .frame(width: context.tabWidth, height: itemHeight, alignment: .leading)
        .offset(x: tabVisualOffset(for: tab, context: context))
        .zIndex(draggingTabId == tab.windowId ? 1 : 0)
        .shadow(
            color: draggingTabId == tab.windowId ? Color.black.opacity(0.18) : Color.clear,
            radius: draggingTabId == tab.windowId ? 7 : 0,
            y: draggingTabId == tab.windowId ? 2 : 0,
        )
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: reorderTargetIndex(context: context))
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: trayModel.windowTabReentryPreview?.targetIndex)
        .animation(nil, value: trayModel.windowTabReentryPreview?.sourceVisualOffset)
        .highPriorityGesture(tabDragGesture(for: tab, context: context))
        .workspaceSidebarDrag(enabled: true) {
            WorkspaceSidebarDragPayload.window(tab.windowId).itemProvider
        }
        .onHover { hovering in
            updateHoveredTab(tab.windowId, hovering: hovering)
        }
        .contextMenu {
            Button("Close Tab") {
                closeWindowFromTabStrip(tab.windowId, fallbackWorkspace: tab.workspaceName)
            }
            Button("Remove Tab From Stack") {
                removeWindowFromTabStrip(tab.windowId, fallbackWorkspace: tab.workspaceName)
            }
        }
    }

    private func tabCloseButton(_ tab: WindowTabItemViewModel) -> some View {
        Button {
            closeWindowFromTabStrip(tab.windowId, fallbackWorkspace: tab.workspaceName)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(width: windowTabStripCloseButtonSize, height: windowTabStripCloseButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close \(tab.title)")
        .accessibilityLabel("Close \(tab.title)")
    }
}
