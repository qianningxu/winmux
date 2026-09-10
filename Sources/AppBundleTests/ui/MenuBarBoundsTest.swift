import AppKit
@testable import AppBundle
import XCTest

final class MenuBarBoundsTest: XCTestCase {
    func testWidgetRowOccupiesMenuStripAndTabsSitImmediatelyBelow() {
        for height: CGFloat in [24, 32] {
            let screen = NSRect(x: -1920, y: 120, width: 1920, height: 1080)
            let left = workspaceSidebarTopBarPanelFrame(
                screenFrame: screen,
                visibleFrame: NSRect(x: -1920, y: 120, width: 1920, height: 1080 - height),
                auxiliaryTopLeftArea: nil,
                barHeight: height
            )
            let right = menuBarStatusWidgetRegionFrame(
                screenFrame: screen,
                auxiliaryTopRightArea: nil,
                barHeight: height
            )
            XCTAssertEqual(left.minY, screen.maxY - height * 2)
            XCTAssertEqual(left.height, height)
            XCTAssertEqual(left.maxY, right.minY)
            XCTAssertEqual(right.maxY, screen.maxY)
            XCTAssertEqual(left.maxX, right.maxX)
            XCTAssertEqual(left.width, screen.width)
        }
    }

    func testBarLayerIsBelowSystemMenuBar() {
        XCTAssertEqual(WinMuxPanelLayer.menuBarSurface.level.rawValue, Int(CGWindowLevelForKey(.dockWindow)))
        XCTAssertLessThan(WinMuxPanelLayer.menuBarSurface.level.rawValue, 21)
        XCTAssertLessThan(WinMuxPanelLayer.menuBarSurface.level.rawValue, NSWindow.Level.mainMenu.rawValue)
        XCTAssertGreaterThan(WinMuxPanelLayer.menuBarSurface.level.rawValue, WinMuxPanelLayer.workspaceBackground.level.rawValue)
        XCTAssertEqual(menuBarFloatingSurfaceOutset, 0)
    }
}
