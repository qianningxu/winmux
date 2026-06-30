import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    var sectionBackground: some View {
        sectionShape
            .fill(sectionBackgroundFill)
            .overlay {
                sectionShape
                    .strokeBorder(
                        sectionBorderColor,
                        style: sectionBorderStyle
                    )
            }
    }

    var sectionBorderColor: Color {
        if isDropTarget {
            return palette.attention(0.46)
        }
        if isSearchSelectedWorkspace {
            return palette.border(0.95)
        }
        if allowsWorkspaceActivation && isInUseOnOtherDisplay {
            return palette.destructive(isHovered ? 0.54 : 0.36)
        }
        if isActiveOnTargetMonitor || isPinnedActiveWorkspace {
            let activeTint = isFromOtherDisplay ? palette.otherDisplay() : workspaceSidebarActiveWorkspaceTint
            return activeTint.opacity(isHovered ? 0.46 : 0.34)
        }
        if isFromOtherDisplay {
            return palette.otherDisplay(isHovered ? 0.32 : 0.22)
        }
        return palette.border(isHovered ? 0.92 : 0.68)
    }

    var sectionBorderStyle: StrokeStyle {
        if isPinnedActiveWorkspace && !isSearchFiltering {
            return StrokeStyle(lineWidth: 1, dash: [5, 4])
        }
        return StrokeStyle(lineWidth: isHovered || isActiveOnTargetMonitor || isDropTarget ? 0.75 : 0.6)
    }

    var sectionBackgroundFill: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.12)
        }
        if isSearchSelectedWorkspace {
            return palette.contrastingFill(darkOpacity: 0.105, lightOpacity: 0.09)
        }
        if isSearchFiltering {
            return palette.contrastingFill(darkOpacity: isHovered ? 0.045 : 0.015, lightOpacity: isHovered ? 0.04 : 0.025)
        }
        if allowsWorkspaceActivation && isInUseOnOtherDisplay {
            let redOpacity: Double = workspace.isFocused ? 0.16 : 0.065
            let hoveredRedOpacity: Double = workspace.isFocused ? 0.24 : 0.13
            return palette.destructive(isHovered ? hoveredRedOpacity : redOpacity)
        }
        if isPinnedActiveWorkspace {
            return workspaceSidebarActiveWorkspaceTint.opacity(isHovered ? 0.12 : 0.075)
        }
        let activeTint = isFromOtherDisplay ? palette.otherDisplay() : workspaceSidebarActiveWorkspaceTint
        if isActiveOnTargetMonitor {
            let compactOpacity: Double = workspace.isFocused ? 0.24 : 0.14
            let expandedOpacity: Double = workspace.isFocused ? 0.12 : 0.07
            return activeTint.opacity(isCompact ? compactOpacity : expandedOpacity)
        }
        if isFromOtherDisplay {
            return palette.otherDisplay(isHovered ? 0.10 : 0.05)
        }
        if isHovered {
            return palette.contrastingFill(darkOpacity: 0.045, lightOpacity: 0.04)
        }
        return palette.contrastingFill(darkOpacity: 0.015, lightOpacity: 0.025)
    }

    var compactFocusOpacity: Double {
        isCompact && !isOnFocusedMonitor ? 0.72 : 1
    }

    var inUseOverrideOverlay: some View {
        WorkspaceSidebarInUseOverrideOverlay(text: inUseOverrideText) {
            activeInUseOverrideWorkspaceName = nil
            actions.send(.overrideWorkspaceInUse(workspace.name))
        }
    }
}
