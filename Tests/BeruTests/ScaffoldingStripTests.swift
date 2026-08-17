import XCTest
@testable import Beru

/// Replace pastes the result into the document the text was selected from, so
/// container tags the model invented must never survive that far.
///
/// Reported as "I should be getting only text which I can replace, but <context>
/// and <task> also insert when I hit replace". The Claude target no longer asks
/// for tags, but this is the structural half of the fix — a prompt instruction is
/// a probability, and this write is one-way into someone's writing.
final class ScaffoldingStripTests: XCTestCase {
    private func strip(_ output: String, input: String = "make this better") -> String {
        PanelEngine.strippedScaffolding(output, input: input)
    }

    // MARK: - Removing what the model added

    func testRemovesAWholeContextAndTaskSkeleton() {
        let output = """
        <context>
        A webpage with a video above the related articles.
        </context>
        <task>
        Move the related articles below the video.
        </task>
        """
        let result = strip(output)
        XCTAssertEqual(result, """
        A webpage with a video above the related articles.
        Move the related articles below the video.
        """)
        XCTAssertFalse(result.contains("<"))
    }

    func testRemovesTagsLeftInlineRatherThanOnTheirOwnLine() {
        XCTAssertEqual(strip("<task>Move the section.</task>"), "Move the section.")
    }

    func testHandlesEveryContainerNameItClaimsTo() {
        for tag in PanelEngine.scaffoldingTags {
            let result = strip("<\(tag)>\nBody text.\n</\(tag)>")
            XCTAssertEqual(result, "Body text.", "failed to strip <\(tag)>")
        }
    }

    /// Removal must not leave the gap where the tag used to be.
    func testDoesNotLeaveBlankLinesBehind() {
        let result = strip("""
        <context>
        First paragraph.
        </context>

        <task>
        Second paragraph.
        </task>
        """)
        XCTAssertFalse(result.contains("\n\n\n"))
        XCTAssertTrue(result.hasPrefix("First paragraph."))
        XCTAssertTrue(result.hasSuffix("Second paragraph."))
    }

    func testCaseVariantsAreCaught() {
        XCTAssertEqual(strip("<Context>\nBody.\n</Context>"), "Body.")
        XCTAssertEqual(strip("<TASK>Body.</TASK>"), "Body.")
    }

    // MARK: - Keeping what the user wrote

    /// The rule the whole app follows: never remove what the input supplied.
    /// Someone enhancing a prompt they deliberately tagged must get their tags
    /// back.
    func testTagsPresentInTheInputAreLeftAlone() {
        let input = "improve this: <task>summarise the doc</task>"
        let output = "<task>Summarise the attached document in three bullets.</task>"
        XCTAssertEqual(strip(output, input: input), output)
    }

    /// Text *about* markup keeps its markup.
    func testOnlyContainerNamesAreTouched() {
        let output = "Wrap each row in <div> and bold the total with <b>."
        XCTAssertEqual(strip(output), output)
    }

    func testOrdinaryProseIsUnchanged() {
        for text in [
            "Move the related articles below the video so the video is seen first.",
            "There are three things we need to discuss before the meeting tomorrow.",
            "Use a < b as the comparison and keep the > operator in the example."
        ] {
            XCTAssertEqual(strip(text), text)
        }
    }

    func testEmptyAndWhitespaceOnlyOutputStaysEmpty() {
        XCTAssertEqual(strip(""), "")
        XCTAssertEqual(strip("   \n\n  "), "")
    }

    /// An output that is nothing but a tag pair must not become a stray blank
    /// string that the panel then reports as an empty response for the wrong
    /// reason — it collapses to empty, which the existing empty check handles.
    func testATagOnlyOutputCollapsesCleanly()  {
        XCTAssertEqual(strip("<context>\n</context>"), "")
    }

    // MARK: - Composition with the existing wrapping strip

    /// `strippedWrapping` matches on prefix and suffix, so scaffolding has to be
    /// removed after it — otherwise an opening `<context>` hides the outer code
    /// fence or quote from that pass.
    func testRunsAfterWrappingSoBothLayersComeOff() {
        let fenced = """
        ```
        <task>
        Move the section.
        </task>
        ```
        """
        let result = strip(PanelEngine.strippedWrapping(fenced))
        XCTAssertEqual(result, "Move the section.")
    }
}

final class SearchChromeStripTests: XCTestCase {
    func testStripsATXHeadingMarkersAndKeepsTheWords() {
        let output = """
        ### Yes
        Elon Musk is a well-known entrepreneur.
        """
        XCTAssertEqual(
            PanelEngine.strippedSearchChrome(output),
            """
            Yes
            Elon Musk is a well-known entrepreneur.
            """
        )
    }

    func testLeavesHashWithoutAFollowingSpaceAlone() {
        XCTAssertEqual(PanelEngine.strippedSearchChrome("#include <stdio.h>"), "#include <stdio.h>")
        XCTAssertEqual(PanelEngine.strippedSearchChrome("C# is a language."), "C# is a language.")
    }

    func testLeavesNonHeadingTextAlone() {
        XCTAssertEqual(
            PanelEngine.strippedSearchChrome("Yes. Elon Musk founded SpaceX."),
            "Yes. Elon Musk founded SpaceX."
        )
    }
}
