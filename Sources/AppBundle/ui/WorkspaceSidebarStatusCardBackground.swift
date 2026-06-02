import SwiftUI

struct WorkspaceSidebarStatusCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: workspaceSidebarStatusCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}
