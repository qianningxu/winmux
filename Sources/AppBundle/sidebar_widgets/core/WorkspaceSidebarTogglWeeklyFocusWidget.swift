import Foundation
import SwiftUI

private let togglPeriodFocusColor = Color(red: 0xE5 / 255, green: 0x7C / 255, blue: 0xD8 / 255)
private let togglWeekFocusColor = Color(red: 0x5E / 255, green: 0xC7 / 255, blue: 0xF2 / 255)
private let togglWeeklyFocusMaxDailySeconds: TimeInterval = 4.5 * 60 * 60
private let togglWeeklyFocusStartDateString = "2026-06-14"

struct WorkspaceSidebarTogglWeeklyFocusWidget: View {
    let id: String
    let sectionWidth: CGFloat
    let isCompact: Bool
    let entriesPath: String
    let targetDate: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = TogglWeeklyFocusAggregator(
                entriesDirectory: URL(filePath: entriesPath, directoryHint: .isDirectory),
                targetDateString: targetDate,
            ).load(now: context.date)

            Group {
                if isCompact {
                    WorkspaceSidebarCompactTogglWeeklyFocusCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                } else {
                    WorkspaceSidebarExpandedTogglWeeklyFocusCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                }
            }
        }
        .id(id)
    }
}

struct WorkspaceSidebarTogglWeekFocusWidget: View {
    let id: String
    let sectionWidth: CGFloat
    let isCompact: Bool
    let entriesPath: String
    let targetDate: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = TogglWeeklyFocusAggregator(
                entriesDirectory: URL(filePath: entriesPath, directoryHint: .isDirectory),
                targetDateString: targetDate,
            ).load(now: context.date)

            Group {
                if isCompact {
                    WorkspaceSidebarCompactTogglWeekFocusCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                } else {
                    WorkspaceSidebarExpandedTogglWeekFocusCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                }
            }
        }
        .id(id)
    }
}

struct TogglWeeklyFocusWeek: Equatable, Identifiable, Sendable {
    let startDate: Date
    let endDate: Date
    let dayCount: Int
    let totalSeconds: TimeInterval
    let isFuture: Bool
    let isCurrent: Bool

    var id: Date { startDate }

    var averageDailySeconds: TimeInterval {
        guard dayCount > 0 else { return 0 }
        return totalSeconds / TimeInterval(dayCount)
    }
}

struct TogglWeeklyFocusDay: Equatable, Identifiable, Sendable {
    let date: Date
    let totalSeconds: TimeInterval
    let isToday: Bool
    let isFuture: Bool

    var id: Date { date }
}

struct TogglWeeklyFocusSnapshot: Equatable, Sendable {
    var weeks: [TogglWeeklyFocusWeek] = []
    var days: [TogglWeeklyFocusDay] = []
    var averageDailySeconds: TimeInterval = 0
    var currentWeekDailyAverageSeconds: TimeInterval = 0
    var totalWeekSeconds: TimeInterval = 0
    var weeksLeft: Int = 0
    var scannedEntryCount: Int = 0
    var errorMessage: String? = nil
}

struct TogglWeeklyFocusAggregator: Sendable {
    let entriesDirectory: URL
    let targetDateString: String

    func load(now: Date = Date()) -> TogglWeeklyFocusSnapshot {
        if let sqliteURL = SidebarSelfDataStore.sqliteURL(for: entriesDirectory) {
            return loadFromSelfData(sqliteURL: sqliteURL, now: now)
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: entriesDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return TogglWeeklyFocusSnapshot(errorMessage: "Can't read Toggl entries")
        }

        let entryUrls: [URL]
        do {
            entryUrls = try fileManager.contentsOfDirectory(
                at: entriesDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles],
            )
        } catch {
            return TogglWeeklyFocusSnapshot(errorMessage: "Can't read Toggl entries")
        }

        let entryFormatter = Self.makeTogglDateFormatter()
        var entries: [TogglWeeklyFocusEntry] = []

        for url in entryUrls where url.pathExtension == "md" {
            guard let entry = TogglWeeklyFocusEntry.parse(url: url, formatter: entryFormatter, now: now) else { continue }
            entries.append(entry)
        }

        return summarize(entries: entries, scannedEntryCount: entries.count, now: now)
    }

    private func loadFromSelfData(sqliteURL: URL, now: Date) -> TogglWeeklyFocusSnapshot {
        guard let entries = SidebarSelfDataStore.loadTimeEntries(from: sqliteURL, now: now) else {
            return TogglWeeklyFocusSnapshot(errorMessage: "Can't read Toggl entries")
        }

        return summarize(
            entries: entries.map { TogglWeeklyFocusEntry(start: $0.start, stop: $0.stop) },
            scannedEntryCount: entries.count,
            now: now,
        )
    }

    private func summarize(entries: [TogglWeeklyFocusEntry], scannedEntryCount: Int, now: Date) -> TogglWeeklyFocusSnapshot {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        calendar.locale = Locale.current
        let todayStart = calendar.startOfDay(for: now)
        let targetDateFormatter = Self.makeTargetDateFormatter()
        guard let rawTargetDate = targetDateFormatter.date(from: targetDateString) else {
            return TogglWeeklyFocusSnapshot(errorMessage: "Invalid target date")
        }
        let targetDay = calendar.startOfDay(for: rawTargetDate)
        guard targetDay >= todayStart else {
            return TogglWeeklyFocusSnapshot(errorMessage: "Target date has passed")
        }

        guard let weekStart = Self.focusStartDay(calendar: calendar), weekStart <= targetDay else {
            return TogglWeeklyFocusSnapshot(errorMessage: "Invalid target window")
        }
        let weeks = Self.weekWindows(startingAt: weekStart, targetDay: targetDay, calendar: calendar)
        guard !weeks.isEmpty else {
            return TogglWeeklyFocusSnapshot(errorMessage: "Invalid target window")
        }

        var totalsByWeek = Array(repeating: TimeInterval(0), count: weeks.count)
        let currentWeekDays = Self.currentWeekDays(containing: todayStart, calendar: calendar) ?? []
        var totalsByDay = Array(repeating: TimeInterval(0), count: currentWeekDays.count)
        for entry in entries {
            for index in weeks.indices {
                guard weeks[index].contains(entry.start) else { continue }
                totalsByWeek[index] += entry.stop.timeIntervalSince(entry.start)
                break
            }
            for index in currentWeekDays.indices {
                guard currentWeekDays[index].contains(entry.start) else { continue }
                totalsByDay[index] += entry.stop.timeIntervalSince(entry.start)
                break
            }
        }

        let summarizedWeeks = weeks.enumerated().map { index, week -> TogglWeeklyFocusWeek in
            let isCurrent = week.contains(todayStart)
            let dayCount = isCurrent
                ? Self.elapsedDayCount(from: week.startDate, to: todayStart, maxCount: week.dayCount, calendar: calendar)
                : week.dayCount
            return TogglWeeklyFocusWeek(
                startDate: week.startDate,
                endDate: week.endDate,
                dayCount: dayCount,
                totalSeconds: totalsByWeek[index],
                isFuture: week.startDate > todayStart,
                isCurrent: isCurrent,
            )
        }
        let currentAverage = summarizedWeeks.first(where: \.isCurrent)?.averageDailySeconds
            ?? summarizedWeeks.first?.averageDailySeconds
            ?? 0
        let weeksLeft = max(0, summarizedWeeks.filter { $0.startDate > todayStart }.count)
        let summarizedDays = currentWeekDays.enumerated().map { index, day -> TogglWeeklyFocusDay in
            TogglWeeklyFocusDay(
                date: day.startDate,
                totalSeconds: totalsByDay[index],
                isToday: day.contains(todayStart),
                isFuture: day.startDate > todayStart,
            )
        }
        let currentWeekElapsedDayCount = max(1, summarizedDays.filter { !$0.isFuture }.count)
        let totalWeekSeconds = totalsByDay.reduce(0, +)

        return TogglWeeklyFocusSnapshot(
            weeks: summarizedWeeks,
            days: summarizedDays,
            averageDailySeconds: currentAverage,
            currentWeekDailyAverageSeconds: totalWeekSeconds / TimeInterval(currentWeekElapsedDayCount),
            totalWeekSeconds: totalWeekSeconds,
            weeksLeft: weeksLeft,
            scannedEntryCount: scannedEntryCount,
            errorMessage: nil,
        )
    }

    private static func currentWeekDays(containing day: Date, calendar: Calendar) -> [TogglWeeklyFocusDayWindow]? {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start else {
            return nil
        }
        let dayCount = calendar.range(of: .weekday, in: .weekOfYear, for: day)?.count ?? 7
        return (0 ..< dayCount).compactMap { offset in
            guard let startDate = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let endExclusive = calendar.date(byAdding: .day, value: 1, to: startDate)
            else {
                return nil
            }
            return TogglWeeklyFocusDayWindow(startDate: startDate, endExclusive: endExclusive)
        }
    }

    private static func weekWindows(
        startingAt startDate: Date,
        targetDay: Date,
        calendar: Calendar,
    ) -> [TogglWeeklyFocusWeekWindow] {
        var result: [TogglWeeklyFocusWeekWindow] = []
        var currentStart = startDate

        while currentStart <= targetDay {
            guard let nextStart = calendar.date(byAdding: .day, value: 7, to: currentStart),
                  let fullWeekEnd = calendar.date(byAdding: .day, value: 6, to: currentStart)
            else {
                break
            }

            let endDate = min(fullWeekEnd, targetDay)
            let dayCount = (calendar.dateComponents([.day], from: currentStart, to: endDate).day ?? 0) + 1
            result.append(TogglWeeklyFocusWeekWindow(
                startDate: currentStart,
                endDate: endDate,
                endExclusive: nextStart,
                dayCount: max(1, dayCount),
            ))
            currentStart = nextStart
        }

        return result
    }

    private static func elapsedDayCount(
        from startDate: Date,
        to day: Date,
        maxCount: Int,
        calendar: Calendar,
    ) -> Int {
        let elapsedDays = (calendar.dateComponents([.day], from: startDate, to: day).day ?? 0) + 1
        return max(1, min(elapsedDays, maxCount))
    }

    private static func focusStartDay(calendar: Calendar) -> Date? {
        makeTargetDateFormatter().date(from: togglWeeklyFocusStartDateString).map {
            calendar.startOfDay(for: $0)
        }
    }

    private static func makeTogglDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func makeTargetDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

private struct TogglWeeklyFocusWeekWindow {
    let startDate: Date
    let endDate: Date
    let endExclusive: Date
    let dayCount: Int

    func contains(_ date: Date) -> Bool {
        date >= startDate && date < endExclusive
    }
}

private struct TogglWeeklyFocusDayWindow {
    let startDate: Date
    let endExclusive: Date

    func contains(_ date: Date) -> Bool {
        date >= startDate && date < endExclusive
    }
}

private struct TogglWeeklyFocusEntry {
    let start: Date
    let stop: Date

    static func parse(url: URL, formatter: DateFormatter, now: Date) -> TogglWeeklyFocusEntry? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let fields = TogglWeeklyFocusFrontMatter.fields(in: text)
        guard let startRaw = fields["start"], let start = formatter.date(from: startRaw) else { return nil }

        let stop = fields["stop"].flatMap { rawStop -> Date? in
            rawStop.isEmpty ? nil : formatter.date(from: rawStop)
        }
            ?? fields["duration"]
                .flatMap(Double.init)
                .map { start.addingTimeInterval($0 * 60 * 60) }
        guard let stop else { return nil }

        let effectiveStop = min(stop, now)
        guard effectiveStop > start else { return nil }
        return TogglWeeklyFocusEntry(start: start, stop: effectiveStop)
    }
}

private enum TogglWeeklyFocusFrontMatter {
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

private struct WorkspaceSidebarCompactTogglWeeklyFocusCard: View {
    let snapshot: TogglWeeklyFocusSnapshot
    let sectionWidth: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: 7) {
            TogglPeriodFocusIcon()
                .frame(width: 18, height: 18)
                .foregroundStyle(togglPeriodFocusColor.opacity(0.90))
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(togglPeriodFocusColor.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(togglPeriodFocusColor.opacity(0.44), lineWidth: 1)
                        }
                }

            if let errorMessage = snapshot.errorMessage {
                Text("!")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(winMuxOverlayForeground(0.90))
                    .lineLimit(1)
                    .help(errorMessage)
            } else {
                Text(togglWeeklyFocusCompactHoursText(snapshot.averageDailySeconds))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(winMuxOverlayForeground(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(spacing: 1) {
                    Text("\(snapshot.weeksLeft)w")
                    Text("left")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(winMuxOverlayMutedForeground(0.78))
                .lineLimit(1)
            }
        }
        .frame(width: sectionWidth, height: 150, alignment: .center)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        if let errorMessage = snapshot.errorMessage {
            return errorMessage
        }
        return "Period, \(togglWeeklyFocusAccessibilityHoursText(snapshot.averageDailySeconds)) average daily focus, \(snapshot.weeksLeft) weeks left"
    }
}

private struct WorkspaceSidebarExpandedTogglWeeklyFocusCard: View {
    let snapshot: TogglWeeklyFocusSnapshot
    let sectionWidth: CGFloat

    private var guideRatio: CGFloat {
        CGFloat(max(0, min(snapshot.averageDailySeconds / togglWeeklyFocusMaxDailySeconds, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 6) {
                    TogglPeriodFocusIcon()
                        .frame(width: 13, height: 13)
                    Text("Period")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(togglPeriodFocusColor.opacity(0.88))

                Spacer(minLength: 8)

                if snapshot.errorMessage == nil {
                    Text("\(snapshot.weeksLeft)w left")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(winMuxOverlayForeground(0.92))
                        .lineLimit(1)
                }
            }

            if let errorMessage = snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.80))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if snapshot.weeks.isEmpty {
                Text("No weeks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TogglWeeklyFocusChart(
                    weeks: snapshot.weeks,
                    averageDailySeconds: snapshot.averageDailySeconds,
                    guideRatio: guideRatio,
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: sectionWidth, alignment: .leading)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .combine)
    }
}

private struct WorkspaceSidebarCompactTogglWeekFocusCard: View {
    let snapshot: TogglWeeklyFocusSnapshot
    let sectionWidth: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: 7) {
            TogglWeekFocusIcon()
                .frame(width: 18, height: 18)
                .foregroundStyle(togglWeekFocusColor.opacity(0.90))
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(togglWeekFocusColor.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(togglWeekFocusColor.opacity(0.44), lineWidth: 1)
                        }
                }

            if let errorMessage = snapshot.errorMessage {
                Text("!")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(winMuxOverlayForeground(0.90))
                    .lineLimit(1)
                    .help(errorMessage)
            } else {
                Text(togglWeeklyFocusCompactHoursText(snapshot.currentWeekDailyAverageSeconds))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(winMuxOverlayForeground(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(spacing: 1) {
                    Text("this")
                    Text("week")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(winMuxOverlayMutedForeground(0.78))
                .lineLimit(1)
            }
        }
        .frame(width: sectionWidth, height: 150, alignment: .center)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var accessibilitySummary: String {
        if let errorMessage = snapshot.errorMessage {
            return errorMessage
        }
        return "Focus of the week, \(togglWeeklyFocusAccessibilityHoursText(snapshot.currentWeekDailyAverageSeconds)) daily average"
    }
}

private struct WorkspaceSidebarExpandedTogglWeekFocusCard: View {
    let snapshot: TogglWeeklyFocusSnapshot
    let sectionWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 6) {
                    TogglWeekFocusIcon()
                        .frame(width: 13, height: 13)
                    Text("Week")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(togglWeekFocusColor.opacity(0.88))

                Spacer(minLength: 8)

                if snapshot.errorMessage == nil {
                    Text(togglWeeklyFocusCompactHoursText(snapshot.totalWeekSeconds))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(winMuxOverlayForeground(0.92))
                        .lineLimit(1)
                }
            }

            if let errorMessage = snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.80))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if snapshot.days.isEmpty {
                Text("No days")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(winMuxOverlayMutedForeground(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TogglWeeklyFocusDayList(days: snapshot.days)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: sectionWidth, alignment: .leading)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .combine)
    }
}

private struct TogglWeeklyFocusChart: View {
    let weeks: [TogglWeeklyFocusWeek]
    let averageDailySeconds: TimeInterval
    let guideRatio: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                        TogglWeeklyFocusWeekRow(
                            week: week,
                            labelText: togglWeeklyFocusWeekLabelText(for: week, previousWeek: weeks.getOrNil(atIndex: index - 1)),
                        )
                    }
                }

                let guideX = max(0, min(geometry.size.width * guideRatio, geometry.size.width))
                Rectangle()
                    .fill(winMuxOverlayForeground(0.30))
                    .frame(width: 1)
                    .position(x: guideX, y: geometry.size.height / 2)

                Text(togglWeeklyFocusCompactHoursText(averageDailySeconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(winMuxOverlayForeground(0.92))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(winMuxOverlayCard(0.96))
                            .overlay {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(winMuxOverlayBorder(0.70), lineWidth: 1)
                            }
                            .shadow(color: winMuxOverlayShadow(darkOpacity: 0.18, lightOpacity: 0.12), radius: 8, y: 3)
                    }
                    .position(x: guideX, y: geometry.size.height / 2)
            }
        }
        .frame(height: chartHeight)
    }

    private var chartHeight: CGFloat {
        CGFloat(weeks.count) * 22 + CGFloat(max(weeks.count - 1, 0)) * 6
    }
}

private struct TogglWeeklyFocusWeekRow: View {
    let week: TogglWeeklyFocusWeek
    let labelText: String

    private var ratio: CGFloat {
        CGFloat(max(0, min(week.averageDailySeconds / togglWeeklyFocusMaxDailySeconds, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(labelText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(week.isFuture ? winMuxOverlayMutedForeground(0.62) : winMuxOverlayForeground(0.88))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(week.isFuture ? "--" : togglWeeklyFocusCompactHoursText(week.averageDailySeconds))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(week.isFuture ? winMuxOverlayMutedForeground(0.48) : winMuxOverlayMutedForeground(0.90))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(winMuxOverlayContrastingFill(darkOpacity: week.isFuture ? 0.045 : 0.07, lightOpacity: week.isFuture ? 0.05 : 0.07))

                    if !week.isFuture, week.averageDailySeconds > 0 {
                        Capsule()
                            .fill(togglPeriodFocusColor.opacity(0.56))
                            .frame(width: max(3, geometry.size.width * ratio))
                    }
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        if week.isFuture {
            return "\(labelText), future week"
        }
        return "\(labelText), \(togglWeeklyFocusAccessibilityHoursText(week.averageDailySeconds)) average daily focus"
    }
}

private struct TogglWeeklyFocusDayList: View {
    let days: [TogglWeeklyFocusDay]

    private var maxSeconds: TimeInterval {
        max(togglWeeklyFocusMaxDailySeconds, days.map(\.totalSeconds).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(days) { day in
                TogglWeeklyFocusDayRow(day: day, maxSeconds: maxSeconds)
            }
        }
    }
}

private struct TogglWeeklyFocusDayRow: View {
    let day: TogglWeeklyFocusDay
    let maxSeconds: TimeInterval

    private var ratio: CGFloat {
        guard maxSeconds > 0 else { return 0 }
        return CGFloat(max(0, min(day.totalSeconds / maxSeconds, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(togglWeeklyFocusDayLabelText(for: day.date))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(day.isFuture ? winMuxOverlayMutedForeground(0.62) : winMuxOverlayForeground(0.88))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(day.isFuture ? "--" : togglWeeklyFocusCompactHoursText(day.totalSeconds))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(day.isFuture ? winMuxOverlayMutedForeground(0.48) : winMuxOverlayMutedForeground(0.90))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(winMuxOverlayContrastingFill(darkOpacity: day.isFuture ? 0.045 : 0.07, lightOpacity: day.isFuture ? 0.05 : 0.07))

                    if !day.isFuture, day.totalSeconds > 0 {
                        Capsule()
                            .fill(togglWeekFocusColor.opacity(day.isToday ? 0.76 : 0.50))
                            .frame(width: max(3, geometry.size.width * ratio))
                    }
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        let labelText = togglWeeklyFocusDayLabelText(for: day.date)
        if day.isFuture {
            return "\(labelText), future day"
        }
        return "\(labelText), \(togglWeeklyFocusAccessibilityHoursText(day.totalSeconds)) focus"
    }
}

private struct TogglPeriodFocusIcon: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let lineWidth = max(1.2, size.width * 0.075)
            let circle = rect.insetBy(dx: size.width * 0.08, dy: size.height * 0.08)
            var path = Path(ellipseIn: circle)
            context.stroke(path, with: .foreground, lineWidth: lineWidth)

            path = Path(ellipseIn: rect.insetBy(dx: size.width * 0.27, dy: size.height * 0.27))
            context.stroke(path, with: .foreground, lineWidth: lineWidth)

            path = Path()
            path.addEllipse(in: CGRect(
                x: size.width * 0.45,
                y: size.height * 0.45,
                width: size.width * 0.10,
                height: size.height * 0.10,
            ))
            context.fill(path, with: .foreground)
        }
    }
}

private struct TogglWeekFocusIcon: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let lineWidth = max(1.2, size.width * 0.075)
            let calendarRect = rect.insetBy(dx: size.width * 0.12, dy: size.height * 0.14)
            let radius = min(size.width, size.height) * 0.12
            var path = Path(roundedRect: calendarRect, cornerRadius: radius)
            context.stroke(path, with: .foreground, lineWidth: lineWidth)

            path = Path()
            path.move(to: CGPoint(x: calendarRect.minX, y: calendarRect.minY + calendarRect.height * 0.30))
            path.addLine(to: CGPoint(x: calendarRect.maxX, y: calendarRect.minY + calendarRect.height * 0.30))
            context.stroke(path, with: .foreground, lineWidth: lineWidth)

            for xRatio in [0.32, 0.50, 0.68] {
                for yRatio in [0.50, 0.68] {
                    path = Path(ellipseIn: CGRect(
                        x: size.width * xRatio - size.width * 0.035,
                        y: size.height * yRatio - size.height * 0.035,
                        width: size.width * 0.07,
                        height: size.height * 0.07,
                    ))
                    context.fill(path, with: .foreground)
                }
            }
        }
    }
}

private func togglWeeklyFocusCompactHoursText(_ seconds: TimeInterval) -> String {
    let hours = seconds / 60 / 60
    if hours >= 10 {
        return String(format: "%.0fh", hours)
    }
    return String(format: "%.1fh", hours)
}

private func togglWeeklyFocusAccessibilityHoursText(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int((seconds / 60).rounded()))
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if hours == 0 {
        return "\(remainingMinutes) minutes"
    }
    if remainingMinutes == 0 {
        return "\(hours) hours"
    }
    return "\(hours) hours \(remainingMinutes) minutes"
}

func togglWeeklyFocusWeekLabelText(for week: TogglWeeklyFocusWeek, previousWeek: TogglWeeklyFocusWeek?) -> String {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .current
    let month = calendar.component(.month, from: week.startDate)
    let previousMonth = previousWeek.map { calendar.component(.month, from: $0.startDate) }
    if previousMonth != nil, previousMonth != month {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: week.startDate).uppercased()
    }
    return "\(calendar.component(.day, from: week.startDate))\(togglWeeklyFocusOrdinalSuffix(for: week.startDate, calendar: calendar))"
}

func togglWeeklyFocusDayLabelText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "EEE"
    return formatter.string(from: date).uppercased()
}

private func togglWeeklyFocusOrdinalSuffix(for date: Date, calendar: Calendar) -> String {
    let day = calendar.component(.day, from: date)
    let teenRemainder = day % 100
    if 11 ... 13 ~= teenRemainder {
        return "th"
    }
    switch day % 10 {
        case 1:
            return "st"
        case 2:
            return "nd"
        case 3:
            return "rd"
        default:
            return "th"
    }
}
