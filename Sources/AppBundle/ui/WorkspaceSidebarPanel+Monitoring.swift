import AppKit

extension WorkspaceSidebarPanel {
    static func updateHoverStateForVisiblePanels() {
        for panel in visiblePanels where panel.isHoverMonitoring {
            panel.updateHoverStateFromMousePosition()
        }
    }

    func startHoverMonitoring() {
        isHoverMonitoring = true
        updateHoverStateFromMousePosition()
    }

    func stopHoverMonitoring() {
        isHoverMonitoring = false
    }

    func scheduleHoverStateUpdate(at deadline: Date) {
        let delay = max(0, deadline.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isHoverMonitoring else { return }
            guard Date() >= deadline else {
                self.scheduleHoverStateUpdate(at: deadline)
                return
            }
            self.updateHoverStateFromMousePosition()
        }
    }

    func updateHoverStateFromMousePosition() {
        updateMousePassthrough()
        setHovering(isMouseInsideHoverRegion())
    }
}
