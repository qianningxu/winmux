import Foundation

extension WindowTabStripPanelController {
    func refresh() {
        hideAll()
    }

    func windowTabStripsWithTransientResizeApplied(_ strips: [WindowTabStripViewModel]) -> [WindowTabStripViewModel] {
        guard let transientResizeTabGroupStrip else { return strips }
        return strips.map { strip in
            strip.id == transientResizeTabGroupStrip.id ? transientResizeTabGroupStrip : strip
        }
    }

    func refreshInteractiveChrome(strips: [WindowTabStripViewModel], activeIds: Set<ObjectIdentifier>) {
        hideAll()
    }

    func refreshSuppressedChrome(
        mode: MouseInteractionChromeMode,
        strips: [WindowTabStripViewModel],
        activeIds: Set<ObjectIdentifier>,
    ) {
        hideAll()
    }

    func refreshFrameOnlyChrome(strips: [WindowTabStripViewModel], activeIds: Set<ObjectIdentifier>) {
        hideAll()
    }
}
