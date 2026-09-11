import AppKit
@testable import AppBundle
import XCTest

final class MenuBarProjectLeadingWidgetLayoutTest: XCTestCase {
    func testPeriodAndProjectsStayTogetherOnLeadingSide() {
        XCTAssertEqual(
            menuBarProjectLeadingWidgetPlacements([80, 60, 40], availableWidth: 300, separation: 12),
            [
                MenuBarWidgetPlacement(x: 0, width: 80),
                MenuBarWidgetPlacement(x: 92, width: 60),
                MenuBarWidgetPlacement(x: 260, width: 40),
            ]
        )
    }
}
