@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class NativeLiveResizeGeometryTest: XCTestCase {
    func testNativeEdgeResizeCannotBecomeAMove() {
        XCTAssertTrue(shouldIgnoreMovedObsForManagedWindowDragSession(
            observedWindowId: 1, currentWindowId: 1, kind: .resize,
            subject: .window, detachOrigin: .window, startedInSidebar: false))
        XCTAssertFalse(shouldIgnoreMovedObsForManagedWindowDragSession(
            observedWindowId: 2, currentWindowId: 1, kind: .resize,
            subject: .window, detachOrigin: .window, startedInSidebar: false))
        XCTAssertFalse(shouldIgnoreMovedObsForManagedWindowDragSession(
            observedWindowId: 1, currentWindowId: 1, kind: .move,
            subject: .window, detachOrigin: .window, startedInSidebar: false))
    }

    func testTranslationAndResizeAreDistinguished() {
        let before = Rect(topLeftX: 100, topLeftY: 100, width: 500, height: 400)
        XCTAssertFalse(nativeWindowSizeChangedForResize(from: before,
            to: Rect(topLeftX: 110, topLeftY: 90, width: 500, height: 400)))
        for delta: CGFloat in [-30, 30] {
            XCTAssertTrue(nativeWindowSizeChangedForResize(from: before,
                to: Rect(topLeftX: 100 - delta, topLeftY: 100, width: 500 + delta, height: 400)))
            XCTAssertTrue(nativeWindowSizeChangedForResize(from: before,
                to: Rect(topLeftX: 100, topLeftY: 100 - delta, width: 500, height: 400 + delta)))
        }
    }

    func testLiveStackContentUsesTheSameGeometryAsNormalLayout() {
        for width: CGFloat in [200, 500, 1200] {
            for height: CGFloat in [150, 400, 900] {
                let content = Rect(topLeftX: 100, topLeftY: 100, width: width, height: height)
                let outer = windowTabGroupFrameRect(forActiveWindowContentRect: content)
                let live = liveResizeWindowContentRect(groupRect: outer, isTabGroup: true)
                XCTAssertEqual(live.topLeftX, content.topLeftX)
                XCTAssertEqual(live.topLeftY, content.topLeftY)
                XCTAssertEqual(live.width, content.width)
                XCTAssertEqual(live.height, content.height)
            }
        }
    }
}
