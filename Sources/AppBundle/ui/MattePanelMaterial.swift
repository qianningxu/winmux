import AppKit
import SwiftUI

let mattePanelNSColor = WinMuxOverlayPalette.adaptiveNSColor(\.mattePanelNSColor)
let mattePanelFill = WinMuxOverlayPalette.adaptiveColor(\.mattePanelNSColor)
let mattePanelBorder = mattePanelFill
let mattePanelInsetShadow = WinMuxOverlayPalette.adaptiveColor {
    $0.backgroundNSColor(opacity: $0.isDark ? 0.28 : 0.12)
}
let mattePanelSeparatorNSColor = WinMuxOverlayPalette.adaptiveNSColor(\.mattePanelSeparatorNSColor)
let mattePanelSeparator = WinMuxOverlayPalette.adaptiveColor(\.mattePanelSeparatorNSColor)
