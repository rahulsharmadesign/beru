import XCTest
@testable import Beru

final class StreamingPrintTests: XCTestCase {
    func testTokensJoinBackToTheSourceIncludingNewlines() {
        let samples = [
            "",
            "Hello",
            "Hello world",
            "Hello  world",
            "Hello\nworld",
            "  leading",
            "trailing  ",
        ]
        for sample in samples {
            XCTAssertEqual(
                StreamingPrint.tokens(in: sample).joined(),
                sample,
                "join must reconstruct \(sample.debugDescription)"
            )
        }
    }

    func testPrefixStopsOnWordBoundaries() {
        let tokens = StreamingPrint.tokens(in: "Pistachio is growing")
        XCTAssertEqual(StreamingPrint.prefix(tokens, count: 0), "")
        XCTAssertEqual(StreamingPrint.prefix(tokens, count: 1), "Pistachio ")
        XCTAssertEqual(StreamingPrint.prefix(tokens, count: 2), "Pistachio is ")
        XCTAssertEqual(StreamingPrint.prefix(tokens, count: tokens.count), "Pistachio is growing")
        XCTAssertEqual(StreamingPrint.prefix(tokens, count: 99), "Pistachio is growing")
    }

    func testWhitespaceOnlyIsOneTokenPerCharacterCluster() {
        let tokens = StreamingPrint.tokens(in: " \n ")
        XCTAssertEqual(tokens, [" ", "\n", " "])
    }
}
