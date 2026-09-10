import AppKit
import SwiftUI

extension WindowTabStripView {
    func tabStripBody(stripWidth: CGFloat, stripHeight: CGFloat) -> some View {
        let context = WindowTabStripLayoutContext(strip: strip, width: stripWidth)
        let itemHeight = max(stripHeight - WinMuxSpacing.compact * 2, 18)
        let activeWindowId = strip.tabs.first(where: \.isActive)?.windowId
        let groupDragWindowId = activeWindowId ?? strip.tabs.first?.windowId

        return HStack(spacing: 0) {
            tabScrollView(
                context: context,
                itemHeight: itemHeight,
                groupDragWindowId: groupDragWindowId,
            )
                .frame(maxWidth: .infinity)
                .frame(height: itemHeight, alignment: .top)


        }
        // Keep the interactive row within the tab height.
        .frame(height: itemHeight, alignment: .top)
        .padding(.top, WinMuxSpacing.compact)
        .padding(.bottom, WinMuxSpacing.compact)
        .frame(width: stripWidth, height: stripHeight, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace tab bar")
        .animation(reduceMotion ? windowTabReducedMotionAnimation : windowTabPillAnimation, value: hoveredTabId)
        .animation(reduceMotion ? windowTabReducedMotionAnimation : windowTabPillAnimation, value: activeWindowId)
        .onDisappear { clearTabDragState() }
        .onChange(of: context.tabOrder) { newOrder in
            clearPendingReorderDropIfModelApplied(currentOrder: newOrder)
            if draggingTabId != nil, dragOriginalOrder != newOrder { clearTabDragState() }
        }
    }

    func tabScrollView(
        context: WindowTabStripLayoutContext,
        itemHeight: CGFloat,
        groupDragWindowId: UInt32?,
    ) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: windowTabStripTabSpacing) {
                    ForEach(strip.tabs) { tab in
                        tabItem(tab, context: context, itemHeight: itemHeight)

                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, windowTabStripContentHorizontalPadding)
                .background {
                    GeometryReader { proxy in
                        WinMuxDesignTokens.transparent.preference(
                            key: WindowTabStripScrollContentFramePreferenceKey.self,
                            value: proxy.frame(in: .named(context.scrollCoordinateSpaceName)),
                        )
                    }
                }
            }
            .onChange(of: tabAutoScrollDirection) { direction in
                guard let direction, let target = tabAutoScrollTarget(direction: direction) else { return }
                withAnimation(.linear(duration: windowTabStripAutoScrollDuration)) {
                    scrollProxy.scrollTo(target, anchor: direction.anchor)
                }
            }
            .coordinateSpace(name: context.scrollCoordinateSpaceName)
            .onPreferenceChange(WindowTabStripScrollContentFramePreferenceKey.self) { nextFrame in
                if abs(tabScrollContentMinX - nextFrame.minX) > 0.5 {
                    tabScrollContentMinX = nextFrame.minX
                }
                if abs(tabScrollContentMaxX - nextFrame.maxX) > 0.5 {
                    tabScrollContentMaxX = nextFrame.maxX
                }
            }
            .onPreferenceChange(WindowTabStripTabFramePreferenceKey.self) { nextFrames in
                tabFramesById = nextFrames
            }
            .mask {
                WindowTabStripScrollFadeMask(
                    leadingFadeWidth: context.leadingFadeWidth(contentMinX: tabScrollContentMinX),
                    trailingFadeWidth: context.trailingFadeWidth(contentMinX: tabScrollContentMinX),
                )
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard let groupDragWindowId, !isWindowTabStripDragInProgress() else { return }
                focusWindowFromTabStripClick(groupDragWindowId, fallbackWorkspace: strip.workspaceName)
            }
            .simultaneousGesture(tabScrollBackgroundGroupDragGesture(
                for: groupDragWindowId,
                context: context,
            ))
        }
    }

    func updateTabAutoScroll(context: WindowTabStripLayoutContext, pointerXInViewport: CGFloat) {
        tabAutoScrollDirection = windowTabAutoScrollDirection(
            pointerXInViewport: pointerXInViewport,
            viewportWidth: context.scrollViewportWidth,
            isScrollable: context.isScrollable,
        )
    }

    func tabAutoScrollTarget(direction: WindowTabAutoScrollDirection) -> UInt32? {
        switch direction {
            case .leading: strip.tabs.first?.windowId
            case .trailing: strip.tabs.last?.windowId
        }
    }

}
