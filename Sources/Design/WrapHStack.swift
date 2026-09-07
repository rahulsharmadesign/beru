import SwiftUI

/// Wrapping row: children flow onto a second line instead of clipping past
/// the trailing edge. For button rows that grow with state (error fallbacks,
/// pin actions) on fixed-width surfaces like the panel and inspectors.
struct WrapHStack: Layout {
    var spacing: CGFloat = BeruSpace.xs
    var lineSpacing: CGFloat = BeruSpace.xs

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        rows(in: proposal.width ?? 0, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subviews[index].place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> (size: CGSize, count: Int) {
        guard width > 0 else { return (CGSize(width: width, height: 0), 0) }
        var size = CGSize(width: 0, height: 0)
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var lines = 1
        for subview in subviews {
            let child = subview.sizeThatFits(.unspecified)
            if lineWidth > 0, lineWidth + child.width > width {
                size.width = max(size.width, lineWidth - spacing)
                size.height += lineHeight + lineSpacing
                lineWidth = 0
                lineHeight = 0
                lines += 1
            }
            lineWidth += child.width + spacing
            lineHeight = max(lineHeight, child.height)
        }
        size.width = max(size.width, lineWidth > 0 ? lineWidth - spacing : 0)
        size.height += lineHeight
        return (size, lines)
    }
}
