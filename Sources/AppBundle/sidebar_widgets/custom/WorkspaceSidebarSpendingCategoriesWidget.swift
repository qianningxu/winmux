import Foundation
import SwiftUI

private let spendingThemeTextColor = workspaceSidebarWidgetColor(.color9)
private let spendingThemeFillColor = workspaceSidebarWidgetColor(.color7)
private let spendingWeekCount = 4
private let spendingDaysPerWeek = 7
private let spendingWeeklyWindowDays = spendingWeekCount * spendingDaysPerWeek

struct WorkspaceSidebarSpendingCategoriesWidget: View {
    let id: String
    let sectionWidth: CGFloat
    let isCompact: Bool
    let entriesPath: String
    let days: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 300)) { context in
            let snapshot = SpendingCategoryAggregator(
                entriesDirectory: URL(filePath: entriesPath, directoryHint: .isDirectory),
                days: days,
            ).load(now: context.date)

            Group {
                if isCompact {
                    WorkspaceSidebarCompactSpendingWeeksCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                } else {
                    WorkspaceSidebarExpandedSpendingWeeksCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                }
            }
        }
        .id(id)
    }
}

struct SpendingWeeklySummary: Equatable, Identifiable, Sendable {
    let startDate: Date
    let endDate: Date
    let amount: Double
    let transactionCount: Int

    var id: Date { startDate }
}

struct SpendingCategorySnapshot: Equatable, Sendable {
    var weeks: [SpendingWeeklySummary] = []
    var totalAmount: Double = 0
    var scannedEntryCount: Int = 0
    var transactionCount: Int = 0
    var errorMessage: String? = nil
}

struct SpendingCategoryAggregator: Sendable {
    let entriesDirectory: URL
    let days: Int

    func load(now: Date = Date()) -> SpendingCategorySnapshot {
        guard days > 0 else {
            return SpendingCategorySnapshot(errorMessage: "Invalid spending window")
        }

        if let sqliteURL = SidebarSelfDataStore.sqliteURL(for: entriesDirectory) {
            return loadFromSelfData(sqliteURL: sqliteURL, now: now)
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: entriesDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return SpendingCategorySnapshot(errorMessage: "Can't read spending entries")
        }

        let entryUrls: [URL]
        do {
            entryUrls = try fileManager.contentsOfDirectory(
                at: entriesDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles],
            )
        } catch {
            return SpendingCategorySnapshot(errorMessage: "Can't read spending entries")
        }

        let dateFormatters = makeSpendingDateFormatters()
        var calendar = Calendar.current
        calendar.locale = Locale.current
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(
            byAdding: .day,
            value: -(spendingWeeklyWindowDays - 1),
            to: todayStart,
        ) else {
            return SpendingCategorySnapshot(errorMessage: "Invalid spending window")
        }

        let chronologicalWeeks = Self.weekWindows(startingAt: windowStart, now: now, calendar: calendar)
        guard chronologicalWeeks.count == spendingWeekCount else {
            return SpendingCategorySnapshot(errorMessage: "Invalid spending window")
        }

        var totalsByWeek = Array(repeating: (amount: Double(0), transactionCount: 0), count: chronologicalWeeks.count)
        var scannedEntryCount = 0

        for url in entryUrls where url.pathExtension == "md" {
            guard let entry = SpendingEntry.parse(url: url, dateFormatters: dateFormatters) else { continue }
            scannedEntryCount += 1
            guard entry.created >= windowStart, entry.created <= now else { continue }
            guard let weekIndex = chronologicalWeeks.firstIndex(where: { $0.contains(entry.created) }) else {
                continue
            }

            var total = totalsByWeek[weekIndex]
            total.amount += entry.amount
            total.transactionCount += 1
            totalsByWeek[weekIndex] = total
        }

        let weeks = chronologicalWeeks.enumerated().reversed().map { index, week in
            let total = totalsByWeek[index]
            return SpendingWeeklySummary(
                startDate: week.startDate,
                endDate: week.endDate,
                amount: total.amount,
                transactionCount: total.transactionCount,
            )
        }

        return SpendingCategorySnapshot(
            weeks: weeks,
            totalAmount: weeks.reduce(0) { $0 + $1.amount },
            scannedEntryCount: scannedEntryCount,
            transactionCount: weeks.reduce(0) { $0 + $1.transactionCount },
            errorMessage: nil,
        )
    }

    private func loadFromSelfData(sqliteURL: URL, now: Date) -> SpendingCategorySnapshot {
        guard let transactions = SidebarSelfDataStore.loadSpendingTransactions(from: sqliteURL) else {
            return SpendingCategorySnapshot(errorMessage: "Can't read spending entries")
        }

        return summarize(
            entries: transactions.map { SpendingEntry(created: $0.created, amount: $0.amount) },
            scannedEntryCount: transactions.count,
            now: now,
        )
    }

    private func summarize(entries: [SpendingEntry], scannedEntryCount: Int, now: Date) -> SpendingCategorySnapshot {
        var calendar = Calendar.current
        calendar.locale = Locale.current
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(
            byAdding: .day,
            value: -(spendingWeeklyWindowDays - 1),
            to: todayStart,
        ) else {
            return SpendingCategorySnapshot(errorMessage: "Invalid spending window")
        }

        let chronologicalWeeks = Self.weekWindows(startingAt: windowStart, now: now, calendar: calendar)
        guard chronologicalWeeks.count == spendingWeekCount else {
            return SpendingCategorySnapshot(errorMessage: "Invalid spending window")
        }

        var totalsByWeek = Array(repeating: (amount: Double(0), transactionCount: 0), count: chronologicalWeeks.count)
        for entry in entries {
            guard entry.created >= windowStart, entry.created <= now else { continue }
            guard let weekIndex = chronologicalWeeks.firstIndex(where: { $0.contains(entry.created) }) else {
                continue
            }

            var total = totalsByWeek[weekIndex]
            total.amount += entry.amount
            total.transactionCount += 1
            totalsByWeek[weekIndex] = total
        }

        let weeks = chronologicalWeeks.enumerated().reversed().map { index, week in
            let total = totalsByWeek[index]
            return SpendingWeeklySummary(
                startDate: week.startDate,
                endDate: week.endDate,
                amount: total.amount,
                transactionCount: total.transactionCount,
            )
        }

        return SpendingCategorySnapshot(
            weeks: weeks,
            totalAmount: weeks.reduce(0) { $0 + $1.amount },
            scannedEntryCount: scannedEntryCount,
            transactionCount: weeks.reduce(0) { $0 + $1.transactionCount },
            errorMessage: nil,
        )
    }

    private static func weekWindows(
        startingAt windowStart: Date,
        now: Date,
        calendar: Calendar,
    ) -> [SpendingWeekWindow] {
        (0 ..< spendingWeekCount).compactMap { index in
            guard let startDate = calendar.date(
                byAdding: .day,
                value: index * spendingDaysPerWeek,
                to: windowStart,
            ),
                let endDate = calendar.date(
                    byAdding: .day,
                    value: spendingDaysPerWeek - 1,
                    to: startDate,
                )
            else {
                return nil
            }

            if index == spendingWeekCount - 1 {
                return SpendingWeekWindow(startDate: startDate, endDate: endDate, endExclusive: nil)
            }

            guard let endExclusive = calendar.date(
                byAdding: .day,
                value: spendingDaysPerWeek,
                to: startDate,
            ) else {
                return nil
            }
            return SpendingWeekWindow(startDate: startDate, endDate: endDate, endExclusive: endExclusive)
        }
    }

    private func makeSpendingDateFormatters() -> [ISO8601DateFormatter] {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let wholeSecondFormatter = ISO8601DateFormatter()
        wholeSecondFormatter.formatOptions = [.withInternetDateTime]

        return [fractionalFormatter, wholeSecondFormatter]
    }
}

private struct SpendingWeekWindow {
    let startDate: Date
    let endDate: Date
    let endExclusive: Date?

    func contains(_ date: Date) -> Bool {
        guard let endExclusive else {
            return date >= startDate
        }
        return date >= startDate && date < endExclusive
    }
}

private struct SpendingEntry {
    let created: Date
    let amount: Double

    static func parse(url: URL, dateFormatters: [ISO8601DateFormatter]) -> SpendingEntry? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let fields = SpendingFrontMatter.fields(in: text)
        guard let createdRaw = fields["created"],
              let created = dateFormatters.lazy.compactMap({ $0.date(from: createdRaw) }).first,
              let amountRaw = fields["amount"],
              let amount = Double(amountRaw)
        else {
            return nil
        }

        return SpendingEntry(
            created: created,
            amount: amount,
        )
    }
}

private enum SpendingFrontMatter {
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

private struct WorkspaceSidebarCompactSpendingWeeksCard: View {
    let snapshot: SpendingCategorySnapshot
    let sectionWidth: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: standardGap * 2.5) {
            Image(systemName: "creditcard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(spendingThemeTextColor)

            Text(spendingCurrencyText(snapshot.totalAmount, compact: true))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                    .foregroundStyle(workspaceSidebarWidgetContent(.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(spendingWeekCount)w")
                .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(workspaceSidebarWidgetContent(.secondary))
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
        return "Spending, \(spendingCurrencyText(snapshot.totalAmount)) in the past \(spendingWeekCount) weeks"
    }
}

private struct WorkspaceSidebarExpandedSpendingWeeksCard: View {
    let snapshot: SpendingCategorySnapshot
    let sectionWidth: CGFloat

    private var visibleWeeks: [SpendingWeeklySummary] {
        snapshot.weeks
    }

    private var maxWeeklyAmount: Double {
        max(visibleWeeks.map { abs($0.amount) }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: standardGap * 5) {
            HStack(alignment: .firstTextBaseline, spacing: standardGap * 4) {
                Label("Spending", systemImage: "creditcard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(spendingThemeTextColor)

                Spacer(minLength: 8)

                Text(spendingCurrencyText(snapshot.totalAmount))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(workspaceSidebarWidgetContent(.primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let errorMessage = snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(workspaceSidebarWidgetContent(.secondary))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: standardGap * 4) {
                    ForEach(visibleWeeks) { week in
                        SpendingWeekRow(
                            week: week,
                            maxAmount: maxWeeklyAmount,
                        )
                    }
                }

            }
        }
        .padding(.horizontal, standardGap * 6)
        .padding(.vertical, standardGap * 5.5)
        .frame(width: sectionWidth, alignment: .leading)
        .background(WorkspaceSidebarStatusCardBackground())
        .accessibilityElement(children: .combine)
    }
}

private struct SpendingWeekRow: View {
    let week: SpendingWeeklySummary
    let maxAmount: Double

    private var ratio: CGFloat {
        CGFloat(max(0, min(abs(week.amount) / maxAmount, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: standardGap * 2) {
            HStack(alignment: .firstTextBaseline, spacing: standardGap * 4) {
                Text(spendingWeekStartText(week.startDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(workspaceSidebarWidgetContent(.primary))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text(spendingCurrencyText(week.amount))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(workspaceSidebarWidgetContent(week.transactionCount > 0 ? .primary : .secondary))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(workspaceSidebarWidgetComponentBackground(.normal))

                    if week.transactionCount > 0 {
                        Capsule()
                            .fill(spendingThemeFillColor)
                            .frame(width: max(3, geometry.size.width * ratio))
                    }
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "\(spendingWeekStartText(week.startDate)), \(spendingCurrencyText(week.amount))",
        ))
    }
}

private func spendingCurrencyText(_ amount: Double, compact: Bool = false) -> String {
    let sign = amount < 0 ? "-" : ""
    let absoluteAmount = abs(amount)
    let pound = "\u{00A3}"

    if compact {
        if absoluteAmount >= 1000 {
            return "\(sign)\(pound)\(String(format: "%.1fk", absoluteAmount / 1000))"
        }
        if absoluteAmount >= 10 {
            return "\(sign)\(pound)\(String(format: "%.0f", absoluteAmount))"
        }
        return "\(sign)\(pound)\(String(format: "%.2f", absoluteAmount))"
    }

    if absoluteAmount >= 100 {
        return "\(sign)\(pound)\(String(format: "%.0f", absoluteAmount))"
    }
    return "\(sign)\(pound)\(String(format: "%.2f", absoluteAmount))"
}

private func spendingWeekStartText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date)
}
