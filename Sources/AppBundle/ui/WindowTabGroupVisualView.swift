import SwiftUI

struct WindowTabGroupVisualView: View {
    let strip: WindowTabStripViewModel

    var body: some View {
        // Native windows and the shared workspace surface provide the framing.
        WinMuxDesignTokens.transparent
            .allowsHitTesting(false)
    }
}
