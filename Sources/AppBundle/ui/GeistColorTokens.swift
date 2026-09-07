import AppKit

enum GeistColorTokens {
    static let background1Light: GeistColorTokenValue = .gray(1.00)
    static let background2Light: GeistColorTokenValue = .gray(0.98)
    static let background1Dark: GeistColorTokenValue = .gray(0.04)
    static let background2Dark: GeistColorTokenValue = .gray(0.00)

    static let gray1Light: GeistColorTokenValue = .gray(0.95)
    static let gray2Light: GeistColorTokenValue = .gray(0.92)
    static let gray3Light: GeistColorTokenValue = .gray(0.90)
    static let gray4Light: GeistColorTokenValue = .gray(0.92)
    static let gray5Light: GeistColorTokenValue = .gray(0.79)
    static let gray6Light: GeistColorTokenValue = .gray(0.66)
    static let gray7Light: GeistColorTokenValue = .gray(0.56)
    static let gray8Light: GeistColorTokenValue = .gray(0.49)
    static let gray9Light: GeistColorTokenValue = .gray(0.30)
    static let gray10Light: GeistColorTokenValue = .gray(0.09)
    static let gray1Dark: GeistColorTokenValue = .gray(0.10)
    static let gray2Dark: GeistColorTokenValue = .gray(0.12)
    static let gray3Dark: GeistColorTokenValue = .gray(0.16)
    static let gray4Dark: GeistColorTokenValue = .gray(0.18)
    static let gray5Dark: GeistColorTokenValue = .gray(0.27)
    static let gray6Dark: GeistColorTokenValue = .gray(0.53)
    static let gray7Dark: GeistColorTokenValue = .gray(0.56)
    static let gray8Dark: GeistColorTokenValue = .gray(0.49)
    static let gray9Dark: GeistColorTokenValue = .gray(0.63)
    static let gray10Dark: GeistColorTokenValue = .gray(0.93)

    static let blue1Light: GeistColorTokenValue = .oklch(0.9732, 0.0141, 251.56)
    static let blue2Light: GeistColorTokenValue = .oklch(0.9629, 0.0195, 250.59)
    static let blue3Light: GeistColorTokenValue = .oklch(0.9458, 0.0293, 249.849)
    static let blue4Light: GeistColorTokenValue = .oklch(0.9158, 0.0473, 245.116)
    static let blue5Light: GeistColorTokenValue = .oklch(0.8275, 0.0979, 248.48)
    static let blue6Light: GeistColorTokenValue = .oklch(0.7308, 0.1583, 248.133)
    static let blue7Light: GeistColorTokenValue = .oklch(0.5761, 0.2508, 258.23)
    static let blue8Light: GeistColorTokenValue = .oklch(0.5151, 0.2399, 257.85)
    static let blue9Light: GeistColorTokenValue = .oklch(0.5318, 0.2399, 256.99)
    static let blue10Light: GeistColorTokenValue = .oklch(0.2667, 0.1099, 254.34)
    static let blue1Dark: GeistColorTokenValue = .oklch(0.2217, 0.0690, 259.89)
    static let blue2Dark: GeistColorTokenValue = .oklch(0.2545, 0.0811, 255.80)
    static let blue3Dark: GeistColorTokenValue = .oklch(0.3086, 0.1022, 255.21)
    static let blue4Dark: GeistColorTokenValue = .oklch(0.3410, 0.1210, 254.74)
    static let blue5Dark: GeistColorTokenValue = .oklch(0.3850, 0.1403, 254.40)
    static let blue6Dark: GeistColorTokenValue = .oklch(0.6494, 0.1982, 251.813)
    static let blue7Dark: GeistColorTokenValue = .oklch(0.5761, 0.2321, 258.23)
    static let blue8Dark: GeistColorTokenValue = .oklch(0.5151, 0.2307, 257.85)
    static let blue9Dark: GeistColorTokenValue = .oklch(0.7170, 0.1648, 250.794)
    static let blue10Dark: GeistColorTokenValue = .oklch(0.9675, 0.0179, 242.423)

    static let red1Light: GeistColorTokenValue = .oklch(0.9650, 0.0223, 13.09)
    static let red2Light: GeistColorTokenValue = .oklch(0.9541, 0.0299, 14.2526)
    static let red3Light: GeistColorTokenValue = .oklch(0.9433, 0.0369, 15.0115)
    static let red4Light: GeistColorTokenValue = .oklch(0.9151, 0.0471, 19.80)
    static let red5Light: GeistColorTokenValue = .oklch(0.8447, 0.1018, 17.71)
    static let red6Light: GeistColorTokenValue = .oklch(0.7112, 0.1881, 21.22)
    static let red7Light: GeistColorTokenValue = .oklch(0.6256, 0.2524, 23.03)
    static let red8Light: GeistColorTokenValue = .oklch(0.5819, 0.2482, 25.15)
    static let red9Light: GeistColorTokenValue = .oklch(0.5499, 0.2320, 25.29)
    static let red10Light: GeistColorTokenValue = .oklch(0.2480, 0.1041, 18.86)
    static let red1Dark: GeistColorTokenValue = .oklch(0.2210, 0.0657, 15.11)
    static let red2Dark: GeistColorTokenValue = .oklch(0.2593, 0.0834, 19.02)
    static let red3Dark: GeistColorTokenValue = .oklch(0.3147, 0.1105, 20.96)
    static let red4Dark: GeistColorTokenValue = .oklch(0.3527, 0.1273, 21.23)
    static let red5Dark: GeistColorTokenValue = .oklch(0.4068, 0.1479, 23.16)
    static let red6Dark: GeistColorTokenValue = .oklch(0.6256, 0.2277, 23.03)
    static let red7Dark: GeistColorTokenValue = .oklch(0.6256, 0.2234, 23.03)
    static let red8Dark: GeistColorTokenValue = .oklch(0.5801, 0.2270, 25.12)
    static let red9Dark: GeistColorTokenValue = .oklch(0.6996, 0.2136, 22.03)
    static let red10Dark: GeistColorTokenValue = .oklch(0.9560, 0.0293, 6.61)

    static let amber1Light: GeistColorTokenValue = .oklch(0.9748, 0.0331, 85.79)
    static let amber2Light: GeistColorTokenValue = .oklch(0.9681, 0.0495, 90.2423)
    static let amber3Light: GeistColorTokenValue = .oklch(0.9593, 0.0636, 90.52)
    static let amber4Light: GeistColorTokenValue = .oklch(0.9102, 0.1322, 88.25)
    static let amber5Light: GeistColorTokenValue = .oklch(0.8655, 0.1583, 79.63)
    static let amber6Light: GeistColorTokenValue = .oklch(0.8025, 0.1953, 73.59)
    static let amber7Light: GeistColorTokenValue = .oklch(0.8187, 0.1969, 76.46)
    static let amber8Light: GeistColorTokenValue = .oklch(0.7721, 0.1991, 64.28)
    static let amber9Light: GeistColorTokenValue = .oklch(0.5279, 0.1496, 54.65)
    static let amber10Light: GeistColorTokenValue = .oklch(0.3083, 0.0990, 45.48)
    static let amber1Dark: GeistColorTokenValue = .oklch(0.2246, 0.0538, 76.04)
    static let amber2Dark: GeistColorTokenValue = .oklch(0.2495, 0.0642, 64.78)
    static let amber3Dark: GeistColorTokenValue = .oklch(0.3234, 0.0837, 63.83)
    static let amber4Dark: GeistColorTokenValue = .oklch(0.3553, 0.0903, 66.2971)
    static let amber5Dark: GeistColorTokenValue = .oklch(0.4155, 0.1044, 67.98)
    static let amber6Dark: GeistColorTokenValue = .oklch(0.7504, 0.1737, 74.49)
    static let amber7Dark: GeistColorTokenValue = .oklch(0.8187, 0.1969, 76.46)
    static let amber8Dark: GeistColorTokenValue = .oklch(0.7721, 0.1991, 64.28)
    static let amber9Dark: GeistColorTokenValue = .oklch(0.7721, 0.1991, 64.28)
    static let amber10Dark: GeistColorTokenValue = .oklch(0.9670, 0.0418, 84.59)

    static let green1Light: GeistColorTokenValue = .oklch(0.9759, 0.0289, 145.42)
    static let green2Light: GeistColorTokenValue = .oklch(0.9692, 0.0370, 147.15)
    static let green3Light: GeistColorTokenValue = .oklch(0.9460, 0.0674, 144.23)
    static let green4Light: GeistColorTokenValue = .oklch(0.9149, 0.0976, 146.24)
    static let green5Light: GeistColorTokenValue = .oklch(0.8545, 0.1627, 146.30)
    static let green6Light: GeistColorTokenValue = .oklch(0.8025, 0.2140, 145.18)
    static let green7Light: GeistColorTokenValue = .oklch(0.6458, 0.1746, 147.27)
    static let green8Light: GeistColorTokenValue = .oklch(0.5781, 0.1507, 147.50)
    static let green9Light: GeistColorTokenValue = .oklch(0.5175, 0.1453, 147.65)
    static let green10Light: GeistColorTokenValue = .oklch(0.2915, 0.1197, 147.38)
    static let green1Dark: GeistColorTokenValue = .oklch(0.2309, 0.0716, 149.68)
    static let green2Dark: GeistColorTokenValue = .oklch(0.2712, 0.0895, 150.09)
    static let green3Dark: GeistColorTokenValue = .oklch(0.2984, 0.0960, 149.25)
    static let green4Dark: GeistColorTokenValue = .oklch(0.3439, 0.1039, 147.78)
    static let green5Dark: GeistColorTokenValue = .oklch(0.4419, 0.1484, 147.20)
    static let green6Dark: GeistColorTokenValue = .oklch(0.5811, 0.1815, 146.55)
    static let green7Dark: GeistColorTokenValue = .oklch(0.6458, 0.1990, 147.27)
    static let green8Dark: GeistColorTokenValue = .oklch(0.5781, 0.1776, 147.50)
    static let green9Dark: GeistColorTokenValue = .oklch(0.7310, 0.2158, 148.29)
    static let green10Dark: GeistColorTokenValue = .oklch(0.9676, 0.0560, 154.18)

    static let teal1Light: GeistColorTokenValue = .oklch(0.9772, 0.0359, 186.70)
    static let teal2Light: GeistColorTokenValue = .oklch(0.9706, 0.0347, 180.66)
    static let teal3Light: GeistColorTokenValue = .oklch(0.9492, 0.0478, 182.07)
    static let teal4Light: GeistColorTokenValue = .oklch(0.9276, 0.0718, 183.78)
    static let teal5Light: GeistColorTokenValue = .oklch(0.8688, 0.1344, 182.42)
    static let teal6Light: GeistColorTokenValue = .oklch(0.8150, 0.1610, 178.96)
    static let teal7Light: GeistColorTokenValue = .oklch(0.6492, 0.1572, 181.95)
    static let teal8Light: GeistColorTokenValue = .oklch(0.5753, 0.1392, 181.66)
    static let teal9Light: GeistColorTokenValue = .oklch(0.5208, 0.1251, 182.93)
    static let teal10Light: GeistColorTokenValue = .oklch(0.3211, 0.0788, 179.82)
    static let teal1Dark: GeistColorTokenValue = .oklch(0.2210, 0.0544, 178.74)
    static let teal2Dark: GeistColorTokenValue = .oklch(0.2506, 0.0620, 178.76)
    static let teal3Dark: GeistColorTokenValue = .oklch(0.3150, 0.0767, 180.99)
    static let teal4Dark: GeistColorTokenValue = .oklch(0.3243, 0.0763, 180.13)
    static let teal5Dark: GeistColorTokenValue = .oklch(0.4335, 0.1055, 180.97)
    static let teal6Dark: GeistColorTokenValue = .oklch(0.6071, 0.1485, 180.24)
    static let teal7Dark: GeistColorTokenValue = .oklch(0.6492, 0.1403, 181.95)
    static let teal8Dark: GeistColorTokenValue = .oklch(0.5753, 0.1392, 181.66)
    static let teal9Dark: GeistColorTokenValue = .oklch(0.7456, 0.1765, 182.80)
    static let teal10Dark: GeistColorTokenValue = .oklch(0.9646, 0.0560, 180.29)

    static let purple1Light: GeistColorTokenValue = .oklch(0.9665, 0.0244, 312.189)
    static let purple2Light: GeistColorTokenValue = .oklch(0.9673, 0.0228, 309.80)
    static let purple3Light: GeistColorTokenValue = .oklch(0.9485, 0.0364, 310.15)
    static let purple4Light: GeistColorTokenValue = .oklch(0.9177, 0.0614, 312.82)
    static let purple5Light: GeistColorTokenValue = .oklch(0.8126, 0.1409, 310.80)
    static let purple6Light: GeistColorTokenValue = .oklch(0.7207, 0.2083, 308.19)
    static let purple7Light: GeistColorTokenValue = .oklch(0.5550, 0.3008, 306.12)
    static let purple8Light: GeistColorTokenValue = .oklch(0.4858, 0.2638, 305.73)
    static let purple9Light: GeistColorTokenValue = .oklch(0.4718, 0.2579, 304.00)
    static let purple10Light: GeistColorTokenValue = .oklch(0.2396, 0.1300, 305.66)
    static let purple1Dark: GeistColorTokenValue = .oklch(0.2234, 0.0779, 316.87)
    static let purple2Dark: GeistColorTokenValue = .oklch(0.2591, 0.0921, 314.41)
    static let purple3Dark: GeistColorTokenValue = .oklch(0.3198, 0.1219, 312.41)
    static let purple4Dark: GeistColorTokenValue = .oklch(0.3593, 0.1504, 309.78)
    static let purple5Dark: GeistColorTokenValue = .oklch(0.4099, 0.1721, 307.92)
    static let purple6Dark: GeistColorTokenValue = .oklch(0.5550, 0.2191, 306.12)
    static let purple7Dark: GeistColorTokenValue = .oklch(0.5550, 0.2186, 306.12)
    static let purple8Dark: GeistColorTokenValue = .oklch(0.4858, 0.2102, 305.73)
    static let purple9Dark: GeistColorTokenValue = .oklch(0.6987, 0.2037, 309.51)
    static let purple10Dark: GeistColorTokenValue = .oklch(0.9610, 0.0304, 316.46)

    static let pink1Light: GeistColorTokenValue = .oklch(0.9569, 0.0359, 344.622)
    static let pink2Light: GeistColorTokenValue = .oklch(0.9571, 0.0321, 353.14)
    static let pink3Light: GeistColorTokenValue = .oklch(0.9383, 0.0451, 356.29)
    static let pink4Light: GeistColorTokenValue = .oklch(0.9112, 0.0573, 358.82)
    static let pink5Light: GeistColorTokenValue = .oklch(0.8428, 0.0915, 356.99)
    static let pink6Light: GeistColorTokenValue = .oklch(0.7433, 0.1547, 0.24)
    static let pink7Light: GeistColorTokenValue = .oklch(0.6352, 0.2380, 1.01)
    static let pink8Light: GeistColorTokenValue = .oklch(0.5951, 0.2339, 4.21)
    static let pink9Light: GeistColorTokenValue = .oklch(0.5350, 0.2058, 2.84)
    static let pink10Light: GeistColorTokenValue = .oklch(0.2600, 0.0977, 359.00)
    static let pink1Dark: GeistColorTokenValue = .oklch(0.2267, 0.0628, 354.73)
    static let pink2Dark: GeistColorTokenValue = .oklch(0.2620, 0.0859, 356.68)
    static let pink3Dark: GeistColorTokenValue = .oklch(0.3115, 0.1067, 355.93)
    static let pink4Dark: GeistColorTokenValue = .oklch(0.3213, 0.1174, 356.71)
    static let pink5Dark: GeistColorTokenValue = .oklch(0.3701, 0.1453, 358.39)
    static let pink6Dark: GeistColorTokenValue = .oklch(0.5033, 0.2089, 4.33)
    static let pink7Dark: GeistColorTokenValue = .oklch(0.6352, 0.2346, 1.01)
    static let pink8Dark: GeistColorTokenValue = .oklch(0.5951, 0.2429, 4.21)
    static let pink9Dark: GeistColorTokenValue = .oklch(0.6936, 0.2223, 3.91)
    static let pink10Dark: GeistColorTokenValue = .oklch(0.9574, 0.0326, 350.08)

    static func background(_ role: GeistBackgroundRole, theme: AppearanceTheme) -> GeistColorTokenValue {
        switch (role, theme) {
            case (.primary, .light): background1Light
            case (.secondary, .light): background2Light
            case (.primary, .dark): background1Dark
            case (.secondary, .dark): background2Dark
        }
    }

    static func color(
        _ family: WorkspaceSidebarProjectThemeFamily,
        _ step: GeistColorStep,
        theme: AppearanceTheme
    ) -> GeistColorTokenValue {
        scale(family, theme: theme)[step.index]
    }

    private static func scale(
        _ family: WorkspaceSidebarProjectThemeFamily,
        theme: AppearanceTheme
    ) -> [GeistColorTokenValue] {
        switch (family, theme) {
            case (.gray, .light): [gray1Light, gray2Light, gray3Light, gray4Light, gray5Light, gray6Light, gray7Light, gray8Light, gray9Light, gray10Light]
            case (.gray, .dark): [gray1Dark, gray2Dark, gray3Dark, gray4Dark, gray5Dark, gray6Dark, gray7Dark, gray8Dark, gray9Dark, gray10Dark]
            case (.blue, .light): [blue1Light, blue2Light, blue3Light, blue4Light, blue5Light, blue6Light, blue7Light, blue8Light, blue9Light, blue10Light]
            case (.blue, .dark): [blue1Dark, blue2Dark, blue3Dark, blue4Dark, blue5Dark, blue6Dark, blue7Dark, blue8Dark, blue9Dark, blue10Dark]
            case (.red, .light): [red1Light, red2Light, red3Light, red4Light, red5Light, red6Light, red7Light, red8Light, red9Light, red10Light]
            case (.red, .dark): [red1Dark, red2Dark, red3Dark, red4Dark, red5Dark, red6Dark, red7Dark, red8Dark, red9Dark, red10Dark]
            case (.amber, .light): [amber1Light, amber2Light, amber3Light, amber4Light, amber5Light, amber6Light, amber7Light, amber8Light, amber9Light, amber10Light]
            case (.amber, .dark): [amber1Dark, amber2Dark, amber3Dark, amber4Dark, amber5Dark, amber6Dark, amber7Dark, amber8Dark, amber9Dark, amber10Dark]
            case (.green, .light): [green1Light, green2Light, green3Light, green4Light, green5Light, green6Light, green7Light, green8Light, green9Light, green10Light]
            case (.green, .dark): [green1Dark, green2Dark, green3Dark, green4Dark, green5Dark, green6Dark, green7Dark, green8Dark, green9Dark, green10Dark]
            case (.teal, .light): [teal1Light, teal2Light, teal3Light, teal4Light, teal5Light, teal6Light, teal7Light, teal8Light, teal9Light, teal10Light]
            case (.teal, .dark): [teal1Dark, teal2Dark, teal3Dark, teal4Dark, teal5Dark, teal6Dark, teal7Dark, teal8Dark, teal9Dark, teal10Dark]
            case (.purple, .light): [purple1Light, purple2Light, purple3Light, purple4Light, purple5Light, purple6Light, purple7Light, purple8Light, purple9Light, purple10Light]
            case (.purple, .dark): [purple1Dark, purple2Dark, purple3Dark, purple4Dark, purple5Dark, purple6Dark, purple7Dark, purple8Dark, purple9Dark, purple10Dark]
            case (.pink, .light): [pink1Light, pink2Light, pink3Light, pink4Light, pink5Light, pink6Light, pink7Light, pink8Light, pink9Light, pink10Light]
            case (.pink, .dark): [pink1Dark, pink2Dark, pink3Dark, pink4Dark, pink5Dark, pink6Dark, pink7Dark, pink8Dark, pink9Dark, pink10Dark]
        }
    }
}

enum GeistColorTokenValue {
    case gray(CGFloat)
    case oklch(CGFloat, CGFloat, CGFloat)

    var nsColor: NSColor {
        switch self {
            case .gray(let white):
                NSColor(srgbRed: white, green: white, blue: white, alpha: 1)
            case .oklch(let lightness, let chroma, let hue):
                Self.oklchNSColor(lightness: lightness, chroma: chroma, hue: hue)
        }
    }

    private static func oklchNSColor(lightness: CGFloat, chroma: CGFloat, hue: CGFloat) -> NSColor {
        let hueRadians = hue * .pi / 180
        let a = chroma * cos(hueRadians)
        let b = chroma * sin(hueRadians)
        let lPrime = lightness + (0.3963377774 * a) + (0.2158037573 * b)
        let mPrime = lightness - (0.1055613458 * a) - (0.0638541728 * b)
        let sPrime = lightness - (0.0894841775 * a) - (1.2914855480 * b)
        let l = lPrime * lPrime * lPrime
        let m = mPrime * mPrime * mPrime
        let s = sPrime * sPrime * sPrime
        let x = (1.2268798734 * l) - (0.5578149966 * m) + (0.2813910502 * s)
        let y = (-0.0405757452 * l) + (1.1122868294 * m) - (0.0717110667 * s)
        let z = (-0.0763729497 * l) - (0.4214933239 * m) + (1.5869240244 * s)
        let red = (2.4934969119 * x) - (0.9313836179 * y) - (0.4027107845 * z)
        let green = (-0.8294889696 * x) + (1.7626640603 * y) + (0.0236246858 * z)
        let blue = (0.0358458302 * x) - (0.0761723893 * y) + (0.9568845240 * z)
        return NSColor(
            displayP3Red: gammaEncode(red),
            green: gammaEncode(green),
            blue: gammaEncode(blue),
            alpha: 1
        )
    }

    private static func gammaEncode(_ component: CGFloat) -> CGFloat {
        let encoded = component <= 0.0031308
            ? 12.92 * component
            : (1.055 * pow(component, 1 / 2.4)) - 0.055
        return min(max(encoded, 0), 1)
    }
}
