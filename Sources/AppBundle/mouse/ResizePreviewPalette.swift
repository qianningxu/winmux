import AppKit

enum ResizePreviewPalette {
    static let fillNSColor = WinMuxOverlayPalette.adaptiveNSColor(\.dropIntentSplitPlacementPaneNSColor)
    static var fill: CGColor { fillNSColor.cgColor }

    static let strokeNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.04, lightOpacity: 0.08)
    }
    static var stroke: CGColor { strokeNSColor.cgColor }

    static let tabGroupBarNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.055, lightOpacity: 0.07)
    }
    static var tabGroupBar: CGColor { tabGroupBarNSColor.cgColor }

    static let fallbackIconFillNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.12, lightOpacity: 0.10)
    }
    static var fallbackIconFill: CGColor { fallbackIconFillNSColor.cgColor }

    static let sourceFrameFillNSColor = WinMuxOverlayPalette.adaptiveNSColor(\.dropIntentInactivePaneNSColor)
    static var sourceFrameFill: CGColor { sourceFrameFillNSColor.cgColor }

    static let sourceFrameStrokeNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.055, lightOpacity: 0.09)
    }
    static var sourceFrameStroke: CGColor { sourceFrameStrokeNSColor.cgColor }

    static let sourceMockTabFillNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.085, lightOpacity: 0.08)
    }
    static var sourceMockTabFill: CGColor { sourceMockTabFillNSColor.cgColor }

    static let sourceMockTabStrokeNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.contrastingNSColor(darkOpacity: 0.075, lightOpacity: 0.10)
    }
    static var sourceMockTabStroke: CGColor { sourceMockTabStrokeNSColor.cgColor }

    static let fallbackTextNSColor = WinMuxOverlayPalette.adaptiveNSColor {
        $0.foregroundNSColor(opacity: 0.82)
    }
    static var fallbackText: CGColor { fallbackTextNSColor.cgColor }
}
