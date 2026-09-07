import AppKit
import SwiftUI

struct WindowTabItemView: View {
    let tab: WindowTabItemViewModel
    let width: CGFloat
    let height: CGFloat
    let isDragSource: Bool
    let isHovered: Bool
    let showsTitle: Bool
    let reservesCloseButtonSpace: Bool
    @Environment(\.colorScheme) var colorScheme

    var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: showsTitle ? WinMuxBarStyle.iconSpacing : WinMuxSpacing.none) {
            appIcon(size: iconSize)

            if showsTitle {
                Text(tab.title)
                    .font(.system(size: WinMuxBarStyle.fontSize, weight: tab.isActive ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if reservesCloseButtonSpace {
                    WinMuxDesignTokens.transparent
                        .frame(width: windowTabStripCloseButtonReservedWidth)
                }
            }
        }
        .foregroundStyle(tabForegroundStyle)
        .padding(.horizontal, showsTitle ? WinMuxBarStyle.contentInset : WinMuxSpacing.none)
        .frame(width: width, height: height, alignment: showsTitle ? .leading : .center)
        .winMuxBarSegment(palette, isSelected: tab.isActive || isDragSource, isHovered: isHovered)
        .background(palette.color(.gray, .color2))
        .clipShape(RoundedRectangle(cornerRadius: WinMuxBarStyle.cornerRadius, style: .continuous))
        .overlay {
            if tab.isActive {
                RoundedRectangle(cornerRadius: WinMuxBarStyle.cornerRadius, style: .continuous)
                    .strokeBorder(palette.color(.gray, .color5), lineWidth: WinMuxBarStyle.strokeWidth)
                    .allowsHitTesting(false)
            }
        }
        .opacity(isDragSource ? 0.55 : 1.0)
        .contentShape(Rectangle())
    }

    private var tabForegroundStyle: Color {
        if tab.isActive || isHovered { return palette.content(.primary) }
        return palette.content(.secondary)
    }

    private var iconSize: CGFloat {
        showsTitle ? workspaceSidebarAppIconSize + 2 : min(16, max(10, width - 14))
    }
}

struct WindowTabRenameTextField: NSViewRepresentable {
    @Binding var text: String
    let onCommit: @MainActor @Sendable () -> Void
    let onCancel: @MainActor @Sendable () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = WinMuxOverlayPalette.current.contentNSColor(.primary)
        field.font = .systemFont(ofSize: 12, weight: .semibold)
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        DispatchQueue.main.async {
            context.coordinator.focus(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        field.delegate = context.coordinator
        DispatchQueue.main.async {
            context.coordinator.focus(field)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit, onCancel: onCancel)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onCommit: @MainActor @Sendable () -> Void
        let onCancel: @MainActor @Sendable () -> Void
        var didFocus = false
        var didFinish = false

        init(
            text: Binding<String>,
            onCommit: @escaping @MainActor @Sendable () -> Void,
            onCancel: @escaping @MainActor @Sendable () -> Void,
        ) {
            _text = text
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        @MainActor
        func focus(_ field: NSTextField) {
            guard !didFocus, let window = field.window else { return }
            window.makeKeyAndOrderFront(nil)
            didFocus = window.makeFirstResponder(field)
            field.selectText(nil)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
            finish(commit: true)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
                case #selector(NSResponder.insertNewline(_:)):
                    text = textView.string
                    finish(commit: true)
                    return true
                case #selector(NSResponder.cancelOperation(_:)):
                    finish(commit: false)
                    return true
                default:
                    return false
            }
        }

        @MainActor
        private func finish(commit: Bool) {
            guard !didFinish else { return }
            didFinish = true
            if commit {
                onCommit()
            } else {
                onCancel()
            }
        }
    }
}
