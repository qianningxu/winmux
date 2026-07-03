import AppKit
import Common
import SwiftUI

let workspaceSidebarPanelId = "WinMux.workspaceSidebar"
let workspaceSidebarContentLeadingInset: CGFloat = 0
let workspaceSidebarContentTrailingInset: CGFloat = 0
let workspaceSidebarMinimumTopPadding: CGFloat = 8
let workspaceSidebarCompactRailHorizontalInset: CGFloat = 0
let workspaceSidebarSectionInnerHorizontalInset: CGFloat = 5
let workspaceSidebarSectionGap: CGFloat = 8
let workspaceSidebarListItemSpacing: CGFloat = 2
let workspaceSidebarNestedRowSpacing: CGFloat = 2
let workspaceSidebarFolderOuterVerticalMargin: CGFloat = 2
let workspaceSidebarBadgeWidth: CGFloat = 22
let workspaceSidebarHeaderSpacing: CGFloat = 8
let workspaceSidebarHeaderRowLeadingPadding: CGFloat = 8
let workspaceSidebarRowsRevealProgress: CGFloat = 0.58
let workspaceSidebarPanelRightCornerRadius: CGFloat = WorkspaceSidebarSideAreaMetrics.standard.plateCornerRadius
let workspaceSidebarPlateCornerRadius: CGFloat = 12
let workspaceSidebarSectionCornerRadius: CGFloat = workspaceSidebarPlateCornerRadius
let workspaceSidebarRowCornerRadius: CGFloat = 10
let workspaceSidebarRowHorizontalPadding: CGFloat = 8
let workspaceSidebarTabRowHeight: CGFloat = 32
let workspaceSidebarWindowRowsLeadingIndent: CGFloat = 0
let workspaceSidebarAppIconSize: CGFloat = 14
let workspaceSidebarAppIconTextSpacing: CGFloat = 6
let workspaceSidebarWindowCloseButtonSize: CGFloat = 18
let workspaceSidebarWindowCloseButtonTrailingInset: CGFloat = 3
let workspaceSidebarWindowCloseButtonReservedWidth: CGFloat = 22
let workspaceSidebarTabGroupChildLeadingIndent: CGFloat = 12
let workspaceSidebarNestedTabRowHeight: CGFloat = workspaceSidebarTabRowHeight
let workspaceSidebarControlHeight: CGFloat = 32
let workspaceSidebarDropdownHeight: CGFloat = 32
let workspaceSidebarSearchHeight: CGFloat = 32
let workspaceSidebarDropdownCornerRadius: CGFloat = 9
let workspaceSidebarDropdownPadding: CGFloat = 7
let workspaceSidebarDropdownLabelSize: CGFloat = 11.5
let workspaceSidebarDropdownSymbolSize: CGFloat = 10.5
let workspaceSidebarPagerHeight: CGFloat = 32
let workspaceSidebarActiveWorkspaceTint = winMuxOverlayAttention()
let workspaceSidebarWorkspaceSectionHeaderHeight: CGFloat = workspaceSidebarTabRowHeight
let workspaceSidebarWorkspaceRowHeight: CGFloat = 26
let workspaceSidebarWorkspaceSectionHeightCompact: CGFloat = workspaceSidebarTabRowHeight
let workspaceSidebarWorkspaceSectionHeightExpanded: CGFloat = workspaceSidebarTabRowHeight
let workspaceSidebarInUseOverrideEmptySectionMinHeight: CGFloat = 76
let workspaceSidebarProjectDotFrameHeight: CGFloat = 32
let workspaceSidebarMenuRowHeight: CGFloat = 28
let workspaceSidebarMenuRowSpacing: CGFloat = 3
let workspaceSidebarMenuRowHorizontalPadding: CGFloat = 10
let workspaceSidebarHoverAnimation: Animation = .interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.06)
let workspaceSidebarReducedMotionHoverAnimation: Animation = .easeOut(duration: 0.14)
let workspaceSidebarDragStartDistance: CGFloat = 8
let workspaceSidebarProjectSwipeIntentThreshold: CGFloat = 5
let workspaceSidebarProjectSwipeNavigateThreshold: CGFloat = 44
let workspaceSidebarProjectSwipeCreateThreshold: CGFloat = 104
let workspaceSidebarProjectSwipeFormationStart: CGFloat = 22
let workspaceSidebarHoverOpenThresholdFraction: CGFloat = 0.75
let workspaceSidebarDisplayEdgeCompactionMargin: CGFloat = 8
@MainActor
var workspaceSidebarDropTargets: [WorkspaceSidebarDropTarget] = []

struct WorkspaceSidebarProjectColorPreset: Hashable, Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
}

let workspaceSidebarProjectColorPresets: [WorkspaceSidebarProjectColorPreset] = [
    WorkspaceSidebarProjectColorPreset(name: "Blue", hex: "#7BA3C9"),
    WorkspaceSidebarProjectColorPreset(name: "Cyan", hex: "#6FBAB4"),
    WorkspaceSidebarProjectColorPreset(name: "Green", hex: "#7DBF8E"),
    WorkspaceSidebarProjectColorPreset(name: "Yellow", hex: "#C9B97A"),
    WorkspaceSidebarProjectColorPreset(name: "Orange", hex: "#C4956E"),
    WorkspaceSidebarProjectColorPreset(name: "Red", hex: "#C48181"),
    WorkspaceSidebarProjectColorPreset(name: "Pink", hex: "#BF8AAE"),
    WorkspaceSidebarProjectColorPreset(name: "Violet", hex: "#9B8FC4"),
]
