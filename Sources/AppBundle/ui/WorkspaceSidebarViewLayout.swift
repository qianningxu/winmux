import AppKit
import Common
import SwiftUI

extension WorkspaceSidebarView {
    func sidebarContent(expansionProgress: CGFloat) -> some View {
        let projectsEnabled = projectsAreEnabled()
        let isCompact = expansionProgress < workspaceSidebarRowsRevealProgress
        let leadingInset = workspaceSidebarOuterLeadingPadding(isCompact: isCompact)
        let trailingInset = workspaceSidebarOuterTrailingPadding(isCompact: isCompact)
        let showsMonitorSelector = !isCompact && shouldShowTopFilterBar
        let projectSwipeDirection = projectsEnabled ? workspaceSidebarProjectSwipeDirection(
            horizontalTranslation: projectSwipeTranslation,
            verticalTranslation: 0,
            minimumDistance: 1,
        ) : nil
        let activeProjectIndex = projectPagerDisplayIndex
        let projectSwipeProgress = workspaceSidebarProjectEdgeCreationProgress(
            currentIndex: activeProjectIndex,
            projectCount: snapshot.projects.count,
            direction: projectSwipeDirection,
            distance: abs(projectSwipeTranslation),
        )
        let hasSwipeTarget = projectSwipeDirection.flatMap { direction in
            workspaceSidebarProjectIndexAfterSwipe(
                currentIndex: activeProjectIndex,
                projectCount: snapshot.projects.count,
                direction: direction,
            )
        } != nil
        let projectSwitchProgress = hasSwipeTarget
            ? workspaceSidebarProjectSwipeSwitchProgress(distance: abs(projectSwipeTranslation))
            : 0
        let visibleWorkspacesByProject = workspaceSidebarVisibleWorkspacesByProject(
            workspaces: snapshot.workspaces,
            selectedScopeId: snapshot.selectedMonitorScopeId,
            focusedMonitorScopeId: snapshot.focusedMonitorScopeId,
            targetMonitorScopeId: snapshot.targetMonitorScopeId,
            browsedProjectId: browsedProjectId,
            projectsEnabled: projectsEnabled,
        )
        let filteredWorkspacesByProject = workspaceSidebarFilteredWorkspacesByProject(
            visibleWorkspacesByProject,
            projects: snapshot.projects,
            query: sidebarSearchQuery,
        )

        return VStack(alignment: .leading, spacing: 0) {
            sidebarTopBar(
                expansionProgress: expansionProgress,
                isCompact: isCompact,
                leadingInset: leadingInset,
                trailingInset: trailingInset,
            )

            if showsMonitorSelector {
                monitorSelectorSection(
                    expansionProgress: expansionProgress,
                    leadingInset: leadingInset,
                    trailingInset: trailingInset,
                )
            }

            if !isCompact, isSidebarSearchFiltering {
                sidebarSearchSection(
                    expansionProgress: expansionProgress,
                    leadingInset: leadingInset,
                    trailingInset: trailingInset,
                )
            }

            projectPagerContent(
                expansionProgress: expansionProgress,
                leadingInset: leadingInset,
                trailingInset: trailingInset,
                topPadding: 0,
                visibleWorkspacesByProject: filteredWorkspacesByProject,
                swipeDirection: projectSwipeDirection,
            )
            .frame(
                width: workspaceSidebarContentFrameWidth(expansionProgress: expansionProgress),
                alignment: .topLeading
            )
            .frame(maxHeight: .infinity, alignment: .topLeading)

            if (isSidebarCollapsing && !isCompact) || (isSidebarExpanding && isCompact) {
                let compactProjectReserveHeight = min(
                    max(CGFloat(snapshot.projects.count) * workspaceSidebarProjectDotFrameHeight, workspaceSidebarPagerHeight),
                    workspaceSidebarProjectDotFrameHeight * 5
                )
                Color.clear
                    .frame(height: isCompact ? compactProjectReserveHeight + 8 : workspaceSidebarCollapseReservedProjectPagerHeight)
            } else if projectsEnabled {
                projectPagerSection(
                    expansionProgress: expansionProgress,
                    leadingInset: leadingInset,
                    trailingInset: trailingInset,
                    swipeDirection: projectSwipeDirection,
                    switchProgress: projectSwitchProgress,
                    edgeProgress: projectSwipeProgress,
                )
            }

            if snapshot.configuration.widgets.contains(where: \.enabled) {
                widgetSection(
                    expansionProgress: expansionProgress,
                    isCompact: isCompact,
                    leadingInset: leadingInset,
                    trailingInset: trailingInset,
                )
            }
        }
        .coordinateSpace(name: "workspaceSidebarContent")
        .onPreferenceChange(WorkspaceSidebarDropTargetPreferenceKey.self) { frames in
            actions.setDropTargets(frames)
        }
        .onPreferenceChange(WorkspaceSidebarWorkspaceReorderFramePreferenceKey.self) { frames in
            workspaceReorderFrames = frames
        }
        .overlay {
            sidebarSwipeCaptureOverlay(expansionProgress: expansionProgress)
        }
    }
}

private let workspaceSidebarCollapseReservedProjectPagerHeight = (workspaceSidebarPagerHeight * 2) + 10

extension WorkspaceSidebarView {
    var shouldShowTopFilterBar: Bool {
        let hasFocusFilter = snapshot.monitorScopes.contains { $0.id == workspaceSidebarFocusedScopeId }
        let hasOtherProjects = projectsAreEnabled() && snapshot.projects.contains { $0.id != snapshot.activeProjectId }
        return hasFocusFilter || hasOtherProjects
    }

    func workspaceSidebarSplitSectionWidth(expansionProgress: CGFloat) -> CGFloat {
        let sectionWidth = workspaceSidebarSectionWidth(expansionProgress, layout: snapshot.configuration)
        return (sectionWidth * 2) + workspaceSidebarSplitPaneGap
    }

    func workspaceSidebarContentFrameWidth(expansionProgress: CGFloat) -> CGFloat {
        guard projectsAreEnabled(), browsedProjectId != nil else {
            return max(snapshot.visibleWidth, 0)
        }
        return workspaceSidebarSplitSectionWidth(expansionProgress: expansionProgress) +
            workspaceSidebarContentLeadingInset +
            workspaceSidebarContentTrailingInset
    }
}

let workspaceSidebarSplitPaneGap: CGFloat = 8

@MainActor
func workspaceSidebarExpandedContentFrameWidth(layout: WorkspaceSidebarConfiguration) -> CGFloat {
    let expandedSectionWidth = workspaceSidebarExpandedSectionWidth(layout: layout)
    return (expandedSectionWidth * 2) +
        workspaceSidebarSplitPaneGap +
        workspaceSidebarContentLeadingInset +
        workspaceSidebarContentTrailingInset
}
