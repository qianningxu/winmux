import Foundation
import SwiftUI

private let togglTrackThemeColor = Color(red: 0xE5 / 255, green: 0x7C / 255, blue: 0xD8 / 255)

enum WorkspaceSidebarTogglBreakdown: Sendable {
    case days
    case projects
}

struct WorkspaceSidebarTogglProjectsWidget: View {
    let id: String
    let sectionWidth: CGFloat
    let isCompact: Bool
    let entriesPath: String
    let days: Int
    let breakdown: WorkspaceSidebarTogglBreakdown

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = TogglProjectTimeAggregator(
                entriesDirectory: URL(filePath: entriesPath, directoryHint: .isDirectory),
                days: days,
            ).load(now: context.date)

            Group {
                if isCompact {
                    WorkspaceSidebarCompactTogglProjectsCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                        days: days,
                        breakdown: breakdown,
                    )
                } else {
                    WorkspaceSidebarExpandedTogglProjectsCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                        days: days,
                        breakdown: breakdown,
                    )
                }
            }
        }
        .id(id)
    }
}

struct TogglProjectTimeSummary: Equatable, Identifiable, Sendable {
    let project: String
    let seconds: TimeInterval

    var id: String { project }
}

struct TogglDailyFocusSummary: Equatable, Identifiable, Sendable {
    let date: Date
    let seconds: TimeInterval

    var id: Date { date }
}

struct TogglProjectTimeSnapshot: Equatable, Sendable {
    var projects: [TogglProjectTimeSummary] = []
    var dailyFocus: [TogglDailyFocusSummary] = []
    var totalSeconds: TimeInterval = 0
    var scannedEntryCount: Int = 0
    var errorMessage: String? = nil
}

struct TogglProjectTimeAggregator: Sendable {
    let entriesDirectory: URL
    let days: Int

    func load(now: Date = Date()) -> TogglProjectTimeSnapshot {
        guard days > 0 else {
            return TogglProjectTimeSnapshot(errorMessage: "Invalid Toggl window")
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: entriesDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return TogglProjectTimeSnapshot(errorMessage: "Can't read Toggl entries")
        }

        let entryUrls: [URL]
        do {
            entryUrls = try fileManager.contentsOfDirectory(
                at: entriesDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles],
            )
        } catch {
            return TogglProjectTimeSnapshot(errorMessage: "Can't read Toggl entries")
        }

        var calendar = Calendar.current
        calendar.locale = Locale.current
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else {
            return TogglProjectTimeSnapshot(errorMessage: "Invalid Toggl window")
        }

        let dayStarts = (0 ..< days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: windowStart)
        }
        var totalsByDay = Dictionary(uniqueKeysWithValues: dayStarts.map { ($0, TimeInterval(0)) })

        let formatter = makeTogglDateFormatter()
        var totalsByProject: [String: TimeInterval] = [:]
        var scannedEntryCount = 0

        for url in entryUrls where url.pathExtension == "md" {
            guard let entry = TogglTimeEntry.parse(url: url, formatter: formatter) else { continue }
            scannedEntryCount += 1

            let entryDayStart = calendar.startOfDay(for: entry.start)
            guard totalsByDay[entryDayStart] != nil else { continue }

            let effectiveStop = min(entry.stop, now)
            let seconds = effectiveStop.timeIntervalSince(entry.start)
            guard seconds > 0 else { continue }

            totalsByProject[entry.project, default: 0] += seconds
            totalsByDay[entryDayStart, default: 0] += seconds
        }

        let projects = totalsByProject
            .map { TogglProjectTimeSummary(project: $0.key, seconds: $0.value) }
            .sorted { lhs, rhs in
                if lhs.seconds != rhs.seconds {
                    return lhs.seconds > rhs.seconds
                }
                return lhs.project.localizedStandardCompare(rhs.project) == .orderedAscending
            }

        let dailyFocus = dayStarts.map { dayStart in
            TogglDailyFocusSummary(date: dayStart, seconds: totalsByDay[dayStart] ?? 0)
        }

        return TogglProjectTimeSnapshot(
            projects: projects,
            dailyFocus: dailyFocus,
            totalSeconds: projects.reduce(0) { $0 + $1.seconds },
            scannedEntryCount: scannedEntryCount,
            errorMessage: nil,
        )
    }

    private func makeTogglDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

}

private struct TogglTimeEntry {
    let start: Date
    let stop: Date
    let project: String

    static func parse(url: URL, formatter: DateFormatter) -> TogglTimeEntry? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let fields = TogglFrontMatter.fields(in: text)
        guard let startRaw = fields["start"], let start = formatter.date(from: startRaw) else { return nil }

        let stop = fields["stop"].flatMap { formatter.date(from: $0) }
            ?? fields["duration"]
                .flatMap(Double.init)
                .map { start.addingTimeInterval($0 * 60 * 60) }
        guard let stop, stop >= start else { return nil }

        let rawProject = fields["project"] ?? ""
        let project = rawProject.isEmpty ? "No project" : rawProject
        return TogglTimeEntry(start: start, stop: stop, project: project)
    }
}

private enum TogglFrontMatter {
    static func fields(in text: String) -> [String: String] {
        var fields: [String: String] = [:]
        var hasStartedFrontMatter = false

        for line in text.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine == "---" {
                if hasStartedFrontMatter {
                    break
                }
                hasStartedFrontMatter = true
                continue
            }

            guard hasStartedFrontMatter, let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            fields[key] = unquote(value)
        }

        return fields
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2,
              value.first == "\"",
              value.last == "\""
        else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }
}

private struct WorkspaceSidebarCompactTogglProjectsCard: View {
    let snapshot: TogglProjectTimeSnapshot
    let sectionWidth: CGFloat
    let days: Int
    let breakdown: WorkspaceSidebarTogglBreakdown

    private var title: String {
        switch breakdown {
            case .days: "Toggl/days"
            case .projects: "Toggl/projects"
        }
    }

    private var systemImage: String {
        switch breakdown {
            case .days: "calendar"
            case .projects: "folder"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(togglTrackThemeColor.opacity(0.86))

            Text(togglHoursText(snapshot.totalSeconds))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(days)d")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
                .lineLimit(1)
        }
        .frame(width: sectionWidth, height: 76, alignment: .center)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        if let errorMessage = snapshot.errorMessage {
            return errorMessage
        }
        return "\(title), \(togglDurationText(snapshot.totalSeconds)) in the last \(days) days"
    }
}

private struct WorkspaceSidebarExpandedTogglProjectsCard: View {
    let snapshot: TogglProjectTimeSnapshot
    let sectionWidth: CGFloat
    let days: Int
    let breakdown: WorkspaceSidebarTogglBreakdown

    private var visibleProjects: [TogglProjectTimeSummary] {
        Array(snapshot.projects.prefix(3))
    }

    private var visibleDays: [TogglDailyFocusSummary] {
        Array(snapshot.dailyFocus.suffix(min(days, 7)).reversed())
    }

    private var maxDailySeconds: TimeInterval {
        max(visibleDays.map(\.seconds).max() ?? 0, 1)
    }

    private var maxProjectSeconds: TimeInterval {
        max(visibleProjects.map(\.seconds).max() ?? 0, 1)
    }

    private var title: String {
        switch breakdown {
            case .days: "Toggl/days"
            case .projects: "Toggl/projects"
        }
    }

    private var systemImage: String {
        switch breakdown {
            case .days: "calendar"
            case .projects: "folder"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(togglTrackThemeColor.opacity(0.88))

                Spacer(minLength: 8)

                Text(togglHoursText(snapshot.totalSeconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let errorMessage = snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                switch breakdown {
                    case .days:
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(visibleDays) { day in
                                TogglDailyFocusRow(
                                    day: day,
                                    maxSeconds: maxDailySeconds,
                                )
                            }
                        }
                    case .projects:
                        if visibleProjects.isEmpty {
                            Text("No entries")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.52))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(visibleProjects) { project in
                                    TogglProjectTimeRow(
                                        project: project,
                                        maxSeconds: maxProjectSeconds,
                                    )
                                }
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: sectionWidth, alignment: .leading)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .combine)
    }
}

private struct TogglDailyFocusRow: View {
    let day: TogglDailyFocusSummary
    let maxSeconds: TimeInterval

    private var ratio: CGFloat {
        CGFloat(max(0, min(day.seconds / maxSeconds, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(togglWeekdayText(day.date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(togglCompactHoursText(day.seconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(day.seconds > 0 ? 0.64 : 0.36))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))

                    if day.seconds > 0 {
                        Capsule()
                            .fill(togglTrackThemeColor.opacity(0.56))
                            .frame(width: max(3, geometry.size.width * ratio))
                    }
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(togglWeekdayAccessibilityText(day.date)), \(togglDurationText(day.seconds))"))
    }
}

private struct TogglProjectTimeRow: View {
    let project: TogglProjectTimeSummary
    let maxSeconds: TimeInterval

    private var ratio: CGFloat {
        CGFloat(max(0, min(project.seconds / maxSeconds, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(project.project)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text(togglDurationText(project.seconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.64))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))

                    Capsule()
                        .fill(togglTrackThemeColor.opacity(0.56))
                        .frame(width: max(3, geometry.size.width * ratio))
                }
            }
            .frame(height: 4)
        }
    }
}

private func togglHoursText(_ seconds: TimeInterval) -> String {
    let hours = seconds / 60 / 60
    if hours >= 10 {
        return String(format: "%.0fh", hours)
    }
    return String(format: "%.1fh", hours)
}

private func togglDurationText(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int((seconds / 60).rounded()))
    let hoursComponent = minutes / 60
    let minutesComponent = minutes % 60

    if hoursComponent == 0 {
        return "\(minutesComponent)m"
    }
    if minutesComponent == 0 {
        return "\(hoursComponent)h"
    }
    return "\(hoursComponent)h \(minutesComponent)m"
}

private func togglCompactHoursText(_ seconds: TimeInterval) -> String {
    let hours = max(0, seconds / 60 / 60)
    guard hours > 0 else { return "0h" }

    let roundedHours = hours.rounded()
    if abs(hours - roundedHours) < 0.05 {
        return "\(Int(roundedHours))h"
    }
    if hours < 10 {
        return String(format: "%.1fh", hours)
    }
    return String(format: "%.0fh", hours)
}

private func togglWeekdayText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
}

private func togglWeekdayAccessibilityText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
}
