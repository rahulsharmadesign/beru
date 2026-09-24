import XCTest
@testable import Beru

final class ModelFitTests: XCTestCase {
    func testVisionModelsAreWeak() {
        for id in [
            "qwen2.5vl:3b",
            "qwen3-vl:8b",
            "llava:13b",
            "moondream",
            "minicpm-v:8b",
            "granite3.2-vision:2b",
        ] {
            XCTAssertEqual(
                OllamaModelFit.fit(for: id),
                .weak(kind: .vision),
                "\(id) should flag as vision"
            )
        }
    }

    func testEmbeddingModelsAreWeak() {
        for id in ["nomic-embed-text", "mxbai-embed-large", "snowflake-arctic-embed:22b", "bge-m3"] {
            XCTAssertEqual(
                OllamaModelFit.fit(for: id),
                .weak(kind: .embedding),
                "\(id) should flag as embedding"
            )
        }
    }

    func testSpeechAndGuardModelsAreWeak() {
        XCTAssertEqual(OllamaModelFit.fit(for: "whisper"), .weak(kind: .speech))
        XCTAssertEqual(OllamaModelFit.fit(for: "parakeet-tdt-0.6b-v2"), .weak(kind: .speech))
        XCTAssertEqual(OllamaModelFit.fit(for: "llama-guard3:8b"), .weak(kind: .guardrail))
        XCTAssertEqual(OllamaModelFit.fit(for: "mxbai-rerank-large"), .weak(kind: .guardrail))
    }

    func testTextModelsAreGood() {
        for id in [
            "qwen2.5:7b",
            "qwen3:8b",
            "qwen3:4b-instruct-2507-q4_K_M",
            "llama3.1:8b",
            "deepseek-r1:8b",
            "gpt-oss:20b",
        ] {
            XCTAssertEqual(OllamaModelFit.fit(for: id), .good, "\(id) must not flag")
        }
    }

    func testSmallTextModelsAreWeak() {
        for id in [
            "gemma3:1b",
            "qwen2.5:3b",
            "llama3.2:1b",
            "qwen2.5:0.5b",
        ] {
            XCTAssertEqual(
                OllamaModelFit.fit(for: id),
                .weak(kind: .small),
                "\(id) should flag as small"
            )
        }
    }

    func testSmallCheckNeedsASizeTag() {
        // Bare family names and larger sizes must never flag: the check only
        // reads the `:Nb` / `-Nb` tag Ollama ids carry.
        for id in [
            "gemma3",
            "qwen2.5:7b",
            "llama3.1:8b",
            "gpt-oss:20b",
            "llama3.2-vision:11b",
        ] {
            XCTAssertNotEqual(
                OllamaModelFit.fit(for: id),
                .weak(kind: .small),
                "\(id) must not flag as small"
            )
        }
    }

    func testWeakRolesNamesOnlyWeakRoles() {
        XCTAssertEqual(
            OllamaModelFit.weakRoles(enhanceModel: "qwen2.5vl:3b", grammarModel: "qwen2.5:7b"),
            ["Enhance"]
        )
        XCTAssertEqual(
            OllamaModelFit.weakRoles(enhanceModel: "qwen2.5:7b", grammarModel: "qwen2.5:7b"),
            []
        )
        XCTAssertEqual(
            OllamaModelFit.weakRoles(enhanceModel: "llava", grammarModel: "whisper"),
            ["Enhance", "Grammar"]
        )
    }

    func testWarningText() {
        XCTAssertNil(OllamaModelFit.fit(for: "qwen2.5:7b").warning)
        XCTAssertEqual(
            OllamaModelFit.fit(for: "qwen2.5vl:3b").warning,
            "Vision model — weak at Enhancify's text tasks"
        )
    }

    func testSmallModelWarningAndRoles() {
        XCTAssertEqual(
            OllamaModelFit.fit(for: "gemma3:1b").warning,
            "Small model — Enhance and Grammar need 7B+ for reliable results"
        )
        XCTAssertEqual(
            OllamaModelFit.weakRoles(enhanceModel: "gemma3:1b", grammarModel: "gemma3:1b"),
            ["Enhance", "Grammar"]
        )
        XCTAssertEqual(
            OllamaModelFit.weakRoles(enhanceModel: "gemma3:1b", grammarModel: "qwen2.5:7b"),
            ["Enhance"]
        )
    }
}
