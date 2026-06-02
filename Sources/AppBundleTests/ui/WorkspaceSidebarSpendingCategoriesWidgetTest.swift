@testable import AppBundle
import Foundation
import XCTest

final class WorkspaceSidebarSpendingCategoriesWidgetTest: XCTestCase {
    func testSpendingCategoryAggregatorSummarizesPastThirtyDays() throws {
        let entriesDirectory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-spending-widget-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: entriesDirectory) }

        try writeEntry(
            entriesDirectory.appending(component: "groceries-one.md"),
            created: "2026-06-01T10:00:00.000Z",
            amount: 12.50,
            category: "groceries",
        )
        try writeEntry(
            entriesDirectory.appending(component: "groceries-two.md"),
            created: "2026-05-20T09:00:00Z",
            amount: 2.50,
            category: "groceries",
        )
        try writeEntry(
            entriesDirectory.appending(component: "eating-out.md"),
            created: "2026-05-16T09:00:00.000Z",
            amount: 10,
            category: "eating_out",
        )
        try writeEntry(
            entriesDirectory.appending(component: "transport.md"),
            created: "2026-05-10T09:00:00.000Z",
            amount: 5,
            category: "transport",
        )
        try writeEntry(
            entriesDirectory.appending(component: "old.md"),
            created: "2026-04-20T09:00:00.000Z",
            amount: 100,
            category: "shopping",
        )
        try writeEntry(
            entriesDirectory.appending(component: "future.md"),
            created: "2026-06-03T09:00:00.000Z",
            amount: 40,
            category: "shopping",
        )

        let now = try XCTUnwrap(makeSpendingTestDateFormatter().date(from: "2026-06-02T12:00:00.000Z"))
        let snapshot = SpendingCategoryAggregator(entriesDirectory: entriesDirectory, days: 30).load(now: now)

        assertNil(snapshot.errorMessage)
        assertEquals(snapshot.categories.map(\.category), ["Groceries", "Eating Out", "Transport"])
        assertEquals(snapshot.categories.map { Int(($0.amount * 100).rounded()) }, [1500, 1000, 500])
        assertEquals(snapshot.categories.map(\.transactionCount), [2, 1, 1])
        assertEquals(Int((snapshot.totalAmount * 100).rounded()), 3000)
        assertEquals(snapshot.transactionCount, 4)
        assertEquals(snapshot.scannedEntryCount, 6)
    }

    func testSpendingCategoryAggregatorReportsMissingDirectory() {
        let missingDirectory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-missing-\(UUID().uuidString)", directoryHint: .isDirectory)
        let snapshot = SpendingCategoryAggregator(entriesDirectory: missingDirectory, days: 30).load()

        assertEquals(snapshot.errorMessage, "Can't read spending entries")
        assertEquals(snapshot.categories, [])
    }

    private func writeEntry(_ url: URL, created: String, amount: Double, category: String) throws {
        let text =
            """
            ---
            created: "\(created)"
            description: ""
            merchant_name: "Test"
            amount: \(amount)
            category: "\(category)"
            ---
            """
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeSpendingTestDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
