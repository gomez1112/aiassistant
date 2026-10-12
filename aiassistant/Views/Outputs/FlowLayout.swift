import SwiftUI

/// Wraps tags within the proposed width, including labels wider than the window.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = availableWidth(proposal.width, subviews: subviews)
        let result = layout(subviews: subviews, width: width)
        return CGSize(width: width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.position.x, y: bounds.minY + placement.position.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private func availableWidth(_ proposedWidth: CGFloat?, subviews: Subviews) -> CGFloat {
        if let proposedWidth, proposedWidth.isFinite { return max(0, proposedWidth) }
        // An unspecified proposal asks for the layout's natural single-row width.
        return subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } +
            spacing * CGFloat(max(0, subviews.count - 1))
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (placements: [(position: CGPoint, size: CGSize)], height: CGFloat) {
        var placements: [(position: CGPoint, size: CGSize)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: max(0, width), height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            placements.append((CGPoint(x: x, y: y), size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (placements, y + rowHeight)
    }
}
