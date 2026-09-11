import AppKit

@MainActor private var floatingFocusOrder: [UInt32] = []
@MainActor private var floatingRaiseTask: Task<Void, Never>?
@MainActor private var floatingRaisePending = false

/// Raise sequentially: AX requests to different applications otherwise race.
@MainActor
func raiseFloatingWindowsInFocusOrder(nativeFocused: Window?) async {
    guard TrayMenuModel.shared.isEnabled, !serverArgs.isReadOnly else { return }
    let windows = globalFloatingWindowsContainer.children.compactMap { $0 as? MacWindow }
        .filter { !$0.macApp.nsApp.isHidden && !$0.macApp.nsApp.isTerminated }
    let ids = Set(windows.map(\.windowId))
    floatingFocusOrder.removeAll { !ids.contains($0) }
    for window in windows where !floatingFocusOrder.contains(window.windowId) {
        floatingFocusOrder.insert(window.windowId, at: 0)
    }
    if let id = nativeFocused?.windowId, ids.contains(id) {
        floatingFocusOrder.removeAll { $0 == id }
        floatingFocusOrder.append(id)
    }
    floatingRaisePending = true
    guard floatingRaiseTask == nil else { return }
    floatingRaiseTask = Task { @MainActor in
        defer { floatingRaiseTask = nil }
        while floatingRaisePending {
            floatingRaisePending = false
            let ordered = floatingFocusOrder
            for id in ordered {
                guard TrayMenuModel.shared.isEnabled, !serverArgs.isReadOnly else { return }
                guard let window = MacWindow.allWindowsMap[id],
                      window.parent is GlobalFloatingWindowsContainer,
                      !window.macApp.nsApp.isHidden else { continue }
                try? await window.macApp.raiseWindowAndWait(id)
            }
        }
    }
}
