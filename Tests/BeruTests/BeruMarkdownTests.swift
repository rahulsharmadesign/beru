import XCTest
@testable import Beru

final class BeruMarkdownTests: XCTestCase {
    func testHeadingsParagraphsAndBulletsStayDistinct() {
        let blocks = BeruMarkdown.parse("""
        # Title
        A lead sentence.

        ## Section
        - one
        - two
        Body after the list.
        """)
        XCTAssertEqual(blocks, [
            .heading(1, "Title"),
            .paragraph("A lead sentence."),
            .gap,
            .heading(2, "Section"),
            .bullet("one"),
            .bullet("two"),
            .paragraph("Body after the list.")
        ])
    }

    func testConsecutiveBlankLinesCollapseToOneGap() {
        let blocks = BeruMarkdown.parse("First\n\n\n\nSecond")
        XCTAssertEqual(blocks, [
            .paragraph("First"),
            .gap,
            .paragraph("Second")
        ])
    }

    func testHeadingTopPaddingIsLargerThanBodySpacing() {
        XCTAssertEqual(BeruMarkdown.headingTopPadding(1), BeruSpace.md)
        XCTAssertEqual(BeruMarkdown.headingTopPadding(2), BeruSpace.sm)
        XCTAssertGreaterThan(BeruMarkdown.headingTopPadding(1), BeruSpace.xxs)
    }
}
