import Common
import Foundation

@MainActor
private var sessionWindowTabLabels: [UInt32: String] = [:]
@MainActor
private var sessionWindowTabLabelKeys: [UInt32: String] = [:]

@MainActor
func resetWindowTabLabelsForTests() {
    sessionWindowTabLabels = [:]
    sessionWindowTabLabelKeys = [:]
}

@MainActor
func windowTabLabelKey(app: any AbstractApp, rawTitle: String) -> String {
    let appIdentity = app.rawAppBundleId?.takeIf { !$0.isEmpty }
        ?? app.bundlePath?.takeIf { !$0.isEmpty }
        ?? app.name?.takeIf { !$0.isEmpty }
        ?? "unknown-app"
    return "\(appIdentity)|\(rawTitle)"
}

@MainActor
func tabDisplayTitle(for window: Window) async -> String {
    let appName = window.app.name ?? window.app.rawAppBundleId ?? "Window"
    if let sessionLabel = sessionWindowTabLabels[window.windowId]?.trimmingCharacters(in: .whitespacesAndNewlines),
       !sessionLabel.isEmpty
    {
        return sessionLabel
    }
    let rawTitle = await getCachedWindowTitle(window) ?? appName
    let key = sessionWindowTabLabelKeys[window.windowId] ?? windowTabLabelKey(app: window.app, rawTitle: rawTitle)
    if let label = config.windowTabs.tabLabels[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
       !label.isEmpty
    {
        sessionWindowTabLabelKeys[window.windowId] = key
        return label
    }
    return rawTitle
}

@MainActor
func renameWindowTab(windowId: UInt32, displayName: String) async throws {
    guard let window = Window.get(byId: windowId) else { return }
    let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
        try await resetWindowTabLabel(windowId: windowId)
        return
    }
    let key = await resolvedWindowTabLabelKey(for: window)
    config.windowTabs.tabLabels[key] = trimmedName
    sessionWindowTabLabelKeys[windowId] = key
    sessionWindowTabLabels[windowId] = trimmedName
    if !isUnitTest {
        try persistWindowTabLabel(key: key, label: trimmedName)
    }
}

@MainActor
func resetWindowTabLabel(windowId: UInt32) async throws {
    guard let window = Window.get(byId: windowId) else { return }
    let key: String
    if let sessionKey = sessionWindowTabLabelKeys[windowId] {
        key = sessionKey
    } else {
        key = await resolvedWindowTabLabelKey(for: window)
    }
    config.windowTabs.tabLabels.removeValue(forKey: key)
    sessionWindowTabLabelKeys.removeValue(forKey: windowId)
    sessionWindowTabLabels.removeValue(forKey: windowId)
    if !isUnitTest {
        try persistWindowTabLabel(key: key, label: nil)
    }
}

@MainActor
private func resolvedWindowTabLabelKey(for window: Window) async -> String {
    let appName = window.app.name ?? window.app.rawAppBundleId ?? "Window"
    let rawTitle = await getCachedWindowTitle(window) ?? appName
    return windowTabLabelKey(app: window.app, rawTitle: rawTitle)
}
