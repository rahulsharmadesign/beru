import XCTest
@testable import Beru

final class ProviderAPIKeyTests: XCTestCase {

    func testEnvironmentValueIsTrimmed() {
        let env = ["BERU_API_KEY": "  sk-live-123  "]
        XCTAssertEqual(ProviderAPIKey.fromEnvironment(environment: env), "sk-live-123")
    }

    func testMissingOrBlankEnvironmentIsNil() {
        XCTAssertNil(ProviderAPIKey.fromEnvironment(environment: [:]))
        XCTAssertNil(ProviderAPIKey.fromEnvironment(environment: ["BERU_API_KEY": "   "]))
        XCTAssertNil(ProviderAPIKey.fromEnvironment(
            name: ProviderAPIKey.anthropicEnvironmentVariable,
            environment: ["BERU_API_KEY": "sk-groq"]
        ))
    }

    func testStoredKeyWinsOverEnvironment() {
        XCTAssertEqual(
            ProviderAPIKey.resolved(stored: "sk-keychain", fallback: "sk-env"),
            "sk-keychain"
        )
        XCTAssertEqual(
            ProviderAPIKey.resolved(stored: "  ", fallback: "sk-env"),
            "sk-env"
        )
        XCTAssertNil(ProviderAPIKey.resolved(stored: nil, fallback: nil))
    }

    func testRemoteOpenAICompatRequiresAKeyBeforeTheRequest() {
        let provider = OpenAICompatProvider(
            baseURL: "https://api.groq.com/openai/v1",
            apiKey: nil,
            enhanceModel: "llama-3.3-70b-versatile",
            grammarModel: "llama-3.3-70b-versatile"
        )
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        XCTAssertThrowsError(try provider.applyAuthentication(to: &request)) { error in
            XCTAssertEqual(error as? ProviderError, .invalidAPIKey)
        }
    }

    func testRemoteOpenAICompatAttachesBearerToken() throws {
        let provider = OpenAICompatProvider(
            baseURL: "https://api.groq.com/openai/v1",
            apiKey: "  sk-test  ",
            enhanceModel: "llama-3.3-70b-versatile",
            grammarModel: "llama-3.3-70b-versatile"
        )
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        try provider.applyAuthentication(to: &request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
    }

    func testLoopbackOpenAICompatDoesNotRequireAKey() throws {
        let provider = OpenAICompatProvider(
            baseURL: "http://127.0.0.1:1234/v1",
            apiKey: nil,
            enhanceModel: "local",
            grammarModel: "local"
        )
        var request = URLRequest(url: URL(string: "http://127.0.0.1:1234/v1/chat/completions")!)
        try provider.applyAuthentication(to: &request)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testAnthropicRequiresAKeyBeforeTheRequest() {
        let provider = AnthropicProvider(apiKey: "  ")
        var request = URLRequest(url: AnthropicProvider.Constants.baseURL)
        XCTAssertThrowsError(try provider.applyAuthentication(to: &request)) { error in
            XCTAssertEqual(error as? ProviderError, .invalidAPIKey)
        }
    }

    func testAnthropicAttachesXAPIKey() throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-test")
        var request = URLRequest(url: AnthropicProvider.Constants.baseURL)
        try provider.applyAuthentication(to: &request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "anthropic-version"),
            AnthropicProvider.Constants.apiVersion
        )
    }
}
