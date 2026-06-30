import Foundation
import SQLite3

struct SidebarSelfDataTimeEntry: Sendable {
    let start: Date
    let stop: Date
}

struct SidebarSelfDataScheduleBlock: Sendable {
    let identity: String
    let fileDate: Date
    let sessionNumber: Int
    let sessionName: String
    let from: Date
    let to: Date
    let done: Bool
}

struct SidebarSelfDataSpendingTransaction: Sendable {
    let created: Date
    let amount: Double
}

enum SidebarSelfDataStore {
    static func sqliteURL(for source: URL) -> URL? {
        if source.pathExtension == "sqlite", FileManager.default.fileExists(atPath: source.path) {
            return source
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        let candidate = source.appending(component: "self_data.sqlite")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    static func loadTimeEntries(from sqliteURL: URL, now: Date) -> [SidebarSelfDataTimeEntry]? {
        withDatabase(sqliteURL) { database in
            query(database, sql: "select start_at_utc, stop_at_utc, duration_seconds from time_entries") { statement in
                guard let start = dateColumn(statement, 0) else { return nil }
                let rawStop = dateColumn(statement, 1)
                let durationSeconds = sqlite3_column_double(statement, 2)
                let stop = rawStop ?? start.addingTimeInterval(durationSeconds)
                let effectiveStop = min(stop, now)
                guard effectiveStop > start else { return nil }
                return SidebarSelfDataTimeEntry(start: start, stop: effectiveStop)
            }
        }
    }

    static func loadScheduleBlocks(from sqliteURL: URL) -> [SidebarSelfDataScheduleBlock]? {
        withDatabase(sqliteURL) { database in
            query(
                database,
                sql: "select id, session_name, start_at_utc, end_at_utc, local_date, done, source_id from schedule_blocks",
            ) { statement -> SidebarSelfDataScheduleBlock? in
                guard let from = dateColumn(statement, 2),
                      let to = dateColumn(statement, 3),
                      to > from
                else {
                    return nil
                }

                let id = sqlite3_column_int64(statement, 0)
                let sessionName = textColumn(statement, 1) ?? "Session"
                let localDate = textColumn(statement, 4)
                let sourceIdentity = textColumn(statement, 6)
                    .map { URL(filePath: $0).deletingPathExtension().lastPathComponent }
                let identity = sourceIdentity ?? "\(localDate ?? "schedule") \(sessionName)"
                let parsedIdentity = parseScheduleIdentity(identity)
                let fileDate = parsedIdentity?.fileDate
                    ?? localDate.flatMap { makeLocalDateFormatter().date(from: $0) }
                    ?? Calendar.current.startOfDay(for: from)
                let sessionNumber = parsedIdentity?.sessionNumber ?? Int(id)
                let done = sqlite3_column_type(statement, 5) != SQLITE_NULL && sqlite3_column_int(statement, 5) != 0

                return SidebarSelfDataScheduleBlock(
                    identity: identity,
                    fileDate: fileDate,
                    sessionNumber: sessionNumber,
                    sessionName: sessionName,
                    from: from,
                    to: to,
                    done: done,
                )
            }
        }
    }

    static func loadSpendingTransactions(from sqliteURL: URL) -> [SidebarSelfDataSpendingTransaction]? {
        withDatabase(sqliteURL) { database in
            query(database, sql: "select created_at_utc, amount_minor from spending_transactions") { statement in
                guard let created = dateColumn(statement, 0) else { return nil }
                let amountMinor = sqlite3_column_double(statement, 1)
                guard amountMinor < 0 else { return nil }
                return SidebarSelfDataSpendingTransaction(
                    created: created,
                    amount: -amountMinor / 100,
                )
            }
        }
    }

    private static func withDatabase<T>(_ url: URL, _ body: (OpaquePointer) -> T?) -> T? {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database
        else {
            if let database {
                sqlite3_close(database)
            }
            return nil
        }
        defer { sqlite3_close(database) }
        return body(database)
    }

    private static func query<T>(
        _ database: OpaquePointer,
        sql: String,
        row: (OpaquePointer) -> T?,
    ) -> [T]? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = row(statement) {
                rows.append(value)
            }
        }
        return rows
    }

    private static func textColumn(_ statement: OpaquePointer, _ column: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: text)
    }

    private static func dateColumn(_ statement: OpaquePointer, _ column: Int32) -> Date? {
        textColumn(statement, column).flatMap { makeUTCDateFormatter().date(from: $0) }
    }

    private static func parseScheduleIdentity(_ identity: String) -> (fileDate: Date, sessionNumber: Int)? {
        let pattern = #"^(\d{4}-\d{2}-\d{2}) Session ([0-9]+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(identity.startIndex ..< identity.endIndex, in: identity)
        guard let match = regex.firstMatch(in: identity, range: nsRange),
              let dateRange = Range(match.range(at: 1), in: identity),
              let sessionRange = Range(match.range(at: 2), in: identity),
              let fileDate = makeLocalDateFormatter().date(from: String(identity[dateRange])),
              let sessionNumber = Int(identity[sessionRange])
        else {
            return nil
        }
        return (fileDate, sessionNumber)
    }

    private static func makeUTCDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private static func makeLocalDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
