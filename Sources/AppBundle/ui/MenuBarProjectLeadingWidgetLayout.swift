import SwiftUI

/// Keeps Period and Projects together on the leading side while the remaining
/// status widgets stay on the trailing side.
struct MenuBarProjectLeadingWidgetLayout: SwiftUI.Layout {
    let separation: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(
            width: proposal.width ?? sizes.reduce(0) { $0 + $1.width }
                + CGFloat(max(subviews.count - 1, 0)) * separation,
            height: proposal.height ?? sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = menuBarProjectLeadingWidgetPlacements(
            subviews.map { $0.sizeThatFits(.unspecified).width },
            availableWidth: bounds.width,
            separation: separation
        )
        for (subview, placement) in zip(subviews, placements) {
            subview.place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: placement.width, height: bounds.height)
            )
        }
    }
}

func menuBarProjectLeadingWidgetPlacements(
    _ idealWidths: [CGFloat],
    availableWidth: CGFloat,
    separation: CGFloat
) -> [MenuBarWidgetPlacement] {
    guard !idealWidths.isEmpty else { return [] }
    let widths = idealWidths.map { $0.isFinite ? max(0, $0) : 0 }
    let available = max(0, availableWidth)
    let gapCount = max(widths.count - 1, 0)
    let gap = gapCount > 0 ? min(max(0, separation), available / CGFloat(gapCount)) : 0
    let contentWidth = max(0, available - CGFloat(gapCount) * gap)
    let total = widths.reduce(0, +)
    let resolved = total > contentWidth && total > 0
        ? widths.map { contentWidth * $0 / total }
        : widths
    let leadingCount = min(2, resolved.count)
    let trailing = resolved.dropFirst(leadingCount)
    var leadingX: CGFloat = 0
    var trailingX = available - trailing.reduce(0, +) - CGFloat(max(trailing.count - 1, 0)) * gap
    var result: [MenuBarWidgetPlacement] = []

    for width in resolved.prefix(leadingCount) {
        result.append(MenuBarWidgetPlacement(x: leadingX, width: width))
        leadingX += width + gap
    }
    for width in trailing {
        result.append(MenuBarWidgetPlacement(x: trailingX, width: width))
        trailingX += width + gap
    }
    return result
}
