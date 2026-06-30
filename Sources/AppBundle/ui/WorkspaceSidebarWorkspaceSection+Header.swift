import SwiftUI

extension WorkspaceSidebarWorkspaceSection {
    var headerButton: some View {
        Button(action: handleSectionClick) {
            header
                .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var header: some View {
        Group {
            if isCompact {
                compactTabBadge
            } else {
                expandedHeader
            }
        }
    }

    var expandedHeader: some View {
        HStack(spacing: workspaceSidebarHeaderSpacing) {
            tabIcon
            if isRenamingWorkspace {
                WorkspaceSidebarWorkspaceRenameField(
                    text: $renamingWorkspaceText,
                    workspaceName: workspace.name,
                    onCommit: onCommitRenameWorkspace,
                    onCancel: onCancelRenameWorkspace,
                )
                .layoutPriority(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.displayName)
                        .font(.system(size: 13.5, weight: isActiveOnTargetMonitor ? .semibold : .medium))
                        .foregroundStyle(isActiveOnTargetMonitor ? palette.foreground(1) : palette.foreground(0.86))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle = workspace.tabSummary.subtitle {
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(palette.foreground(0.50))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: handleHeaderDoubleClick)
                .onTapGesture(count: 1) {}
                .layoutPriority(1)
            }
            if let projectContextLabel, let projectContextColor {
                Text(projectContextLabel)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(projectContextColor.opacity(0.86))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 15)
                    .background {
                        Capsule(style: .continuous)
                            .fill(projectContextColor.opacity(0.13))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(projectContextColor.opacity(0.24), lineWidth: 0.5)
                    }
            }
            if workspace.tabSummary.windowCount > 1 {
                Text("\(workspace.tabSummary.windowCount)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.foreground(isActiveOnTargetMonitor ? 0.76 : 0.48))
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .frame(height: 16)
                    .background {
                        Capsule(style: .continuous)
                            .fill(palette.contrastingFill(darkOpacity: 0.08, lightOpacity: 0.07))
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, workspaceSidebarHeaderRowLeadingPadding)
        .padding(.trailing, workspaceSidebarRowHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var compactTabBadge: some View {
        Group {
            if workspace.tabSummary.isEmpty {
                workspaceBadge
            } else {
                tabIcon
            }
        }
        .frame(width: workspaceSidebarBadgeWidth, height: workspaceSidebarBadgeWidth)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    var tabIcon: some View {
        if let icon = appIconImage(
            bundleIdentifier: workspace.tabSummary.appBundleId,
            bundlePath: workspace.tabSummary.appBundlePath
        ) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
                .cornerRadius(4)
                .opacity(isActiveOnTargetMonitor ? 1 : 0.88)
        } else {
            workspaceBadge
                .font(.system(size: 12, weight: isActiveOnTargetMonitor ? .bold : .semibold))
                .frame(width: workspaceSidebarAppIconSize + 2, height: workspaceSidebarAppIconSize + 2)
        }
    }
}
