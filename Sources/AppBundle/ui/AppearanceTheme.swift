import AppKit
import Common
import SwiftUI

enum AppearanceTheme {
    case light
    case dark

    /// System Settings -> Appearance -> Light/Dark
    /// This is the theme representing how the UI should look inside the app (this might be different than the menu bar color)
    @MainActor
    static var current: AppearanceTheme {
        from(NSApplication.shared.effectiveAppearance)
    }

    init(colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }

    static func from(_ appearance: NSAppearance) -> AppearanceTheme {
        let name = appearance.bestMatch(from: [
            .aqua,
            .darkAqua,
            .vibrantLight,
            .vibrantDark,
            .accessibilityHighContrastAqua,
            .accessibilityHighContrastDarkAqua,
            .accessibilityHighContrastVibrantLight,
            .accessibilityHighContrastVibrantDark,
        ]) ?? appearance.name
        let isDarkAppearance = name == .vibrantDark ||
            name == .darkAqua ||
            name == .accessibilityHighContrastDarkAqua ||
            name == .accessibilityHighContrastVibrantDark
        return isDarkAppearance ? .dark : .light
    }
}

struct WinMuxOverlayPalette {
    let theme: AppearanceTheme

    init(theme: AppearanceTheme) {
        self.theme = theme
    }

    init(colorScheme: ColorScheme) {
        self.theme = AppearanceTheme(colorScheme: colorScheme)
    }

    @MainActor
    static var current: WinMuxOverlayPalette {
        WinMuxOverlayPalette(theme: .current)
    }

    var colorScheme: ColorScheme {
        theme == .dark ? .dark : .light
    }

    var isDark: Bool {
        theme == .dark
    }

    var foregroundBaseNSColor: NSColor {
        colorToken(.foreground)
    }

    var backgroundBaseNSColor: NSColor {
        colorToken(.background)
    }

    var cardBaseNSColor: NSColor {
        colorToken(.card)
    }

    var mutedBaseNSColor: NSColor {
        colorToken(.muted)
    }

    var gray100BaseNSColor: NSColor {
        colorToken(.gray100)
    }

    var gray200BaseNSColor: NSColor {
        colorToken(.gray200)
    }

    var gray300BaseNSColor: NSColor {
        colorToken(.gray300)
    }

    var gray500BaseNSColor: NSColor {
        colorToken(.gray500)
    }

    var gray700BaseNSColor: NSColor {
        colorToken(.gray700)
    }

    var borderBaseNSColor: NSColor {
        colorToken(.border)
    }

    var mutedForegroundBaseNSColor: NSColor {
        colorToken(.mutedForeground)
    }

    func foregroundNSColor(opacity: CGFloat = 1) -> NSColor {
        foregroundBaseNSColor.withAlphaComponent(opacity)
    }

    func foreground(_ opacity: Double = 1) -> Color {
        Color(nsColor: foregroundNSColor(opacity: CGFloat(opacity)))
    }

    func mutedForegroundNSColor(opacity: CGFloat = 1) -> NSColor {
        mutedForegroundBaseNSColor.withAlphaComponent(opacity)
    }

    func mutedForeground(_ opacity: Double = 1) -> Color {
        Color(nsColor: mutedForegroundNSColor(opacity: CGFloat(opacity)))
    }

    func backgroundNSColor(opacity: CGFloat) -> NSColor {
        backgroundBaseNSColor.withAlphaComponent(opacity)
    }

    func background(_ opacity: Double) -> Color {
        Color(nsColor: backgroundNSColor(opacity: CGFloat(opacity)))
    }

    func cardNSColor(opacity: CGFloat = 1) -> NSColor {
        cardBaseNSColor.withAlphaComponent(opacity)
    }

    func card(_ opacity: Double = 1) -> Color {
        Color(nsColor: cardNSColor(opacity: CGFloat(opacity)))
    }

    func mutedNSColor(opacity: CGFloat = 1) -> NSColor {
        mutedBaseNSColor.withAlphaComponent(opacity)
    }

    func muted(_ opacity: Double = 1) -> Color {
        Color(nsColor: mutedNSColor(opacity: CGFloat(opacity)))
    }

    func gray100NSColor(opacity: CGFloat = 1) -> NSColor {
        gray100BaseNSColor.withAlphaComponent(opacity)
    }

    func gray100(_ opacity: Double = 1) -> Color {
        Color(nsColor: gray100NSColor(opacity: CGFloat(opacity)))
    }

    func gray200NSColor(opacity: CGFloat = 1) -> NSColor {
        gray200BaseNSColor.withAlphaComponent(opacity)
    }

    func gray200(_ opacity: Double = 1) -> Color {
        Color(nsColor: gray200NSColor(opacity: CGFloat(opacity)))
    }

    func gray300NSColor(opacity: CGFloat = 1) -> NSColor {
        gray300BaseNSColor.withAlphaComponent(opacity)
    }

    func gray300(_ opacity: Double = 1) -> Color {
        Color(nsColor: gray300NSColor(opacity: CGFloat(opacity)))
    }

    func gray500NSColor(opacity: CGFloat = 1) -> NSColor {
        gray500BaseNSColor.withAlphaComponent(opacity)
    }

    func gray500(_ opacity: Double = 1) -> Color {
        Color(nsColor: gray500NSColor(opacity: CGFloat(opacity)))
    }

    func gray700NSColor(opacity: CGFloat = 1) -> NSColor {
        gray700BaseNSColor.withAlphaComponent(opacity)
    }

    func gray700(_ opacity: Double = 1) -> Color {
        Color(nsColor: gray700NSColor(opacity: CGFloat(opacity)))
    }

    func selectedSurfaceNSColor(opacity: CGFloat = 1) -> NSColor {
        cardBaseNSColor.withAlphaComponent(opacity)
    }

    func selectedSurface(_ opacity: Double = 1) -> Color {
        Color(nsColor: selectedSurfaceNSColor(opacity: CGFloat(opacity)))
    }

    func borderNSColor(opacity: CGFloat = 1) -> NSColor {
        borderBaseNSColor.withAlphaComponent(opacity)
    }

    func border(_ opacity: Double = 1) -> Color {
        Color(nsColor: borderNSColor(opacity: CGFloat(opacity)))
    }

    var tabHoverSurfaceNSColor: NSColor {
        isDark ? gray300BaseNSColor : gray200BaseNSColor
    }

    func tabHoverSurface(_ opacity: Double = 1) -> Color {
        Color(nsColor: tabHoverSurfaceNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    func tabStrokeNSColor(active: Bool = false) -> NSColor {
        gray500BaseNSColor.withAlphaComponent(active ? 0.90 : 0.66)
    }

    func tabStroke(active: Bool = false) -> Color {
        Color(nsColor: tabStrokeNSColor(active: active))
    }

    func iconStrokeNSColor(active: Bool = false) -> NSColor {
        gray500BaseNSColor.withAlphaComponent(active ? 0.82 : 0.58)
    }

    func iconStroke(active: Bool = false) -> Color {
        Color(nsColor: iconStrokeNSColor(active: active))
    }

    func contrastingNSColor(darkOpacity: CGFloat, lightOpacity: CGFloat? = nil) -> NSColor {
        let opacity = isDark ? darkOpacity : (lightOpacity ?? darkOpacity)
        return foregroundBaseNSColor.withAlphaComponent(opacity)
    }

    func contrastingFill(darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
        Color(nsColor: contrastingNSColor(
            darkOpacity: CGFloat(darkOpacity),
            lightOpacity: lightOpacity.map { CGFloat($0) },
        ))
    }

    func shadow(_ darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
        Color.black.opacity(isDark ? darkOpacity : (lightOpacity ?? darkOpacity * 0.65))
    }

    var surfaceTint: Color {
        muted()
    }

    var materialFallbackColorScheme: ColorScheme {
        colorScheme
    }

    var mattePanelNSColor: NSColor {
        cardBaseNSColor.withAlphaComponent(0.96)
    }

    var mattePanelFill: Color {
        Color(nsColor: mattePanelNSColor)
    }

    var mattePanelInsetShadow: Color {
        shadow(0.28, lightOpacity: 0.12)
    }

    var mattePanelSeparatorNSColor: NSColor {
        contrastingNSColor(darkOpacity: 0.07, lightOpacity: 0.10)
    }

    var mattePanelSeparator: Color {
        Color(nsColor: mattePanelSeparatorNSColor)
    }
}

extension WinMuxOverlayPalette {
    var dropIntentBackdropNSColor: NSColor {
        gray100BaseNSColor
    }

    func dropIntentBackdrop(_ opacity: Double = 1) -> Color {
        Color(nsColor: dropIntentBackdropNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var dropIntentInactivePaneNSColor: NSColor {
        gray300BaseNSColor
    }

    func dropIntentInactivePane(_ opacity: Double = 1) -> Color {
        Color(nsColor: dropIntentInactivePaneNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var dropIntentLandingPaneNSColor: NSColor {
        dropIntentSplitPlacementPaneNSColor
    }

    func dropIntentLandingPane(_ opacity: Double = 1) -> Color {
        Color(nsColor: dropIntentLandingPaneNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var dropIntentSplitPlacementPaneNSColor: NSColor {
        gray500BaseNSColor
    }

    func dropIntentSplitPlacementPane(_ opacity: Double = 1) -> Color {
        Color(nsColor: dropIntentSplitPlacementPaneNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var dropIntentDisplacedPaneNSColor: NSColor {
        dropIntentSplitExistingPaneNSColor
    }

    func dropIntentDisplacedPane(_ opacity: Double = 1) -> Color {
        Color(nsColor: dropIntentDisplacedPaneNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var dropIntentSplitExistingPaneNSColor: NSColor {
        gray300BaseNSColor
    }

    func dropIntentSplitExistingPane(_ opacity: Double = 1) -> Color {
        Color(nsColor: dropIntentSplitExistingPaneNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var canvasBackgroundNSColor: NSColor {
        colorToken(.canvasBackground)
    }

    func canvasBackground(_ opacity: Double = 1) -> Color {
        Color(nsColor: canvasBackgroundNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var attentionNSColor: NSColor {
        colorToken(.attention)
    }

    func attention(_ opacity: Double = 1) -> Color {
        Color(nsColor: attentionNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var destructiveNSColor: NSColor {
        colorToken(.destructive)
    }

    func destructive(_ opacity: Double = 1) -> Color {
        Color(nsColor: destructiveNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    var otherDisplayNSColor: NSColor {
        colorToken(.otherDisplay)
    }

    func otherDisplay(_ opacity: Double = 1) -> Color {
        Color(nsColor: otherDisplayNSColor.withAlphaComponent(CGFloat(opacity)))
    }

    fileprivate func colorToken(_ token: GeistOverlayColorToken) -> NSColor {
        token.nsColor(theme: theme)
    }
}

private enum GeistOverlayColorToken {
    case background
    case foreground
    case card
    case gray100
    case gray200
    case gray300
    case gray500
    case gray700
    case muted
    case mutedForeground
    case border
    case canvasBackground
    case attention
    case destructive
    case otherDisplay

    func nsColor(theme: AppearanceTheme) -> NSColor {
        switch self {
            case .background:
                return GeistCSSColor.background200.nsColor(theme: theme)
            case .foreground:
                return GeistCSSColor.gray1000.nsColor(theme: theme)
            case .card:
                return GeistCSSColor.background100.nsColor(theme: theme)
            case .gray100:
                return GeistCSSColor.gray100.nsColor(theme: theme)
            case .gray200:
                return GeistCSSColor.gray200.nsColor(theme: theme)
            case .gray300:
                return GeistCSSColor.gray300.nsColor(theme: theme)
            case .gray500:
                return GeistCSSColor.gray500.nsColor(theme: theme)
            case .gray700:
                return GeistCSSColor.gray700.nsColor(theme: theme)
            case .muted:
                return GeistCSSColor.gray100.nsColor(theme: theme)
            case .mutedForeground:
                return GeistCSSColor.gray900.nsColor(theme: theme)
            case .border:
                return GeistCSSColor.gray400.nsColor(theme: theme)
            case .canvasBackground:
                return theme == .dark
                    ? GeistCSSColor.gray200.nsColor(theme: theme)
                    : GeistCSSColor.gray200.nsColor(theme: theme)
            case .attention:
                return theme == .dark
                    ? GeistCSSColor.blue900.nsColor(theme: theme)
                    : GeistCSSColor.blue700.nsColor(theme: theme)
            case .destructive:
                return theme == .dark
                    ? GeistCSSColor.red900.nsColor(theme: theme)
                    : GeistCSSColor.red700.nsColor(theme: theme)
            case .otherDisplay:
                return theme == .dark
                    ? GeistCSSColor.pink900.nsColor(theme: theme)
                    : GeistCSSColor.pink700.nsColor(theme: theme)
        }
    }
}

private enum GeistCSSColor {
    case background100
    case background200
    case gray100
    case gray200
    case gray300
    case gray400
    case gray500
    case gray700
    case gray900
    case gray1000
    case blue700
    case blue900
    case red700
    case red900
    case pink700
    case pink900

    func nsColor(theme: AppearanceTheme) -> NSColor {
        switch self {
            case .background100:
                return theme == .dark ? Self.hex(0x0A0A0A) : Self.gray(1.00)
            case .background200:
                return theme == .dark ? Self.hex(0x000000) : Self.gray(0.98)
            case .gray100:
                return theme == .dark ? Self.hex(0x1A1A1A) : Self.gray(0.95)
            case .gray200:
                return theme == .dark ? Self.hex(0x1F1F1F) : Self.gray(0.92)
            case .gray300:
                return theme == .dark ? Self.hex(0x292929) : Self.gray(0.90)
            case .gray400:
                return theme == .dark ? Self.hex(0x333333) : Self.gray(0.92)
            case .gray500:
                return theme == .dark ? Self.hex(0x454545) : Self.gray(0.79)
            case .gray700:
                return theme == .dark ? Self.hex(0x8F8F8F) : Self.gray(0.56)
            case .gray900:
                return theme == .dark ? Self.hex(0xDEDEDE) : Self.gray(0.30)
            case .gray1000:
                return theme == .dark ? Self.hex(0xEDEDED) : Self.gray(0.09)
            case .blue700:
                return Self.hsl(212, 1.00, 0.48)
            case .blue900:
                return Self.hsl(211, 1.00, 0.42)
            case .red700:
                return Self.hsl(358, 0.75, 0.59)
            case .red900:
                return Self.hsl(358, 0.66, 0.48)
            case .pink700:
                return Self.hsl(336, 0.80, 0.58)
            case .pink900:
                return Self.hsl(336, 0.65, 0.45)
        }
    }

    private static func gray(_ white: CGFloat) -> NSColor {
        NSColor(srgbRed: white, green: white, blue: white, alpha: 1)
    }

    private static func hex(_ rgb: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func hsl(_ hue: CGFloat, _ saturation: CGFloat, _ lightness: CGFloat) -> NSColor {
        let normalizedHue = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        let chroma = (1 - abs((2 * lightness) - 1)) * saturation
        let huePrime = normalizedHue * 6
        let x = chroma * (1 - abs(huePrime.truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - (chroma / 2)
        let (red, green, blue): (CGFloat, CGFloat, CGFloat) = switch huePrime {
            case 0..<1: (chroma, x, 0)
            case 1..<2: (x, chroma, 0)
            case 2..<3: (0, chroma, x)
            case 3..<4: (0, x, chroma)
            case 4..<5: (x, 0, chroma)
            default: (chroma, 0, x)
        }
        return NSColor(
            srgbRed: red + match,
            green: green + match,
            blue: blue + match,
            alpha: 1
        )
    }
}

extension WinMuxOverlayPalette {
    static func adaptiveNSColor(_ provider: @escaping (WinMuxOverlayPalette) -> NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            provider(WinMuxOverlayPalette(theme: AppearanceTheme.from(appearance)))
        }
    }

    static func adaptiveColor(_ provider: @escaping (WinMuxOverlayPalette) -> NSColor) -> Color {
        Color(nsColor: adaptiveNSColor(provider))
    }
}

func winMuxOverlayForeground(_ opacity: Double = 1) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.foregroundNSColor(opacity: CGFloat(opacity))
    }
}

func winMuxOverlayMutedForeground(_ opacity: Double = 1) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.mutedForegroundNSColor(opacity: CGFloat(opacity))
    }
}

func winMuxOverlayBackground(_ opacity: Double) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.backgroundNSColor(opacity: CGFloat(opacity))
    }
}

func winMuxOverlayCard(_ opacity: Double = 1) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.cardNSColor(opacity: CGFloat(opacity))
    }
}

func winMuxOverlayBorder(_ opacity: Double = 1) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.borderNSColor(opacity: CGFloat(opacity))
    }
}

func winMuxOverlayContrastingFill(darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.contrastingNSColor(darkOpacity: CGFloat(darkOpacity), lightOpacity: lightOpacity.map { CGFloat($0) })
    }
}

func winMuxOverlayShadow(darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        NSColor.black.withAlphaComponent(CGFloat($0.isDark ? darkOpacity : (lightOpacity ?? darkOpacity * 0.65)))
    }
}

func winMuxOverlayAttention(_ opacity: Double = 1) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.attentionNSColor.withAlphaComponent(CGFloat(opacity))
    }
}

func winMuxOverlayDestructive(_ opacity: Double = 1) -> Color {
    WinMuxOverlayPalette.adaptiveColor {
        $0.destructiveNSColor.withAlphaComponent(CGFloat(opacity))
    }
}
