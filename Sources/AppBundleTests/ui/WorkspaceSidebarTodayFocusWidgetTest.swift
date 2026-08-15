@testable import AppBundle
import Foundation
import SQLite3
import XCTest

final class WorkspaceSidebarTodayFocusWidgetTest: XCTestCase {
    func testAggregatorReadsTodayFocusFromSelfDataSQLite() throws {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        defer { NSTimeZone.default = previousTimeZone }

        let dataDirectory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-today-focus-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dataDirectory) }

        let sqliteURL = dataDirectory.appending(component: "self_data.sqlite")
        try makeDatabase(at: sqliteURL)
        try execute(
            """
            insert into time_entries (start_at_utc, stop_at_utc, duration_seconds) values
                ('2026-07-28T23:00:00Z', '2026-07-29T01:00:00Z', 7200),
                ('2026-07-29T08:00:00Z', '2026-07-29T12:00:00Z', 14400),
                ('2026-07-30T08:00:00Z', '2026-07-30T09:00:00Z', 3600);
            """,
            at: sqliteURL,
        )

        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-29T10:00:00Z"))
        let snapshot = TodayFocusAggregator(dataSource: dataDirectory).load(now: now)

        assertNil(snapshot.errorMessage)
        XCTAssertEqual(snapshot.focusedSeconds, 3 * 3600, accuracy: 1)
        assertEquals(snapshot.targetHours, 11)
        assertEquals(snapshot.percentage, 27)
    }

    func testAggregatorReportsMissingSelfData() {
        let missing = FileManager.default.temporaryDirectory
            .appending(component: "missing-self-data-\(UUID().uuidString)", directoryHint: .isDirectory)
        let snapshot = TodayFocusAggregator(dataSource: missing).load()
        assertEquals(snapshot.errorMessage, "Can't read self_data")
    }

    func testAggregatorUsesConfiguredDailyTargets() throws {
        let missing = FileManager.default.temporaryDirectory
            .appending(component: "missing-self-data-\(UUID().uuidString)", directoryHint: .isDirectory)
        let formatter = ISO8601DateFormatter()

        let sunday = try XCTUnwrap(formatter.date(from: "2026-08-02T12:00:00Z"))
        let monday = try XCTUnwrap(formatter.date(from: "2026-08-03T12:00:00Z"))
        let tuesday = try XCTUnwrap(formatter.date(from: "2026-08-04T12:00:00Z"))

        XCTAssertEqual(TodayFocusAggregator(dataSource: missing).load(now: sunday).targetHours, 11)
        XCTAssertEqual(TodayFocusAggregator(dataSource: missing).load(now: monday).targetHours, 11)
        XCTAssertEqual(TodayFocusAggregator(dataSource: missing).load(now: tuesday).targetHours, 6)
    }

    func testAggregatorRetriesAReadThatIsBrieflyUnavailable() throws {
        let dataDirectory = FileManager.default.temporaryDirectory
            .appending(component: "winmux-today-focus-retry-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dataDirectory) }

        let sqliteURL = dataDirectory.appending(component: "self_data.sqlite")
        try makeDatabase(at: sqliteURL)
        try execute(
            """
            insert into time_entries (start_at_utc, stop_at_utc, duration_seconds) values
                ('2026-07-29T08:00:00Z', '2026-07-29T09:00:00Z', 3600);
            """,
            at: sqliteURL,
        )

        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: sqliteURL.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sqliteURL.path)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: sqliteURL.path)
        }

        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-29T10:00:00Z"))
        let snapshot = TodayFocusAggregator(dataSource: dataDirectory).load(now: now)

        assertNil(snapshot.errorMessage)
        XCTAssertEqual(snapshot.focusedSeconds, 3600, accuracy: 1)
    }

    private func makeDatabase(at url: URL) throws {
        try execute(
            """
            create table time_entries (
                start_at_utc text not null,
                stop_at_utc text,
                duration_seconds real not null
            );
            """,
            at: url,
        )
    }

    private func execute(_ sql: String, at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "WorkspaceSidebarTodayFocusWidgetTest", code: 1)
        }
        defer { sqlite3_close(database) }

        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "SQLite error"
            sqlite3_free(errorMessage)
            throw NSError(
                domain: "WorkspaceSidebarTodayFocusWidgetTest",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message],
            )
        }
    }
}
