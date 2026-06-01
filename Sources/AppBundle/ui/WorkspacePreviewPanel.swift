import AppKit
import SwiftUI

private let workspacePreviewPanelId = "WinMux.workspacePreview"

private struct WorkspacePreviewItem: Identifiable {
    let id: String
    let workspace: Workspace
    let displayName: String
    let isCurrent: Bool
    let windows: [WorkspacePreviewWindowItem]
}

private struct WorkspacePreviewWindowItem: Identifiable {
    let id: UInt32
    let title: String
    let appName: String
    let appIcon: NSImage?
    let thumbnail: NSImage?
}

@MainActor
final class WorkspacePreviewPanel: NSPanelHud {
    static let shared = WorkspacePreviewPanel()

    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var items: [WorkspacePreviewItem] = []
    private var selectedIndex: Int = 0
    private(set) var isPreviewActive = false

    override private init() {
        super.init()
        identifier = NSUserInterfaceItemIdentifier(workspacePreviewPanelId)
        hasShadow = false
        isFloatingPanel = true
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        backgroundColor = .clear
        applyWinMuxLayer(.overlay)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = hostingView
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }

    func advance(direction: Int) {
        if !isPreviewActive {
            begin(direction: direction)
            return
        }
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + direction + items.count) % items.count
        render()
    }

    func commitIfActive() {
        guard isPreviewActive else { return }
        let target = items.getOrNil(atIndex: selectedIndex)?.workspace
        dismiss()
        guard let target, target != focus.workspace else { return }
        Task { @MainActor in
            guard let token: RunSessionGuard = .isServerEnabled else { return }
            try await runLightSession(.menuBarButton, token) {
                _ = target.focusWorkspace()
            }
        }
    }

    func dismiss() {
        guard isPreviewActive else { return }
        isPreviewActive = false
        items = []
        selectedIndex = 0
        orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
    }

    private func begin(direction: Int) {
        let current = focus.workspace
        let candidates = orderedUserFacingWorkspaces(in: current.projectId, focusedWorkspace: current)
        guard !candidates.isEmpty else { return }
        items = candidates.map { workspace in
            WorkspacePreviewItem(
                id: workspace.name,
                workspace: workspace,
                displayName: workspaceDisplayName(workspace.name),
                isCurrent: workspace == current,
                windows: workspacePreviewWindowItems(for: workspace),
            )
        }
        let currentIndex = items.firstIndex { $0.workspace == current } ?? 0
        selectedIndex = (currentIndex + direction + items.count) % items.count
        isPreviewActive = true
        let frame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        setFrame(frame, display: true, animate: false)
        render()
        orderFrontRegardless()
    }

    private func render() {
        hostingView.rootView = AnyView(
            WorkspacePreviewView(
                items: items,
                selectedIndex: selectedIndex,
                onSelect: { [weak self] index in
                    self?.selectedIndex = index
                    self?.commitIfActive()
                },
                onDismiss: { [weak self] in self?.dismiss() },
            )
        )
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dismiss(); return }
        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
func handleWorkspacePreviewHotkey(_ binding: String) -> Bool {
    switch binding {
        case "ctrl-tab":
            WorkspacePreviewPanel.shared.advance(direction: 1)
            return true
        case "ctrl-shift-tab":
            WorkspacePreviewPanel.shared.advance(direction: -1)
            return true
        default:
            return false
    }
}

@MainActor
private func workspacePreviewWindowItems(for workspace: Workspace) -> [WorkspacePreviewWindowItem] {
    (workspace.allLeafWindowsRecursive + workspace.floatingWindows).map { window in
        WorkspacePreviewWindowItem(
            id: window.windowId,
            title: sidebarDisplayLabel(for: window),
            appName: window.app.name ?? "Unknown",
            appIcon: appIconImage(bundleIdentifier: window.app.rawAppBundleId, bundlePath: window.app.bundlePath),
            thumbnail: captureExposeThumbnail(window.windowId),
        )
    }
}

private struct WorkspacePreviewView: View {
    let items: [WorkspacePreviewItem]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            HStack(spacing: 18) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    WorkspacePreviewCard(
                        item: item,
                        isSelected: index == selectedIndex,
                    )
                    .onTapGesture { onSelect(index) }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WorkspacePreviewCard: View {
    let item: WorkspacePreviewItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .lineLimit(1)
                Spacer()
                if item.isCurrent {
                    Text("Current")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.60))
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.24))
                windowPreviewGrid
                    .padding(14)
            }
            .frame(width: 220, height: 136)

            Text("\(item.windows.count) window\(item.windows.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.52))
        }
        .padding(14)
        .frame(width: 252)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.16 : 0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.64 : 0.14), lineWidth: isSelected ? 2 : 1)
                }
        )
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isSelected)
    }

    private var windowPreviewGrid: some View {
        let windows = Array(item.windows.prefix(9))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            if windows.isEmpty {
                Text("Empty")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .frame(width: 188, height: 92)
            } else {
                ForEach(windows) { window in
                    WorkspacePreviewWindowTile(window: window)
                }
            }
        }
    }
}

private struct WorkspacePreviewWindowTile: View {
    let window: WorkspacePreviewWindowItem

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.10))
            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 54, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else if let appIcon = window.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
                    .frame(width: 54, height: 34)
            }
        }
        .frame(width: 54, height: 34)
        .overlay(alignment: .bottomLeading) {
            Text(window.appName)
                .font(.system(size: 6, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.34))
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
