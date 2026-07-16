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
        HStack(spacing: showsTitle ? 6 : 0) {
            appIcon(size: iconSize)

            if showsTitle {
                Text(tab.title)
                    .font(.system(size: 12, weight: tab.isActive ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if reservesCloseButtonSpace {
                    Color.clear
                        .frame(width: windowTabStripCloseButtonReservedWidth)
                }
            }
        }
        .foregroundStyle(tabForegroundStyle)
        .padding(.horizontal, showsTitle ? 10 : 0)
        .frame(width: width, height: height, alignment: showsTitle ? .leading : .center)
        .background {
            RoundedRectangle(cornerRadius: windowTabStripInnerCornerRadius, style: .continuous)
                .fill(tab.isActive
                    ? palette.contrastingFill(darkOpacity: 0.14, lightOpacity: 0.10)
                    : palette.contrastingFill(darkOpacity: 0.04, lightOpacity: 0.045)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: windowTabStripInnerCornerRadius, style: .continuous)
                .stroke(tabStrokeStyle, lineWidth: 0.75)
        }
        .opacity(isDragSource ? 0.55 : 1.0)
        .contentShape(Rectangle())
    }

    private var tabForegroundStyle: Color {
        if tab.isActive { return palette.foreground(0.92) }
        if isDragSource { return palette.foreground(0.72) }
        return palette.foreground(isHovered ? 0.74 : 0.58)
    }

    private var tabStrokeStyle: Color {
        palette.tabStroke(active: tab.isActive || isHovered)
    }

    private var iconSize: CGFloat {
        showsTitle ? 14 : min(16, max(10, width - 14))
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
        field.textColor = WinMuxOverlayPalette.current.foregroundNSColor(opacity: 0.92)
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

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
                case #selector(NSResponder.insertNewline(_:)):
                    text = textView.string
                    onCommit()
                    return true
                case #selector(NSResponder.cancelOperation(_:)):
                    onCancel()
                    return true
                default:
                    return false
            }
        }
    }
}
