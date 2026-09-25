import AppKit
import XCTest
@testable import Enhancify

final class LiquidGlassChromeTests: XCTestCase {
    func testWindowSlabStaysStaticSoClicksDoNotBounceTheHUD() {
        let glass = NSGlassEffectView(frame: .zero)
        LiquidGlassChrome.prepareWindowSlab(glass)
        // Regular plus a scrim tint: .clear let the desktop's text read
        // straight through; untinted regular read as plain blur.
        XCTAssertEqual(glass.style, .regular)
        XCTAssertNotNil(glass.tintColor)
        guard let interactive = LiquidGlassChrome.isInteractive(glass) else {
            return
        }
        XCTAssertFalse(interactive)
    }

    func testInteractiveFlagCanStillBeTurnedOn() {
        let glass = NSGlassEffectView(frame: .zero)
        LiquidGlassChrome.prepareWindowSlab(glass, interactive: true)
        guard let interactive = LiquidGlassChrome.isInteractive(glass) else {
            return
        }
        XCTAssertTrue(interactive)
    }

    func testObjectMenuKeepsSymbolImageVisibleOnMacOS27() {
        let item = NSMenuItem(title: "Cursor", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil)
        LiquidGlassChrome.keepMenuImageVisible(item)
        guard let visibility = LiquidGlassChrome.menuImageVisibility(item) else {
            return
        }
        XCTAssertEqual(visibility, 1)
    }

    func testHighContrastFollowsTheWorkspaceSwitch() {
        guard let appearance = NSAppearance(named: .aqua) else {
            return XCTFail("missing aqua appearance")
        }
        let traits = EnhancifyColor.DisplayTraits.resolve(appearance)
        XCTAssertEqual(
            traits.isHighContrast,
            NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        )
    }

    func testDarkAquaIsDarkWithoutAssumingContrast() {
        guard let appearance = NSAppearance(named: .darkAqua) else {
            return XCTFail("missing dark aqua appearance")
        }
        let traits = EnhancifyColor.DisplayTraits.resolve(appearance)
        XCTAssertTrue(traits.isDark)
    }

    func testAquaIsLightWithoutHighContrastName() {
        guard let appearance = NSAppearance(named: .aqua) else {
            return XCTFail("missing aqua appearance")
        }
        let traits = EnhancifyColor.DisplayTraits.resolve(appearance)
        XCTAssertFalse(traits.isDark)
    }
}
