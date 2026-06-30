import Foundation

extension WindowTabStripPanelController {
    func hideChromeDuringMouseInteraction(showFrameOnly: Bool = true) {
        hideAll()
    }

    func showChromeDuringMouseInteraction() {
        hideAll()
    }

    func refreshHiddenChrome(activeIds: Set<ObjectIdentifier>) {
        for id in Array(visualPanels.keys) {
            orderOutIfVisible(visualPanels[id])
            if !activeIds.contains(id) {
                visualPanels.removeValue(forKey: id)
            }
        }
        for id in Array(stripPanels.keys) {
            orderOutIfVisible(stripPanels[id])
            if !activeIds.contains(id) {
                stripPanels.removeValue(forKey: id)
            }
        }
    }

    @discardableResult
    func clearMouseInteractionChromeSuppressionIfInactive() -> Bool {
        let hadSuppression = mouseInteractionChromeMode != nil || !hiddenPassiveTabGroupChromeIds.isEmpty
        if currentlyManipulatedWithMouseWindowId == nil {
            mouseInteractionChromeMode = nil
            hiddenPassiveTabGroupChromeIds.removeAll()
        }
        return hadSuppression
    }
}
