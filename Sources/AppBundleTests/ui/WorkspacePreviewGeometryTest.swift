@testable import AppBundle
import AppKit
import XCTest

final class WorkspacePreviewGeometryTest: XCTestCase {
    @MainActor
    func testTabGroupBuildsSingleVisiblePreviewPane() {
        setUpWorkspacesForTests()
        config.windowTabs.enabled = true
        let workspace = Workspace.get(byName: "preview-tabs")
        let workspaceRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let root = workspace.rootTilingContainer
        let tabGroup = TilingContainer(parent: root, adaptiveWeight: WEIGHT_AUTO, .v, .tabGroup, index: INDEX_BIND_LAST)
        let active = TestWindow.new(id: 1, parent: tabGroup)
        let hidden = TestWindow.new(id: 2, parent: tabGroup)
        tabGroup.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 500, height: 400)
        active.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 34, width: 500, height: 366)
        hidden.lastAppliedLayoutPhysicalRect = nil
        active.markAsMostRecentChild()

        let items = workspacePreviewWindowItems(for: workspace, workspaceRect: workspaceRect)

        XCTAssertEqual(items.map(\.id), [1])
        assertFrame(items[0].layoutFrame, equals: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
    }

    @MainActor
    func testTiledWindowWithoutCachedRectUsesTreeFallbackFrame() {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "preview-fallback")
        let workspaceRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let root = workspace.rootTilingContainer
        let window = TestWindow.new(id: 1, parent: root)
        window.lastAppliedLayoutPhysicalRect = nil
        window.lastAppliedLayoutVirtualRect = nil
        window.lastKnownActualRect = nil

        let items = workspacePreviewWindowItems(for: workspace, workspaceRect: workspaceRect)

        XCTAssertEqual(items.map(\.id), [1])
        assertFrame(items[0].layoutFrame, equals: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @MainActor
    func testTiledHiddenWorkspaceWindowsPreferTreeFallbackOverParkedActualRect() {
        setUpWorkspacesForTests()
        config.gaps = .zero
        let workspace = Workspace.get(byName: "preview-parked")
        let workspaceRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 800)
        let root = workspace.rootTilingContainer
        let first = TestWindow.new(id: 1, parent: root, adaptiveWeight: 0.5)
        let second = TestWindow.new(id: 2, parent: root, adaptiveWeight: 0.5)
        first.lastKnownActualRect = Rect(topLeftX: 1600, topLeftY: 900, width: 500, height: 400)
        second.lastKnownActualRect = Rect(topLeftX: 1600, topLeftY: 900, width: 500, height: 400)

        let items = workspacePreviewWindowItems(for: workspace, workspaceRect: workspaceRect)

        XCTAssertEqual(items.map(\.id), [1, 2])
        assertFrame(items[0].layoutFrame, equals: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        assertFrame(items[1].layoutFrame, equals: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testPlacedWindowsUseExactWorkspaceCanvasWithoutRecenteringVisibleUnion() {
        let item = previewTestItem(id: 1, layoutFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))

        let placed = workspacePreviewPlacedWindows(
            windows: [item],
            workspaceAspectRatio: 1,
            in: CGSize(width: 120, height: 120),
            inset: 10,
        )

        XCTAssertEqual(placed.map(\.id), [1])
        assertFrame(placed[0].frame, equals: CGRect(x: 60, y: 10, width: 50, height: 100))
    }

    @MainActor
    func testFloatingWindowUsesActualRectAndRendersAfterTiledPanes() {
        setUpWorkspacesForTests()
        let workspace = Workspace.get(byName: "preview-floating")
        let workspaceRect = Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 500)
        let root = workspace.rootTilingContainer
        let tiled = TestWindow.new(id: 1, parent: root)
        tiled.lastAppliedLayoutPhysicalRect = Rect(topLeftX: 0, topLeftY: 0, width: 500, height: 500)
        _ = TestWindow.new(
            id: 2,
            parent: workspace,
            rect: Rect(topLeftX: 400, topLeftY: 200, width: 200, height: 100),
        )

        let items = workspacePreviewWindowItems(for: workspace, workspaceRect: workspaceRect)

        XCTAssertEqual(items.map(\.id), [1, 2])
        assertFrame(items[1].layoutFrame, equals: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
    }

    func testNormalizedFrameClipsToWorkspaceCanvas() {
        let workspaceRect = Rect(topLeftX: 100, topLeftY: 200, width: 400, height: 300)
        let overflowingRect = Rect(topLeftX: 0, topLeftY: 260, width: 300, height: 300)

        let frame = workspacePreviewNormalizedFrame(for: overflowingRect, in: workspaceRect)

        assertFrame(frame, equals: CGRect(x: 0, y: 0.2, width: 0.5, height: 0.8))
    }

    func testSolidGreyThumbnailIsRejectedAsBlank() {
        let image = previewTestImage(width: 24, height: 24) { _, _ in
            NSColor(deviceRed: 0.42, green: 0.42, blue: 0.42, alpha: 1)
        }

        XCTAssertTrue(isLikelyBlankWindowThumbnail(image, sampleGrid: 8))
    }

    func testContrastyThumbnailIsKept() {
        let image = previewTestImage(width: 24, height: 24) { x, y in
            x < 12 || y < 6
                ? NSColor(deviceRed: 0.12, green: 0.12, blue: 0.12, alpha: 1)
                : NSColor(deviceRed: 0.86, green: 0.86, blue: 0.86, alpha: 1)
        }

        XCTAssertFalse(isLikelyBlankWindowThumbnail(image, sampleGrid: 8))
    }
}

private func previewTestItem(id: UInt32, layoutFrame: CGRect) -> WorkspacePreviewWindowItem {
    WorkspacePreviewWindowItem(
        id: id,
        title: "Window \(id)",
        appName: "Test",
        appIcon: nil,
        thumbnail: nil,
        layoutFrame: layoutFrame,
    )
}

private func assertFrame(
    _ actual: CGRect?,
    equals expected: CGRect,
    accuracy: CGFloat = 0.001,
    file: StaticString = #filePath,
    line: UInt = #line,
) {
    guard let actual else {
        XCTFail("Expected \(expected), got nil", file: file, line: line)
        return
    }
    assertFrame(actual, equals: expected, accuracy: accuracy, file: file, line: line)
}

private func assertFrame(
    _ actual: CGRect,
    equals expected: CGRect,
    accuracy: CGFloat = 0.001,
    file: StaticString = #filePath,
    line: UInt = #line,
) {
    XCTAssertEqual(actual.minX, expected.minX, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.minY, expected.minY, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
}

private func previewTestImage(
    width: Int,
    height: Int,
    color: (Int, Int) -> NSColor,
) -> CGImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0,
    ).orDie()

    for y in 0 ..< height {
        for x in 0 ..< width {
            rep.setColor(color(x, y), atX: x, y: y)
        }
    }

    return rep.cgImage.orDie()
}
