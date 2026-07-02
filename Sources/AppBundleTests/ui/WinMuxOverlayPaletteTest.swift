@testable import AppBundle
import AppKit
import SwiftUI
import XCTest

final class WinMuxOverlayPaletteTest: XCTestCase {
    func testPaletteUsesGeistLikeLightAndDarkSemantics() {
        let light = WinMuxOverlayPalette(theme: .light)
        let dark = WinMuxOverlayPalette(theme: .dark)

        XCTAssertLessThan(relativeLuminance(light.foregroundBaseNSColor), relativeLuminance(light.cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.foregroundBaseNSColor), relativeLuminance(dark.cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(light.borderBaseNSColor), relativeLuminance(light.foregroundBaseNSColor))
        XCTAssertLessThan(relativeLuminance(dark.borderBaseNSColor), relativeLuminance(dark.foregroundBaseNSColor))
    }

    func testPaletteCanBeBuiltFromSwiftUIColorScheme() {
        XCTAssertEqual(WinMuxOverlayPalette(colorScheme: .light).theme, .light)
        XCTAssertEqual(WinMuxOverlayPalette(colorScheme: .dark).theme, .dark)
    }

    func testPaletteUsesImportedGeistTokenValues() {
        let light = WinMuxOverlayPalette(theme: .light)
        let dark = WinMuxOverlayPalette(theme: .dark)

        assertGray(light.backgroundBaseNSColor, 0.98)
        assertGray(light.cardBaseNSColor, 1.00)
        assertGray(light.gray100BaseNSColor, 0.95)
        assertGray(light.gray300BaseNSColor, 0.90)
        assertGray(light.gray500BaseNSColor, 0.79)
        assertGray(light.gray700BaseNSColor, 0.56)
        assertGray(light.mutedBaseNSColor, 0.95)
        assertGray(light.borderBaseNSColor, 0.92)
        assertGray(light.foregroundBaseNSColor, 0.09)
        assertGray(light.mutedForegroundBaseNSColor, 0.30)

        assertHex(dark.backgroundBaseNSColor, 0x000000)
        assertHex(dark.cardBaseNSColor, 0x0A0A0A)
        assertHex(dark.gray100BaseNSColor, 0x1A1A1A)
        assertHex(dark.gray300BaseNSColor, 0x292929)
        assertHex(dark.gray500BaseNSColor, 0x454545)
        assertHex(dark.gray700BaseNSColor, 0x8F8F8F)
        assertHex(dark.mutedBaseNSColor, 0x1A1A1A)
        assertHex(dark.borderBaseNSColor, 0x333333)
        assertHex(dark.foregroundBaseNSColor, 0xEDEDED)
        assertHex(dark.mutedForegroundBaseNSColor, 0xDEDEDE)
    }

    func testCanvasBackgroundUsesInvertedContrastFromGeistTokens() {
        let light = WinMuxOverlayPalette(theme: .light)
        let dark = WinMuxOverlayPalette(theme: .dark)

        assertGray(light.gray100BaseNSColor, 0.95)
        assertHex(dark.gray100BaseNSColor, 0x1A1A1A)
        XCTAssertLessThan(relativeLuminance(light.canvasBackgroundNSColor), relativeLuminance(light.cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.canvasBackgroundNSColor), relativeLuminance(dark.cardBaseNSColor))
        XCTAssertLessThan(relativeLuminance(light.gray100BaseNSColor), relativeLuminance(light.cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.gray100BaseNSColor), relativeLuminance(dark.cardBaseNSColor))
    }

    func testSidebarTabChromeUsesDistinctHoverAndDarkerStrokes() {
        let light = WinMuxOverlayPalette(theme: .light)
        let dark = WinMuxOverlayPalette(theme: .dark)

        assertGray(light.tabHoverSurfaceNSColor, 0.92)
        assertHex(dark.tabHoverSurfaceNSColor, 0x292929)
        XCTAssertLessThan(relativeLuminance(light.tabHoverSurfaceNSColor), relativeLuminance(light.gray100BaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.tabHoverSurfaceNSColor), relativeLuminance(dark.gray100BaseNSColor))
        XCTAssertLessThan(relativeLuminance(light.tabStrokeNSColor()), relativeLuminance(light.borderBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.tabStrokeNSColor()), relativeLuminance(dark.borderBaseNSColor))
        XCTAssertLessThan(relativeLuminance(light.iconStrokeNSColor()), relativeLuminance(light.borderBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.iconStrokeNSColor()), relativeLuminance(dark.borderBaseNSColor))
    }

    func testPaletteUsesGeistSemanticAccentTokens() {
        let light = WinMuxOverlayPalette(theme: .light)
        let dark = WinMuxOverlayPalette(theme: .dark)

        assertRGB(light.attentionNSColor, red: 0, green: 0.448, blue: 0.960)
        assertRGB(dark.attentionNSColor, red: 0, green: 0.406, blue: 0.840)
        assertRGB(light.destructiveNSColor, red: 0.898, green: 0.2825, blue: 0.303)
        assertRGB(dark.destructiveNSColor, red: 0.797, green: 0.163, blue: 0.184)
        assertRGB(light.otherDisplayNSColor, red: 0.916, green: 0.244, blue: 0.513)
        assertRGB(dark.otherDisplayNSColor, red: 0.743, green: 0.158, blue: 0.392)
    }

    func testDropIntentLandingPreviewUsesGreyPlacementPaneNotCardWhite() {
        let light = WinMuxOverlayPalette(theme: .light)
        let dark = WinMuxOverlayPalette(theme: .dark)

        assertGray(light.dropIntentBackdropNSColor, 0.95)
        assertGray(light.dropIntentInactivePaneNSColor, 0.90)
        assertGray(light.dropIntentLandingPaneNSColor, 0.79)
        assertGray(light.dropIntentSplitPlacementPaneNSColor, 0.79)
        assertGray(light.dropIntentSplitExistingPaneNSColor, 0.90)
        assertGray(light.dropIntentDisplacedPaneNSColor, 0.90)
        assertHex(dark.dropIntentBackdropNSColor, 0x1A1A1A)
        assertHex(dark.dropIntentInactivePaneNSColor, 0x292929)
        assertHex(dark.dropIntentLandingPaneNSColor, 0x454545)
        assertHex(dark.dropIntentSplitPlacementPaneNSColor, 0x454545)
        assertHex(dark.dropIntentSplitExistingPaneNSColor, 0x292929)
        assertHex(dark.dropIntentDisplacedPaneNSColor, 0x292929)
        XCTAssertLessThan(relativeLuminance(light.dropIntentBackdropNSColor), relativeLuminance(light.cardBaseNSColor))
        XCTAssertLessThan(relativeLuminance(light.dropIntentInactivePaneNSColor), relativeLuminance(light.cardBaseNSColor))
        XCTAssertEqual(relativeLuminance(light.dropIntentLandingPaneNSColor), relativeLuminance(light.gray500BaseNSColor))
        XCTAssertLessThan(relativeLuminance(light.dropIntentLandingPaneNSColor), relativeLuminance(light.dropIntentInactivePaneNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.dropIntentBackdropNSColor), relativeLuminance(dark.cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.dropIntentInactivePaneNSColor), relativeLuminance(dark.dropIntentBackdropNSColor))
        XCTAssertEqual(relativeLuminance(dark.dropIntentLandingPaneNSColor), relativeLuminance(dark.gray500BaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(dark.dropIntentLandingPaneNSColor), relativeLuminance(dark.dropIntentInactivePaneNSColor))
    }

    func testResizePreviewPlacementPaletteUsesGreyDropIntentFills() {
        let lightFill = resolvedColor(ResizePreviewPalette.fillNSColor, appearance: .aqua)
        let lightSourceFill = resolvedColor(ResizePreviewPalette.sourceFrameFillNSColor, appearance: .aqua)
        let darkFill = resolvedColor(ResizePreviewPalette.fillNSColor, appearance: .darkAqua)
        let darkSourceFill = resolvedColor(ResizePreviewPalette.sourceFrameFillNSColor, appearance: .darkAqua)

        assertGray(lightFill, 0.79)
        assertGray(lightSourceFill, 0.90)
        assertHex(darkFill, 0x454545)
        assertHex(darkSourceFill, 0x292929)
        XCTAssertLessThan(relativeLuminance(lightFill), relativeLuminance(WinMuxOverlayPalette(theme: .light).cardBaseNSColor))
        XCTAssertLessThan(relativeLuminance(lightSourceFill), relativeLuminance(WinMuxOverlayPalette(theme: .light).cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(darkFill), relativeLuminance(WinMuxOverlayPalette(theme: .dark).cardBaseNSColor))
        XCTAssertGreaterThan(relativeLuminance(darkSourceFill), relativeLuminance(WinMuxOverlayPalette(theme: .dark).cardBaseNSColor))
    }

    func testSidebarPanelFrameUsesVisibleFrameAndExtraReserve() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = NSRect(x: 0, y: 40, width: 1512, height: 914)

        let frame = workspaceSidebarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            width: 480,
            extraTopReserveHeight: 0,
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 40, width: 480, height: 914))
    }

    func testSidebarPanelFrameCanSpanVisibleFrameForCanvasHost() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = NSRect(x: 0, y: 40, width: 1512, height: 914)

        let frame = workspaceSidebarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            width: visibleFrame.width,
            extraTopReserveHeight: 0,
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 40, width: 1512, height: 914))
    }

    func testCanvasBackgroundFrameCanFillToPhysicalScreenTop() {
        let sidebarFrame = NSRect(x: 0, y: 40, width: 1512, height: 914)
        let screenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)

        let frame = workspaceCanvasBackgroundFrame(
            sidebarFrame: sidebarFrame,
            screenFrame: screenFrame
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 40, width: 1512, height: 942))
    }

    func testSidebarSideAreaVisualFrameIsInsetWithinHostFrame() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        let hostFrame = NSRect(x: 0, y: 40, width: 490, height: 914)

        let visualFrame = metrics.visualSidebarFrame(in: hostFrame, visibleWidth: 240)

        XCTAssertEqual(visualFrame, NSRect(x: 10, y: 50, width: 240, height: 894))
    }

    func testSidebarSideAreaBackgroundFrameUsesCurrentVisibleWidthWhenFolded() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        let hostFrame = NSRect(x: 0, y: 40, width: 510, height: 914)

        let backgroundFrame = metrics.sideAreaBackgroundFrame(
            in: hostFrame,
            visibleWidth: 44,
            expandedWidth: 250
        )

        XCTAssertEqual(backgroundFrame, NSRect(x: 0, y: 40, width: 64, height: 914))
    }

    func testSidebarSideAreaBackgroundFrameFillsExpandedSideArea() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        let hostFrame = NSRect(x: 0, y: 40, width: 510, height: 914)

        let backgroundFrame = metrics.sideAreaBackgroundFrame(
            in: hostFrame,
            visibleWidth: 250,
            expandedWidth: 250
        )

        XCTAssertEqual(backgroundFrame, NSRect(x: 0, y: 40, width: 270, height: 914))
    }

    func testSidebarSideAreaEdgeTriggerStaysFlushToHostEdge() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard
        let hostFrame = NSRect(x: -1440, y: 145, width: 490, height: 875)

        let triggerFrame = metrics.edgeTriggerFrame(in: hostFrame)

        XCTAssertEqual(triggerFrame, NSRect(x: -1440, y: 145, width: 4, height: 875))
    }

    func testSidebarSideAreaReservationUsesExpandedWidthAndWindowGap() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard

        XCTAssertEqual(metrics.sideAreaReservation(expandedWidth: 240), 260)
    }

    func testWindowCanvasLeftInsetUsesSingleTenPointGapWhenFolded() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard

        XCTAssertEqual(metrics.windowCanvasLeftInset(visibleWidth: 44, userOuterLeftGap: 8), 64)
    }

    func testWindowCanvasLeftInsetUsesSingleTenPointGapWhenExpanded() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard

        XCTAssertEqual(metrics.windowCanvasLeftInset(visibleWidth: 250, userOuterLeftGap: 8), 270)
    }

    func testWindowCanvasLeftInsetPreservesLargerUserGap() {
        let metrics = WorkspaceSidebarSideAreaMetrics.standard

        XCTAssertEqual(metrics.windowCanvasLeftInset(visibleWidth: 44, userOuterLeftGap: 20), 74)
    }

    func testSidebarPanelFrameDoesNotDoubleCountMenuBarReserveAlreadyInVisibleFrame() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = NSRect(x: 0, y: 40, width: 1512, height: 914)

        let frame = workspaceSidebarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            width: 480,
            extraTopReserveHeight: 28,
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 40, width: 480, height: 914))
    }

    func testSidebarPanelFrameAppliesReserveBeyondVisibleFrameTopInset() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = NSRect(x: 0, y: 40, width: 1512, height: 914)

        let frame = workspaceSidebarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            width: 480,
            extraTopReserveHeight: 56,
        )

        XCTAssertEqual(frame, NSRect(x: 0, y: 40, width: 480, height: 886))
    }

    func testSidebarPanelFrameKeepsSecondaryMonitorCoordinates() {
        let screenFrame = NSRect(x: -1440, y: 120, width: 1440, height: 900)
        let visibleFrame = NSRect(x: -1432, y: 145, width: 1432, height: 875)

        let frame = workspaceSidebarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            width: 480,
            extraTopReserveHeight: 0,
        )

        XCTAssertEqual(frame, NSRect(x: -1432, y: 145, width: 480, height: 875))
    }

    func testSidebarPanelFrameClampsToAtLeastOnePointTall() {
        let screenFrame = NSRect(x: 0, y: 0, width: 100, height: 100)
        let visibleFrame = NSRect(x: 0, y: 20, width: 100, height: 40)

        let frame = workspaceSidebarPanelFrame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            width: 400,
            extraTopReserveHeight: 1000,
        )

        XCTAssertEqual(frame.width, 100)
        XCTAssertEqual(frame.height, 1)
    }
}

private func relativeLuminance(_ color: NSColor) -> CGFloat {
    let rgb = color.usingColorSpace(.sRGB).orDie()
    return (0.2126 * rgb.redComponent) + (0.7152 * rgb.greenComponent) + (0.0722 * rgb.blueComponent)
}

private func resolvedColor(_ color: NSColor, appearance: NSAppearance.Name) -> NSColor {
    let appearance = NSAppearance(named: appearance).orDie()
    var resolved: NSColor?
    appearance.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    return resolved.orDie()
}

private func assertGray(_ color: NSColor, _ expectedWhite: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
    let rgb = color.usingColorSpace(.sRGB).orDie()
    XCTAssertEqual(rgb.redComponent, expectedWhite, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rgb.greenComponent, expectedWhite, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rgb.blueComponent, expectedWhite, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rgb.alphaComponent, 1, accuracy: 0.001, file: file, line: line)
}

private func assertHex(_ color: NSColor, _ expectedRGB: UInt32, file: StaticString = #filePath, line: UInt = #line) {
    assertRGB(
        color,
        red: CGFloat((expectedRGB >> 16) & 0xFF) / 255,
        green: CGFloat((expectedRGB >> 8) & 0xFF) / 255,
        blue: CGFloat(expectedRGB & 0xFF) / 255,
        file: file,
        line: line
    )
}

private func assertRGB(
    _ color: NSColor,
    red: CGFloat,
    green: CGFloat,
    blue: CGFloat,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let rgb = color.usingColorSpace(.sRGB).orDie()
    XCTAssertEqual(rgb.redComponent, red, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rgb.greenComponent, green, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rgb.blueComponent, blue, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(rgb.alphaComponent, 1, accuracy: 0.001, file: file, line: line)
}
