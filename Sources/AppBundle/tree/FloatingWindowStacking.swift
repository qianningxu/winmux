import AppKit

@MainActor private var floatingFocusOrder: [UInt32] = []

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
    let ordered = floatingFocusOrder.compactMap { id in windows.first { $0.windowId == id } }
    for window in ordered {
        guard !Task.isCancelled else { return }
        try? await window.macApp.raiseWindowAndWait(window.windowId)
    }
}
