@testable import AppBundle
import XCTest

final class MenuBarLabelTest: XCTestCase {
    func testEmptyTrayStateUsesAppIndicator() {
        XCTAssertTrue(menuBarLabelShouldUseAppIndicator(trayText: "", trayItems: []))
    }

    func testNonEmptyTrayTextKeepsTextLabel() {
        XCTAssertFalse(menuBarLabelShouldUseAppIndicator(trayText: "A", trayItems: []))
    }

    func testTrayItemsKeepConfiguredItemStyle() {
        XCTAssertFalse(menuBarLabelShouldUseAppIndicator(
            trayText: "",
            trayItems: [
                TrayItem(type: .mode, name: "A", isActive: true, hasFullscreenWindows: false),
            ]
        ))
    }
}
