import AppKit
import XCTest
@testable import Enhancify

/// The reveal's transform math. The panel has to unfold *from* the selection:
/// these pin the contract that the anchor is in slab coordinates and that the
/// first keyframe is born smaller and off-center toward it.
final class PanelEntranceTests: XCTestCase {
    private let size = CGSize(width: 360, height: 520)

    func testScreenAnchorConvertsToSlabCoordinates() {
        let frame = NSRect(x: 100, y: 300, width: 360, height: 520)
        let local = PanelController.localAnchor(
            CGPoint(x: 150, y: 850),
            frame: frame,
            size: size,
            growsDownward: true
        )
        XCTAssertEqual(local.x, 50, accuracy: 0.001)
        // The selection sits above the panel (it grows below it), so the slab
        // pin lands on the top edge, not past it.
        XCTAssertEqual(local.y, 520, accuracy: 0.001)
    }

    func testMissingAnchorFallsBackToTheGrowthEdge() {
        XCTAssertEqual(
            PanelController.localAnchor(nil, frame: .zero, size: size, growsDownward: true),
            CGPoint(x: 180, y: 520)
        )
        XCTAssertEqual(
            PanelController.localAnchor(nil, frame: .zero, size: size, growsDownward: false),
            CGPoint(x: 180, y: 0)
        )
    }

    func testFirstKeyframeGrowsTowardThePoint() {
        // The anchor is the panel's own pinned spot: the offset there is zero
        // and the far corner has to move, which is exactly the "unfolds from
        // the text" geometry. An identity-margin there would mean the anchor
        // was ignored and the panel scales from its center.
        let anchor = CGPoint(x: 40, y: size.height)
        let small = PanelController.scaleTransform(0.62, 0.74, about: anchor, in: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let shifted = small.transformPoint(center)
        XCTAssertNotEqual(shifted.x, center.x, accuracy: 0.001)
        XCTAssertNotEqual(shifted.y, center.y, accuracy: 0.001)
    }
}

private extension CATransform3D {
    func transformPoint(_ point: CGPoint) -> CGPoint {
        let x = m11 * point.x + m21 * point.y + m41
        let y = m12 * point.x + m22 * point.y + m42
        return CGPoint(x: x, y: y)
    }
}