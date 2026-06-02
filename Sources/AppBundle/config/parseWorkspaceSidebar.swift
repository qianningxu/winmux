import Foundation
import TOMLKit

private let workspaceSidebarParser: [String: any ParserProtocol<WorkspaceSidebarConfig>] = [
    "enabled": Parser(\.enabled, parseBool),
    "enable-focus": Parser(\.enableFocus, parseBool),
    "collapsed-width": Parser(\.collapsedWidth, parseWorkspaceSidebarWidth),
    "width": Parser(\.width, parseWorkspaceSidebarWidth),
    "monitor": Parser(\.monitor) { value, backtrace, errors in
        parseMonitorDescriptions(value, backtrace, &errors)
    },
    "show-status-pills": Parser(\.showStatusPills, parseBool),
    "show-date": Parser(\.showDate, parseBool),
    "widgets": Parser(\.widgets, parseWorkspaceSidebarWidgets),
    "menu-bar-reserve-height": Parser(\.menuBarReserveHeight, parseWorkspaceSidebarMenuBarReserveHeight),
    "project-deletion-action": Parser(\.projectDeletionAction, parseWorkspaceProjectDeletionAction),
    "workspace-labels": Parser(\.workspaceLabels, parseWorkspaceSidebarLabels),
    "project-labels": Parser(\.projectLabels, parseWorkspaceSidebarLabels),
    "project-colors": Parser(\.projectColors, parseWorkspaceSidebarProjectColors),
]

func parseWorkspaceSidebar(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> WorkspaceSidebarConfig {
    parseTable(raw, WorkspaceSidebarConfig(), workspaceSidebarParser, backtrace, &errors)
}

private func parseWorkspaceSidebarWidth(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    parseInt(raw, backtrace)
        .filter(.semantic(backtrace, "Must be greater than 0")) { $0 > 0 }
}

private func parseWorkspaceSidebarMenuBarReserveHeight(_ raw: TOMLValueConvertible, _ backtrace: TomlBacktrace) -> ParsedToml<Int> {
    parseInt(raw, backtrace)
        .filter(.semantic(backtrace, "Must be greater than or equal to 0")) { $0 >= 0 }
}

private let workspaceSidebarWidgetParser: [String: any ParserProtocol<WorkspaceSidebarWidgetConfig>] = [
    "id": Parser(\.id, parseString),
    "type": Parser(\.type, parseWorkspaceSidebarWidgetType),
    "enabled": Parser(\.enabled, parseBool),
    "show-date": Parser(\.showDate, parseBool),
    "bundle": Parser(\.bundle) { raw, backtrace in parseString(raw, backtrace).map { Optional($0) } },
    "entries-path": Parser(\.entriesPath) { raw, backtrace in
        parseString(raw, backtrace)
            .filter(.semantic(backtrace, "Must not be empty")) { !$0.isEmpty }
            .map { Optional($0) }
    },
    "days": Parser(\.days) { raw, backtrace in
        parseInt(raw, backtrace)
            .filter(.semantic(backtrace, "Must be greater than 0")) { $0 > 0 }
            .map { Optional($0) }
    },
]

private func parseWorkspaceSidebarWidgets(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [WorkspaceSidebarWidgetConfig]? {
    guard let rawArray = raw.array else {
        errors.append(expectedActualTypeError(expected: .array, actual: raw.type, backtrace))
        return nil
    }

    var seenIds = Set<String>()
    return rawArray.enumerated().compactMap { index, rawWidget in
        let widgetBacktrace = backtrace + .index(index)
        guard rawWidget.table != nil else {
            errors.append(expectedActualTypeError(expected: .table, actual: rawWidget.type, widgetBacktrace))
            return nil
        }

        let widget = parseTable(rawWidget, WorkspaceSidebarWidgetConfig(), workspaceSidebarWidgetParser, widgetBacktrace, &errors)
        guard !widget.id.isEmpty else {
            errors.append(.semantic(widgetBacktrace + .key("id"), "Must not be empty"))
            return nil
        }
        guard seenIds.insert(widget.id).inserted else {
            errors.append(.semantic(widgetBacktrace + .key("id"), "Duplicate widget id '\(widget.id)'"))
            return nil
        }
        switch widget.type {
            case .builtInTimeDate:
                if widget.bundle != nil {
                    errors.append(.semantic(widgetBacktrace + .key("bundle"), "Only plugin widgets can specify bundle"))
                }
                if widget.entriesPath != nil {
                    errors.append(.semantic(widgetBacktrace + .key("entries-path"), "Only data widgets can specify entries-path"))
                }
                if widget.days != nil {
                    errors.append(.semantic(widgetBacktrace + .key("days"), "Only data widgets can specify days"))
                }
            case .builtInTogglProjects:
                if widget.bundle != nil {
                    errors.append(.semantic(widgetBacktrace + .key("bundle"), "Only plugin widgets can specify bundle"))
                }
            case .builtInSpendingCategories:
                if widget.bundle != nil {
                    errors.append(.semantic(widgetBacktrace + .key("bundle"), "Only plugin widgets can specify bundle"))
                }
            case .plugin:
                if widget.bundle?.isEmpty != false {
                    errors.append(.semantic(widgetBacktrace + .key("bundle"), "Plugin widgets require a bundle name"))
                    return nil
                }
                if widget.entriesPath != nil {
                    errors.append(.semantic(widgetBacktrace + .key("entries-path"), "Only data widgets can specify entries-path"))
                }
                if widget.days != nil {
                    errors.append(.semantic(widgetBacktrace + .key("days"), "Only data widgets can specify days"))
                }
        }
        return widget
    }
}

private func parseWorkspaceSidebarWidgetType(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<WorkspaceSidebarWidgetType> {
    parseString(raw, backtrace).flatMap { rawValue in
        WorkspaceSidebarWidgetType(rawValue: rawValue)
            .orFailure(.semantic(
                backtrace,
                "Possible values: \(WorkspaceSidebarWidgetType.allCases.map(\.rawValue).joined(separator: ", "))",
            ))
    }
}

private func parseWorkspaceProjectDeletionAction(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<WorkspaceProjectDeletionAction> {
    parseString(raw, backtrace).flatMap { rawValue in
        WorkspaceProjectDeletionAction(rawValue: rawValue)
            .orFailure(.semantic(
                backtrace,
                "Possible values: \(WorkspaceProjectDeletionAction.allCases.map(\.rawValue).joined(separator: ", "))",
            ))
    }
}

private func parseWorkspaceSidebarLabels(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [String: String] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: String] = [:]
    for (workspaceName, rawLabel) in rawTable {
        if let label = parseString(rawLabel, backtrace + .key(workspaceName)).getOrNil(appendErrorTo: &errors) {
            result[workspaceName] = label
        }
    }
    return result
}

func normalizedWorkspaceSidebarColorHex(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
    let allowedCharacters = Set("0123456789abcdefABCDEF")
    guard hex.count == 6,
          hex.allSatisfy({ allowedCharacters.contains($0) })
    else {
        return nil
    }
    return "#\(hex.uppercased())"
}

private func parseWorkspaceSidebarProjectColors(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [String: String] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: String] = [:]
    for (projectId, rawColor) in rawTable {
        let colorBacktrace = backtrace + .key(projectId)
        guard let color = parseString(rawColor, colorBacktrace).getOrNil(appendErrorTo: &errors) else { continue }
        guard let normalized = normalizedWorkspaceSidebarColorHex(color) else {
            errors.append(.semantic(colorBacktrace, "Must be a hex color like '#RRGGBB'"))
            continue
        }
        result[projectId] = normalized
    }
    return result
}
