@testable import AppBundle
import CoreGraphics
import XCTest

@MainActor
final class FloatingWindowLevelControllerTest: XCTestCase {
    func testPromotesFloatingWindowsAndRestoresTheirOriginalLevels() {
        var levels: [UInt32: CGWindowLevel] = [11: 0, 12: 3]
        var writes: [(UInt32, CGWindowLevel)] = []
        let controller = FloatingWindowLevelController(
            loadLevels: { levels },
            setLevel: { windowId, level in
                writes.append((windowId, level))
                levels[windowId] = level
                return true
            }
        )

        controller.sync(floatingWindowIds: [11, 12])
        XCTAssertEqual(writes.map(\.0), [11])
        XCTAssertEqual(writes.map(\.1), [3])

        controller.sync(floatingWindowIds: [12])
        XCTAssertEqual(writes.map(\.0), [11, 11])
        XCTAssertEqual(writes.map(\.1), [3, 0])

        controller.restoreAll()
        XCTAssertEqual(writes.count, 2)
    }

    func testRetriesPromotionWhenWindowLevelIsNotYetAvailable() {
        var levels: [UInt32: CGWindowLevel] = [:]
        var writes: [(UInt32, CGWindowLevel)] = []
        let controller = FloatingWindowLevelController(
            loadLevels: { levels },
            setLevel: { windowId, level in
                writes.append((windowId, level))
                return true
            }
        )

        controller.sync(floatingWindowIds: [21])
        XCTAssertTrue(writes.isEmpty)

        levels[21] = 0
        controller.sync(floatingWindowIds: [21])
        XCTAssertEqual(writes.map(\.0), [21])
        XCTAssertEqual(writes.map(\.1), [3])
    }
}
