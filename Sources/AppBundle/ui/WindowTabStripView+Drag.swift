import AppKit
import SwiftUI

extension WindowTabStripView {
    func tabDragGesture(
        for tab: WindowTabItemViewModel,
        context: WindowTabStripLayoutContext,
    ) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(context.scrollCoordinateSpaceName))
            .onChanged { value in
                noteCurrentMousePointerSample()
                handleTabDragChanged(
                    tab: tab,
                    context: context,
                    translation: value.translation,
                    pointerXInViewport: value.location.x,
                )
            }
            .onEnded { _ in
                noteCurrentMousePointerSample()
                handleTabDragEnded(tab: tab, context: context)
            }
    }

    func handleTabDragChanged(
        tab: WindowTabItemViewModel,
        context: WindowTabStripLayoutContext,
        translation: CGSize,
        pointerXInViewport: CGFloat,
    ) {
        if shouldPromoteTabStripDragToGroup(windowId: tab.windowId) {
            clearTabDragState()
            updateMoveFromTabStrip(tab.windowId)
            return
        }
        if hasCommittedToDetach {
            tabAutoScrollDirection = nil
            updateDetachedTabFromTabStrip(tab.windowId)
            return
        }
        if abs(translation.height) > tabReorderVerticalEscapeThreshold, strip.tabs.count > 1 {
            hasCommittedToDetach = true
            draggingTabId = nil
            hoveredTabId = nil
            dragTranslationX = 0
            tabAutoScrollDirection = nil
            updateDetachedTabFromTabStrip(tab.windowId)
            return
        }
        draggingTabId = tab.windowId
        hoveredTabId = nil
        dragTranslationX = translation.width
        reorderPreviewTargetIndex = tabReorderTargetIndexForFrames(
            pointerXInViewport: pointerXInViewport,
            tabOrder: context.tabOrder,
            tabFramesById: tabFramesById,
            sourceIndex: draggingIndex(context: context),
        )
        updateTabAutoScroll(context: context, pointerXInViewport: pointerXInViewport)
    }

    func handleTabDragEnded(tab: WindowTabItemViewModel, context: WindowTabStripLayoutContext) {
        if shouldContinueCurrentGroupDrag(windowId: tab.windowId) {
            finishMoveFromTabStrip()
        } else if hasCommittedToDetach {
            hasCommittedToDetach = false
            Task { @MainActor in
                try? await resetManipulatedWithMouseIfPossible()
            }
        } else if let srcIdx = draggingIndex(context: context),
                  let tgtIdx = reorderPreviewTargetIndex,
                  srcIdx != tgtIdx {
            settleReorderedTab(
                windowId: tab.windowId,
                sourceIndex: srcIdx,
                targetIndex: tgtIdx,
                orderBeforeDrop: context.tabOrder,
            )
            reorderTabInStrip(tab.windowId, toIndex: tgtIdx)
            return
        }
        clearTabDragState()
    }

    func clearTabDragState() {
        draggingTabId = nil
        hoveredTabId = nil
        dragTranslationX = 0
        reorderPreviewTargetIndex = nil
        tabAutoScrollDirection = nil
        hasCommittedToDetach = false
    }
}
