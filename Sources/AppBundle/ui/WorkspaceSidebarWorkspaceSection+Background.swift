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
            return palette.tabStroke(active: true)
        }
        if isSearchSelectedWorkspace {
            return palette.tabStroke(active: true)
        }
        if allowsWorkspaceActivation && isInUseOnOtherDisplay {
            return palette.destructive(isHovered ? 0.54 : 0.36)
        }
        if isVisuallyActiveOnTargetMonitor && showsWindowRows {
            return Color.clear
        }
        if (isVisuallyActiveOnTargetMonitor || isPinnedActiveWorkspace) && !showsWindowRows {
            return Color.clear
        }
        if isVisuallyActiveOnTargetMonitor || isPinnedActiveWorkspace {
            return palette.tabStroke(active: isHovered)
        }
        if isFromOtherDisplay {
            return palette.otherDisplay(isHovered ? 0.32 : 0.22)
        }
        return Color.clear
    }

    var sectionBorderStyle: StrokeStyle {
        if isPinnedActiveWorkspace && !isSearchFiltering {
            return StrokeStyle(lineWidth: 1, dash: [5, 4])
        }
        return StrokeStyle(lineWidth: isHovered || isVisuallyActiveOnTargetMonitor || isDropTarget ? 0.75 : 0.6)
    }

    var sectionBackgroundFill: Color {
        if isDropTarget {
            return palette.gray200(palette.isDark ? 0.78 : 0.66)
        }
        if isSearchSelectedWorkspace {
            return palette.card()
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
            return Color.clear
        }
        if isVisuallyActiveOnTargetMonitor && showsWindowRows {
            return Color.clear
        }
        if isVisuallyActiveOnTargetMonitor && nestedContentIndent <= 0 {
            return Color.clear
        }
        if isFromOtherDisplay {
            return palette.otherDisplay(isHovered ? 0.10 : 0.05)
        }
        return Color.clear
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
