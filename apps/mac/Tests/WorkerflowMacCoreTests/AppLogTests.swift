import XCTest
@testable import WorkerflowMacCore

final class AppLogTests: XCTestCase {
    func testRedactsSecretLikeValues() {
        let redacted = AppLog.redact("""
        AZURE_OPENAI_API_KEY=<your-api-key>
        Authorization: Bearer fake-openai-token-value
        x-api-key: abcdefghijklmnop
        """)

        XCTAssertFalse(redacted.contains("<your-api-key>"))
        XCTAssertFalse(redacted.contains("fake-openai-token-value"))
        XCTAssertFalse(redacted.contains("abcdefghijklmnop"))
        XCTAssertTrue(redacted.contains("AZURE_OPENAI_API_KEY=[REDACTED]"))
        XCTAssertTrue(AppLog.redact("AZURE_OPENAI_API_KEY: set").contains("set"))
    }
}
