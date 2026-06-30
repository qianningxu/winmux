import SwiftUI

struct WorkspaceSidebarDropdownControlStyle: ViewModifier {
    let isActive: Bool
    var activeFill: Color = winMuxOverlayContrastingFill(darkOpacity: 0.12, lightOpacity: 0.10)
    var activeStroke: Color = winMuxOverlayContrastingFill(darkOpacity: 0.18, lightOpacity: 0.14)
    var inactiveFill: Color = winMuxOverlayContrastingFill(darkOpacity: 0.06, lightOpacity: 0.055)
    var inactiveHoverFill: Color = winMuxOverlayContrastingFill(darkOpacity: 0.10, lightOpacity: 0.08)
    var inactiveStroke: Color = winMuxOverlayContrastingFill(darkOpacity: 0.08, lightOpacity: 0.10)
    var inactiveHoverStroke: Color = winMuxOverlayContrastingFill(darkOpacity: 0.14, lightOpacity: 0.13)
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, workspaceSidebarDropdownPadding)
            .frame(height: workspaceSidebarDropdownHeight)
            .background {
                RoundedRectangle(cornerRadius: workspaceSidebarDropdownCornerRadius, style: .continuous)
                    .fill(controlFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: workspaceSidebarDropdownCornerRadius, style: .continuous)
                            .strokeBorder(controlStroke, lineWidth: isHovered || isActive ? 0.65 : 0.5)
                    }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var controlFill: Color {
        if isActive {
            return activeFill
        }
        return isHovered ? inactiveHoverFill : inactiveFill
    }

    private var controlStroke: Color {
        if isActive {
            return activeStroke
        }
        return isHovered ? inactiveHoverStroke : inactiveStroke
    }
}

struct WorkspaceSidebarDropdownMenuRowStyle: ViewModifier {
    let isSelected: Bool
    var rowHeight: CGFloat = workspaceSidebarDropdownHeight
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: WinMuxOverlayPalette { WinMuxOverlayPalette(colorScheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, workspaceSidebarDropdownPadding)
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: workspaceSidebarRowCornerRadius, style: .continuous)
                    .fill(rowFill)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeOut(duration: 0.10), value: isHovered)
    }

    private var rowFill: Color {
        if isSelected {
            return palette.contrastingFill(darkOpacity: isHovered ? 0.10 : 0.06, lightOpacity: isHovered ? 0.08 : 0.055)
        }
        return palette.contrastingFill(darkOpacity: isHovered ? 0.07 : 0, lightOpacity: isHovered ? 0.055 : 0)
    }
}

func checkmark(isVisible: Bool) -> some View {
    Image(systemName: "checkmark")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(winMuxOverlayForeground(isVisible ? 0.80 : 0))
}
