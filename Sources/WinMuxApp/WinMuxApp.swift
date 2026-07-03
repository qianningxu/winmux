import AppBundle
import AppKit
import SwiftUI

// This file is shared between SPM and xcode project

@MainActor
final class WinMuxAppDelegate: NSObject, NSApplicationDelegate {
    private var isTerminating = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateNow }
        isTerminating = true
        Task { @MainActor in
            await prepareAppBundleForTerminationIfNeeded()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct WinMuxApp: App {
    @NSApplicationDelegateAdaptor(WinMuxAppDelegate.self) var appDelegate
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared
    @StateObject var shortcutSettingsModel = ShortcutSettingsModel.shared
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    init() {
        initAppBundle()
    }

    var body: some Scene {
        menuBar(viewModel: viewModel)
        getShortcutSettingsWindow(model: shortcutSettingsModel)
            .onChange(of: shortcutSettingsModel.openRequestId) { _ in
                openShortcutSettingsWindow(openWindow)
            }
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
