import AppKit

enum ResizePreviewPalette {
    static let fill = mattePanelNSColor.cgColor
    static let stroke = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.04, lightOpacity: 0.08)
    }.cgColor
    static let tabGroupBar = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.055, lightOpacity: 0.07)
    }.cgColor
    static let fallbackIconFill = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.12, lightOpacity: 0.10)
    }.cgColor
    static let sourceFrameFill = mattePanelNSColor.cgColor
    static let sourceFrameStroke = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.055, lightOpacity: 0.09)
    }.cgColor
    static let sourceMockTabFill = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.085, lightOpacity: 0.08)
    }.cgColor
    static let sourceMockTabStroke = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.075, lightOpacity: 0.10)
    }.cgColor
    static let fallbackText = WinMuxOverlayPalette.adaptiveNSColor {
        $0.foregroundNSColor(opacity: 0.82)
    }.cgColor
}
