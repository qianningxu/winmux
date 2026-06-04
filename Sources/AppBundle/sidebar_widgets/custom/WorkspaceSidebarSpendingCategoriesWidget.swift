import Foundation
import SwiftUI

private let dollarGreenThemeColor = Color(red: 0x85 / 255, green: 0xBB / 255, blue: 0x65 / 255)

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
                    WorkspaceSidebarCompactSpendingCategoriesCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                        days: days,
                    )
                } else {
                    WorkspaceSidebarExpandedSpendingCategoriesCard(
                        snapshot: snapshot,
                        sectionWidth: sectionWidth,
                    )
                }
            }
        }
        .id(id)
    }
}

struct SpendingCategorySummary: Equatable, Identifiable, Sendable {
    let category: String
    let amount: Double
    let transactionCount: Int

    var id: String { category }
}

struct SpendingCategorySnapshot: Equatable, Sendable {
    var categories: [SpendingCategorySummary] = []
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
        let windowStart = now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
        var totalsByCategory: [String: (amount: Double, transactionCount: Int)] = [:]
        var scannedEntryCount = 0

        for url in entryUrls where url.pathExtension == "md" {
            guard let entry = SpendingEntry.parse(url: url, dateFormatters: dateFormatters) else { continue }
            scannedEntryCount += 1
            guard entry.created >= windowStart, entry.created <= now else { continue }

            var total = totalsByCategory[entry.category] ?? (amount: 0, transactionCount: 0)
            total.amount += entry.amount
            total.transactionCount += 1
            totalsByCategory[entry.category] = total
        }

        let categories = totalsByCategory
            .map { category, total in
                SpendingCategorySummary(
                    category: category,
                    amount: total.amount,
                    transactionCount: total.transactionCount,
                )
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount {
                    return lhs.amount > rhs.amount
                }
                return lhs.category.localizedStandardCompare(rhs.category) == .orderedAscending
            }

        return SpendingCategorySnapshot(
            categories: categories,
            totalAmount: categories.reduce(0) { $0 + $1.amount },
            scannedEntryCount: scannedEntryCount,
            transactionCount: categories.reduce(0) { $0 + $1.transactionCount },
            errorMessage: nil,
        )
    }

    private func makeSpendingDateFormatters() -> [ISO8601DateFormatter] {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let wholeSecondFormatter = ISO8601DateFormatter()
        wholeSecondFormatter.formatOptions = [.withInternetDateTime]

        return [fractionalFormatter, wholeSecondFormatter]
    }
}

private struct SpendingEntry {
    let created: Date
    let category: String
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
            category: spendingCategoryTitle(fields["category"] ?? ""),
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

private struct WorkspaceSidebarCompactSpendingCategoriesCard: View {
    let snapshot: SpendingCategorySnapshot
    let sectionWidth: CGFloat
    let days: Int

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            Image(systemName: "creditcard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(dollarGreenThemeColor.opacity(0.86))

            Text(spendingCurrencyText(snapshot.totalAmount, compact: true))
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
        return "Spending, \(spendingCurrencyText(snapshot.totalAmount)) in the last \(days) days"
    }
}

private struct WorkspaceSidebarExpandedSpendingCategoriesCard: View {
    let snapshot: SpendingCategorySnapshot
    let sectionWidth: CGFloat

    private var visibleCategories: [SpendingCategorySummary] {
        Array(snapshot.categories.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Spending", systemImage: "creditcard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(dollarGreenThemeColor.opacity(0.88))

                Spacer(minLength: 8)

                Text(spendingCurrencyText(snapshot.totalAmount))
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
            } else if visibleCategories.isEmpty {
                Text("No entries")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleCategories) { category in
                        SpendingCategoryRow(
                            category: category,
                            maxAmount: max(snapshot.categories.first?.amount ?? 0, 1),
                        )
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

private struct SpendingCategoryRow: View {
    let category: SpendingCategorySummary
    let maxAmount: Double

    private var ratio: CGFloat {
        CGFloat(max(0, min(abs(category.amount) / maxAmount, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(category.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text(spendingCurrencyText(category.amount))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.64))
                    .lineLimit(1)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(dollarGreenThemeColor.opacity(0.58))
                        .frame(width: max(3, geometry.size.width * ratio))
                }
            }
            .frame(height: 4)
        }
    }
}

private func spendingCategoryTitle(_ raw: String) -> String {
    let normalized = raw
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalized.isEmpty else {
        return "Uncategorized"
    }
    return normalized.capitalized
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
