@testable import AppBundle
import XCTest

final class WindowDropIntentResolverTest: XCTestCase {
    @MainActor
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testResolvesTopBandAsTabZone() {
        let resolution = resolve(point: CGPoint(x: 150, y: 115))
        XCTAssertEqual(resolution?.intent.zone, .tab)
        XCTAssertEqual(resolution?.intent.sourceWindowId, 1)
        XCTAssertEqual(resolution?.intent.targetWindowId, 2)
    }

    func testResolvesBodyZones() {
        XCTAssertEqual(resolve(point: CGPoint(x: 110, y: 210))?.intent.zone, .left)
        XCTAssertEqual(resolve(point: CGPoint(x: 290, y: 210))?.intent.zone, .right)
        XCTAssertEqual(resolve(point: CGPoint(x: 200, y: 160))?.intent.zone, .top)
        XCTAssertEqual(resolve(point: CGPoint(x: 200, y: 210))?.intent.zone, .middle)
        XCTAssertEqual(resolve(point: CGPoint(x: 200, y: 285))?.intent.zone, .bottom)
    }

    func testPreviewZonesUseFullTargetFrameAndActiveZone() {
        let resolution = resolve(point: CGPoint(x: 200, y: 210)).orDie()
        let zones = windowDropIntentPreviewZones(for: resolution)

        XCTAssertEqual(zones.count, 6)
        XCTAssertEqual(zones.filter(\.isActive).count, 1)
        assertRect(zones.first { $0.isActive }?.rect, x: 170, y: 195.2, width: 70, height: 57.4)
        assertRect(windowDropIntentActivePreviewRect(for: resolution), x: 170, y: 195.2, width: 70, height: 57.4)
        assertRect(zones.first?.rect, x: 100, y: 100, width: 210, height: 37.8)
    }

    func testRejectsSourceAsTargetAndOutsidePointer() {
        let frame = Rect(topLeftX: 100, topLeftY: 100, width: 210, height: 210)
        XCTAssertNil(WindowDropIntentResolver().resolve(
            sourceWindowId: 1,
            targetWindowId: 1,
            pointer: CGPoint(x: 150, y: 150),
            targetFrame: frame,
        ))
        XCTAssertNil(WindowDropIntentResolver().resolve(
            sourceWindowId: 1,
            targetWindowId: 2,
            pointer: CGPoint(x: 99, y: 150),
            targetFrame: frame,
        ))
    }

    @MainActor
    func testTopTabAndCenterBodyDropsProduceNoDestination() {
        let workspace = Workspace.get(byName: "drag")
        let root = workspace.rootTilingContainer
        let source = TestWindow.new(id: 1, parent: root)
        let target = TestWindow.new(id: 2, parent: root)
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 100, topLeftY: 100, width: 210, height: 210)

        let topResolution = resolve(point: CGPoint(x: 150, y: 115)).orDie()
        let centerResolution = resolve(point: CGPoint(x: 200, y: 210)).orDie()

        XCTAssertNil(destinationFromWindowDropIntent(
            topResolution,
            sourceWindow: source,
            targetWindow: target,
            mouseLocation: CGPoint(x: 150, y: 115),
            subject: .window,
            detachOrigin: .window,
        ))
        XCTAssertNil(destinationFromWindowDropIntent(
            centerResolution,
            sourceWindow: source,
            targetWindow: target,
            mouseLocation: CGPoint(x: 200, y: 210),
            subject: .window,
            detachOrigin: .window,
        ))
    }

    @MainActor
    func testEdgeDropsStillProduceSplitDestinations() {
        let workspace = Workspace.get(byName: "drag")
        let root = workspace.rootTilingContainer
        let source = TestWindow.new(id: 1, parent: root)
        let target = TestWindow.new(id: 2, parent: root)
        target.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 100, topLeftY: 100, width: 210, height: 210)
        let resolution = resolve(point: CGPoint(x: 110, y: 210)).orDie()

        let destination = destinationFromWindowDropIntent(
            resolution,
            sourceWindow: source,
            targetWindow: target,
            mouseLocation: CGPoint(x: 110, y: 210),
            subject: .window,
            detachOrigin: .window,
        )

        XCTAssertEqual(destination?.kind, .stackSplit(targetWindowId: target.windowId, position: .left))
    }

    private func resolve(point: CGPoint) -> WindowDropIntentResolution? {
        WindowDropIntentResolver().resolve(
            sourceWindowId: 1,
            targetWindowId: 2,
            pointer: point,
            targetFrame: Rect(topLeftX: 100, topLeftY: 100, width: 210, height: 210),
        )
    }

    private func assertRect(
        _ rect: Rect?,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let rect else {
            XCTFail("Expected rect", file: file, line: line)
            return
        }
        XCTAssertEqual(rect.topLeftX, x, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(rect.topLeftY, y, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(rect.width, width, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(rect.height, height, accuracy: 0.0001, file: file, line: line)
    }
}
