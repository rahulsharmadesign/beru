import AppKit
import XCTest
@testable import Beru

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

    func testScaleKeepsItsOwnAnchorFixed() {
        // The shift is built from the anchor itself, so the anchor never
        // moves no matter the scale — this is what plants the fixed point.
        let anchor = CGPoint(x: 90, y: 130)
        let transform = PanelController.scaleTransform(0.62, 0.74, about: anchor, in: size)
        let pinned = transform.transformPoint(anchor)
        XCTAssertEqual(pinned.x, anchor.x, accuracy: 0.001)
        XCTAssertEqual(pinned.y, anchor.y, accuracy: 0.001)
    }

    func testDockEdgeReadsTheEatenScreenEdge() {
        // Bottom Dock: 80pt eaten off the bottom.
        XCTAssertEqual(
            PanelController.dockEdge(
                frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visible: CGRect(x: 0, y: 80, width: 1512, height: 902)
            ),
            .minYEdge
        )
        // Left Dock.
        XCTAssertEqual(
            PanelController.dockEdge(
                frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visible: CGRect(x: 80, y: 0, width: 1432, height: 982)
            ),
            .minXEdge
        )
        // Right Dock.
        XCTAssertEqual(
            PanelController.dockEdge(
                frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visible: CGRect(x: 0, y: 0, width: 1432, height: 982)
            ),
            .maxXEdge
        )
    }

    func testDockEdgeIgnoresTheMenuBarAndHiddenDock() {
        // Menu bar only: the top inset never reads as a Dock.
        XCTAssertNil(
            PanelController.dockEdge(
                frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visible: CGRect(x: 0, y: 0, width: 1512, height: 958)
            )
        )
        // Autohidden Dock: nothing eaten, no edge.
        XCTAssertNil(
            PanelController.dockEdge(
                frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visible: CGRect(x: 0, y: 0, width: 1512, height: 982)
            )
        )
    }

    func testDockAnchorPinsTheDockSideEdge() {
        XCTAssertEqual(
            PanelController.anchorForDockEdge(.minYEdge, in: size),
            CGPoint(x: 180, y: 0)
        )
        XCTAssertEqual(
            PanelController.anchorForDockEdge(.minXEdge, in: size),
            CGPoint(x: 0, y: 260)
        )
        XCTAssertEqual(
            PanelController.anchorForDockEdge(.maxXEdge, in: size),
            CGPoint(x: 360, y: 260)
        )
    }
}

private extension CATransform3D {
    func transformPoint(_ point: CGPoint) -> CGPoint {
        let x = m11 * point.x + m21 * point.y + m41
        let y = m12 * point.x + m22 * point.y + m42
        return CGPoint(x: x, y: y)
    }
}