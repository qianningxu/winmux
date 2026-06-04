@testable import AppBundle
import Foundation
import XCTest

final class WorkspaceSidebarTogglProjectsWidgetTest: XCTestCase {
    func testTogglProjectAggregatorGroupsEntriesByStartDate() throws {
        let entriesDirectory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-toggl-widget-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: entriesDirectory) }

        try writeEntry(
            entriesDirectory.appending(component: "2026-06-02 09.00.md"),
            start: "2026-06-02 09:00:00",
            stop: "2026-06-02 10:00:00",
            project: "Alpha",
        )
        try writeEntry(
            entriesDirectory.appending(component: "2026-06-01 10.00.md"),
            start: "2026-06-01 10:00:00",
            stop: "2026-06-01 12:00:00",
            project: "Alpha",
        )
        try writeEntry(
            entriesDirectory.appending(component: "2026-05-31 10.00.md"),
            start: "2026-05-31 10:00:00",
            stop: "2026-05-31 11:30:00",
            project: "",
        )
        try writeEntry(
            entriesDirectory.appending(component: "2026-05-30 23.30.md"),
            start: "2026-05-30 23:30:00",
            stop: "2026-05-31 00:30:00",
            project: "Boundary",
        )
        try writeEntry(
            entriesDirectory.appending(component: "2026-05-26 11.00.md"),
            start: "2026-05-26 11:00:00",
            stop: "2026-05-26 13:00:00",
            project: "Old boundary",
        )
        try writeEntry(
            entriesDirectory.appending(component: "2026-05-20 10.00.md"),
            start: "2026-05-20 10:00:00",
            stop: "2026-05-20 12:00:00",
            project: "Old",
        )

        let now = try XCTUnwrap(makeTogglTestDateFormatter().date(from: "2026-06-02 12:00:00"))
        let snapshot = TogglProjectTimeAggregator(entriesDirectory: entriesDirectory, days: 7).load(now: now)

        assertNil(snapshot.errorMessage)
        assertEquals(snapshot.projects.map(\.project), ["Alpha", "No project", "Boundary"])
        assertEquals(snapshot.projects.map { Int($0.seconds) }, [10_800, 5400, 3600])
        assertEquals(Int(snapshot.totalSeconds), 19_800)
        assertEquals(snapshot.scannedEntryCount, 6)
        assertEquals(snapshot.dailyFocus.map { dateKey($0.date) }, [
            "2026-05-27",
            "2026-05-28",
            "2026-05-29",
            "2026-05-30",
            "2026-05-31",
            "2026-06-01",
            "2026-06-02",
        ])
        assertEquals(snapshot.dailyFocus.map { Int($0.seconds) }, [0, 0, 0, 3600, 5400, 7200, 3600])
    }

    func testTogglProjectAggregatorReportsMissingDirectory() {
        let missingDirectory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-missing-\(UUID().uuidString)", directoryHint: .isDirectory)
        let snapshot = TogglProjectTimeAggregator(entriesDirectory: missingDirectory, days: 7).load()

        assertEquals(snapshot.errorMessage, "Can't read Toggl entries")
        assertEquals(snapshot.projects, [])
    }

    private func writeEntry(_ url: URL, start: String, stop: String, project: String) throws {
        let text =
            """
            ---
            start: "\(start)"
            stop: "\(stop)"
            duration: 0
            project: "\(project)"
            description: ""
            tags:
            ---
            """
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTogglTestDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = makeTogglTestDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
