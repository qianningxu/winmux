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
    let layoutFrame: CGRect?
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
        case "alt-tab":
            WorkspacePreviewPanel.shared.advance(direction: 1)
            return true
        case "alt-shift-tab":
            WorkspacePreviewPanel.shared.advance(direction: -1)
            return true
        default:
            return false
    }
}

@MainActor
private func workspacePreviewWindowItems(for workspace: Workspace) -> [WorkspacePreviewWindowItem] {
    let workspaceRect = workspace.rootTilingContainer.lastAppliedLayoutPhysicalRect
        ?? workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
    return (workspace.allLeafWindowsRecursive + workspace.floatingWindows).map { window in
        WorkspacePreviewWindowItem(
            id: window.windowId,
            title: sidebarDisplayLabel(for: window),
            appName: window.app.name ?? "Unknown",
            appIcon: appIconImage(bundleIdentifier: window.app.rawAppBundleId, bundlePath: window.app.bundlePath),
            thumbnail: captureExposeThumbnail(window.windowId),
            layoutFrame: normalizedWorkspacePreviewFrame(for: window, in: workspaceRect),
        )
    }
}

private func normalizedWorkspacePreviewFrame(for window: Window, in workspaceRect: Rect) -> CGRect? {
    guard let rect = window.lastAppliedLayoutPhysicalRect,
          workspaceRect.width > 0,
          workspaceRect.height > 0
    else { return nil }

    return CGRect(
        x: ((rect.minX - workspaceRect.minX) / workspaceRect.width).clamped(to: 0...1),
        y: ((rect.minY - workspaceRect.minY) / workspaceRect.height).clamped(to: 0...1),
        width: (rect.width / workspaceRect.width).clamped(to: 0.04...1),
        height: (rect.height / workspaceRect.height).clamped(to: 0.04...1),
    )
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private struct WorkspacePreviewView: View {
    let items: [WorkspacePreviewItem]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                WorkspacePreviewCard(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                )
                                .id(index)
                                .onTapGesture { onSelect(index) }
                            }
                        }
                        .padding(.horizontal, 36)
                        .padding(.vertical, 28)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .center)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear { proxy.scrollTo(selectedIndex, anchor: .center) }
                    .onChange(of: selectedIndex) { index in
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
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

            WorkspacePreviewLayoutCanvas(windows: item.windows)
                .frame(width: 268, height: 168)

        }
        .padding(14)
        .frame(width: 300)
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            LiquidGlassSurface(
                shape: shape,
                tint: Color.white,
                tintOpacity: isSelected ? 0.04 : 0.02,
                scrimOpacity: isSelected ? 0.03 : 0.015,
                highlightOpacity: isSelected ? 0.18 : 0.12,
                borderOpacity: isSelected ? 0.78 : 0.28,
                glowOpacity: isSelected ? 0.16 : 0,
                glowRadius: isSelected ? 18 : 0,
                lineWidth: isSelected ? 1.8 : 0.9,
            )
        }
        .shadow(color: Color.black.opacity(isSelected ? 0.42 : 0.24), radius: isSelected ? 30 : 18, x: 0, y: 18)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isSelected)
    }
}

private struct WorkspacePreviewLayoutCanvas: View {
    let windows: [WorkspacePreviewWindowItem]

    var body: some View {
        GeometryReader { geometry in
            let placedWindows = placedWindowFrames(in: geometry.size)

            ZStack(alignment: .topLeading) {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                LiquidGlassSurface(
                    shape: shape,
                    tint: Color.white,
                    tintOpacity: 0.02,
                    scrimOpacity: 0.01,
                    highlightOpacity: 0.14,
                    borderOpacity: 0.28,
                    lineWidth: 0.7,
                    isInteractive: false,
                )

                if windows.isEmpty {
                    Text("Empty")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.54))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ForEach(Array(placedWindows.enumerated()), id: \.element.id) { index, placedWindow in
                        WorkspacePreviewWindowTile(window: placedWindow.window, showsLabel: placedWindow.frame.width >= 58 && placedWindow.frame.height >= 42)
                            .frame(width: placedWindow.frame.width, height: placedWindow.frame.height)
                            .position(x: placedWindow.frame.midX, y: placedWindow.frame.midY)
                            .zIndex(Double(index))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    private func placedWindowFrames(in size: CGSize) -> [WorkspacePreviewPlacedWindow] {
        let visibleWindows = Array(windows.prefix(12))
        let rawFrames = visibleWindows.enumerated().map { index, window in
            WorkspacePreviewPlacedWindow(
                window: window,
                frame: previewFrame(for: window, index: index, count: visibleWindows.count, in: size),
            )
        }
        guard let unionFrame = rawFrames.map(\.frame).reduce(nil, { partial, frame in
            partial.map { $0.union(frame) } ?? frame
        }) else {
            return rawFrames
        }
        let offsetX = (size.width - unionFrame.width) / 2 - unionFrame.minX
        let offsetY = (size.height - unionFrame.height) / 2 - unionFrame.minY
        return rawFrames.map { placedWindow in
            WorkspacePreviewPlacedWindow(
                window: placedWindow.window,
                frame: placedWindow.frame.offsetBy(dx: offsetX, dy: offsetY),
            )
        }
    }

    private func previewFrame(for window: WorkspacePreviewWindowItem, index: Int, count: Int, in size: CGSize) -> CGRect {
        let normalized = window.layoutFrame ?? fallbackFrame(index: index, count: count)
        let inset: CGFloat = 8
        let availableWidth = max(size.width - inset * 2, 1)
        let availableHeight = max(size.height - inset * 2, 1)
        let width = max(28, normalized.width * availableWidth)
        let height = max(24, normalized.height * availableHeight)
        return CGRect(
            x: min(inset + normalized.minX * availableWidth, max(inset, size.width - inset - width)),
            y: min(inset + normalized.minY * availableHeight, max(inset, size.height - inset - height)),
            width: width,
            height: height,
        )
    }

    private func fallbackFrame(index: Int, count: Int) -> CGRect {
        let columns = max(1, Int(ceil(sqrt(Double(max(count, 1))))))
        let rows = max(1, Int(ceil(Double(max(count, 1)) / Double(columns))))
        let col = index % columns
        let row = index / columns
        return CGRect(
            x: CGFloat(col) / CGFloat(columns),
            y: CGFloat(row) / CGFloat(rows),
            width: 1 / CGFloat(columns),
            height: 1 / CGFloat(rows),
        )
    }
}

private struct WorkspacePreviewPlacedWindow: Identifiable {
    let window: WorkspacePreviewWindowItem
    let frame: CGRect

    var id: UInt32 { window.id }
}

private struct WorkspacePreviewWindowTile: View {
    let window: WorkspacePreviewWindowItem
    let showsLabel: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.10))
            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else if let appIcon = window.appIcon {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.13, blue: 0.15))
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showsLabel {
                Text(window.appName)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.88))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.6)
        }
        .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 2)
    }
}
