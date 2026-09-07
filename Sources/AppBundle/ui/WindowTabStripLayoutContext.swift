import AppKit

struct WindowTabStripLayoutContext {
    let strip: WindowTabStripViewModel
    let width: CGFloat

    var tabOrder: [UInt32] {
        strip.tabs.map(\.windowId)
    }

    var tabIndicesById: [UInt32: Int] {
        Dictionary(uniqueKeysWithValues: strip.tabs.enumerated().map { ($0.element.windowId, $0.offset) })
    }

    var tabWidth: CGFloat {
        if packsTabsIntoSingleSlot {
            let count = max(strip.tabs.count, 1)
            let availableWidth = singleTabSlotWidth - CGFloat(max(count - 1, 0)) * windowTabStripTabSpacing
            return max(24, availableWidth / CGFloat(count))
        }
        return singleTabSlotWidth
    }

    var showsTabTitles: Bool {
        // Keep every tab fully identifiable. The horizontal scroll view is
        // responsible for overflow, so adding tabs must not collapse them to
        // icon-only pills.
        true
    }

    var effectiveTabWidth: CGFloat {
        tabWidth + windowTabStripTabSpacing
    }

    func pointerXInContent(sourceIndex: Int, pointerXInSourceTab: CGFloat) -> CGFloat {
        windowTabStripContentHorizontalPadding
            + CGFloat(sourceIndex) * effectiveTabWidth
            + pointerXInSourceTab
    }

    var scrollViewportWidth: CGFloat {
        windowTabStripScrollViewportWidth(stripWidth: width)
    }

    var scrollContentWidth: CGFloat {
        CGFloat(strip.tabs.count) * tabWidth
            + CGFloat(max(strip.tabs.count - 1, 0)) * windowTabStripTabSpacing
            + windowTabStripContentHorizontalPadding * 2
    }

    var isScrollable: Bool {
        scrollContentWidth > scrollViewportWidth + 1
    }

    var scrollCoordinateSpaceName: String {
        "window-tab-strip-scroll-\(strip.id.hashValue)"
    }

    var outerTopRadius: CGFloat {
        windowTabGroupOuterCornerRadius(
            innerCornerRadius: windowTabGroupTopInnerCornerRadius(strip.activeWindowCornerRadius)
        )
    }

    func trailingFadeWidth(contentMinX: CGFloat) -> CGFloat {
        windowTabTrailingScrollFadeWidth(
            isScrollable: shouldFadeTabScroll,
            contentMaxX: contentMinX + scrollContentWidth,
            viewportWidth: scrollViewportWidth,
            stripWidth: width,
        )
    }

    func leadingFadeWidth(contentMinX: CGFloat) -> CGFloat {
        windowTabLeadingScrollFadeWidth(
            isScrollable: shouldFadeTabScroll,
            contentMinX: contentMinX,
            stripWidth: width,
        )
    }

    private var shouldFadeTabScroll: Bool { isScrollable }

    private var packsTabsIntoSingleSlot: Bool {
        strip.tabs.count > 1
    }

    private var singleTabSlotWidth: CGFloat {
        windowTabStripTabWidth(stripWidth: width, count: 1)
    }
}
