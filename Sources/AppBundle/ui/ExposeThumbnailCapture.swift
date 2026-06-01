import AppKit

func captureExposeThumbnail(_ windowId: UInt32) -> NSImage? {
    guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(windowId),
                                           [.boundsIgnoreFraming, .nominalResolution]) else { return nil }
    guard !isLikelyBlankWindowThumbnail(cg) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

func isLikelyBlankWindowThumbnail(_ image: CGImage, sampleGrid: Int = 18) -> Bool {
    let bitmap = NSBitmapImageRep(cgImage: image)
    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    let grid = max(3, min(sampleGrid, width, height))
    guard width > 1, height > 1 else { return true }

    var sampleCount = 0
    var minLuminance = CGFloat.greatestFiniteMagnitude
    var maxLuminance = CGFloat.leastNormalMagnitude
    var maxChannelSpread: CGFloat = 0

    for yIndex in 0 ..< grid {
        let y = Int(round(CGFloat(yIndex) * CGFloat(height - 1) / CGFloat(grid - 1)))
        for xIndex in 0 ..< grid {
            let x = Int(round(CGFloat(xIndex) * CGFloat(width - 1) / CGFloat(grid - 1)))
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  color.alphaComponent > 0.05
            else {
                continue
            }

            let red = color.redComponent
            let green = color.greenComponent
            let blue = color.blueComponent
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            minLuminance = min(minLuminance, luminance)
            maxLuminance = max(maxLuminance, luminance)
            maxChannelSpread = max(maxChannelSpread, max(red, green, blue) - min(red, green, blue))
            sampleCount += 1
        }
    }

    guard sampleCount >= grid * grid / 2 else { return true }
    return (maxLuminance - minLuminance) < 0.035 && maxChannelSpread < 0.035
}
