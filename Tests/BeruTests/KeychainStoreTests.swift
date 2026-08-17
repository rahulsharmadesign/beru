import XCTest
@testable import Beru

final class KeychainStoreTests: XCTestCase {
    private let testAccount = "beru-tests-account"

    override func tearDown() {
        KeychainStore.shared.delete(account: testAccount)
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() {
        XCTAssertTrue(KeychainStore.shared.save(key: "sk-test-12345", account: testAccount))
        XCTAssertEqual(KeychainStore.shared.load(account: testAccount), "sk-test-12345")
    }

    func testLoadMissingAccountReturnsNil() {
        XCTAssertNil(KeychainStore.shared.load(account: "beru-nonexistent-account"))
    }

    func testDeleteRemovesKey() {
        _ = KeychainStore.shared.save(key: "sk-test-67890", account: testAccount)
        XCTAssertTrue(KeychainStore.shared.delete(account: testAccount))
        XCTAssertNil(KeychainStore.shared.load(account: testAccount))
    }

    func testSaveOverwritesExistingValue() {
        _ = KeychainStore.shared.save(key: "sk-first", account: testAccount)
        _ = KeychainStore.shared.save(key: "sk-second", account: testAccount)
        XCTAssertEqual(KeychainStore.shared.load(account: testAccount), "sk-second")
    }
}
