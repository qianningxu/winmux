@testable import AppBundle
import Foundation
import XCTest

final class MenuBarAcademicPeriodTest: XCTestCase {
    func testSemesterWeeksAndLondonMondayBoundaries() {
        let cases: [(String, String)] = [
            ("2026-09-10T12:00:00Z", "Y4S1 - 0/12"),
            ("2026-09-13T22:59:59Z", "Y4S1 - 0/12"),
            ("2026-09-13T23:00:00Z", "Y4S1 - 1/12"),
            ("2026-10-18T23:00:00Z", "Y4S1 - 6/12 - Reading Week"),
            ("2026-10-25T23:59:59Z", "Y4S1 - 6/12 - Reading Week"),
            ("2026-10-26T00:00:00Z", "Y4S1 - 7/12"),
            ("2026-11-23T00:00:00Z", "Y4S1 - 11/12 - Revision Week"),
            ("2026-11-30T00:00:00Z", "Y4S1 - 12/12"),
            ("2026-12-21T00:00:00Z", "Y4S1 - 12/12"),
            ("2026-09-01T00:00:00Z", "Y4S1 - 0/12")
        ]
        for (date, expected) in cases {
            let period = MenuBarAcademicPeriod(now: ISO8601DateFormatter().date(from: date)!)
            XCTAssertEqual(period.title, expected, date)
        }
    }
}
