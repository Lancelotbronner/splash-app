import XCTest
@testable import Splash

final class ServerCLIValidatorTests: XCTestCase {

	func testAcceptsValidFlags() {
		let (tokens, error) = ServerCLIValidator.validateAndTokenize("--no-webui --max-cache-disk 50GB")
		XCTAssertNil(error)
		XCTAssertEqual(tokens, ["--no-webui", "--max-cache-disk", "50GB"])
	}

	func testAcceptsComplexArguments() {
		let raw = "--draft-model incoai/Qwen3.6-35B-A3B-DFlash2 --revision f12a584 --temp=0.7 --cache-dir /tmp/splash_cache"
		let (tokens, error) = ServerCLIValidator.validateAndTokenize(raw)
		XCTAssertNil(error)
		XCTAssertEqual(tokens.count, 7)
		XCTAssertTrue(tokens.contains("--no-webui") == false)
		XCTAssertTrue(tokens.contains("--temp=0.7"))
		XCTAssertTrue(tokens.contains("/tmp/splash_cache"))
	}

	func testEmptyAndWhitespaceReturnsEmptyListWithoutError() {
		let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("")
		XCTAssertNil(error1)
		XCTAssertTrue(tokens1.isEmpty)

		let (tokens2, _) = ServerCLIValidator.validateAndTokenize("   \n\t  ")
		XCTAssertTrue(tokens2.isEmpty)

		let (tokens3, error3) = ServerCLIValidator.validateAndTokenize("    ")
		XCTAssertNil(error3)
		XCTAssertTrue(tokens3.isEmpty)
	}

	func testRejectsShellInjectionSemicolon() {
		let (tokens, error) = ServerCLIValidator.validateAndTokenize("--no-webui ; rm -rf /")
		XCTAssertNotNil(error)
		XCTAssertTrue(tokens.isEmpty)
	}

	func testRejectsCommandSubstitution() {
		let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("--draft $(whoami)")
		XCTAssertNotNil(error1)
		XCTAssertTrue(tokens1.isEmpty)

		let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("--draft `whoami`")
		XCTAssertNotNil(error2)
		XCTAssertTrue(tokens2.isEmpty)
	}

	func testRejectsPipesAndRedirections() {
		let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("--opt | nc 127.0.0.1 9000")
		XCTAssertNotNil(error1)
		XCTAssertTrue(tokens1.isEmpty)

		let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("--opt > /tmp/output")
		XCTAssertNotNil(error2)
		XCTAssertTrue(tokens2.isEmpty)
	}

	func testRejectsQuotesAndBackslashes() {
		let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("--opt \"value\"")
		XCTAssertNotNil(error1)
		XCTAssertTrue(tokens1.isEmpty)

		let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("--opt \\escape")
		XCTAssertNotNil(error2)
		XCTAssertTrue(tokens2.isEmpty)
	}

	func testSanitizedStringHelper() {
		let valid = ServerCLIValidator.sanitizedString("--no-webui --max-cache-disk 50GB")
		XCTAssertEqual(valid, "--no-webui --max-cache-disk 50GB")

		let malicious = ServerCLIValidator.sanitizedString("--no-webui ; evil")
		XCTAssertEqual(malicious, "")
	}

	func testValidateIdleReleaseAcceptsStandardDurations() {
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("off"), "off")
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("OFF"), "off")
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("30s"), "30s")
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("2m"), "2m")
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("10M"), "10m")
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("1h"), "1h")
		XCTAssertEqual(ServerCLIValidator.validateIdleRelease("600"), "600")

		// Rechazos
		XCTAssertNil(ServerCLIValidator.validateIdleRelease("10m; rm -rf /"))
		XCTAssertNil(ServerCLIValidator.validateIdleRelease("fast"))
		XCTAssertNil(ServerCLIValidator.validateIdleRelease("-5m"))
	}

	func testValidateMaxMemoryAcceptsStandardBudgets() {
		XCTAssertEqual(ServerCLIValidator.validateMaxMemory("auto"), "auto")
		XCTAssertEqual(ServerCLIValidator.validateMaxMemory("AUTO"), "auto")
		XCTAssertEqual(ServerCLIValidator.validateMaxMemory("16G"), "16G")
		XCTAssertEqual(ServerCLIValidator.validateMaxMemory("28g"), "28G")
		XCTAssertEqual(ServerCLIValidator.validateMaxMemory("512M"), "512M")
		XCTAssertEqual(ServerCLIValidator.validateMaxMemory("1024"), "1024")

		// Rechazos
		XCTAssertNil(ServerCLIValidator.validateMaxMemory("28GB; whoami"))
		XCTAssertNil(ServerCLIValidator.validateMaxMemory("unlimited"))
		XCTAssertNil(ServerCLIValidator.validateMaxMemory("-16G"))
	}

	func testValidateStateFormat() {
		XCTAssertEqual(ServerCLIValidator.validateStateFormat("bf16"), "bf16")
		XCTAssertEqual(ServerCLIValidator.validateStateFormat("BF16"), "bf16")
		XCTAssertEqual(ServerCLIValidator.validateStateFormat("fp32"), "fp32")
		XCTAssertEqual(ServerCLIValidator.validateStateFormat("FP32"), "fp32")

		// Rechazos
		XCTAssertNil(ServerCLIValidator.validateStateFormat("fp16"))
		XCTAssertNil(ServerCLIValidator.validateStateFormat("int8"))
		XCTAssertNil(ServerCLIValidator.validateStateFormat("bf16; rm -rf /"))
	}

	func testValidateThinkingBudget() {
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("auto"), "auto")
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("-1"), "-1")
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("off"), "-1")
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("0"), "-1")
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("4K"), "4000")
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("16k"), "16000")
		XCTAssertEqual(ServerCLIValidator.validateThinkingBudget("8192"), "8192")

		// Rechazos
		XCTAssertNil(ServerCLIValidator.validateThinkingBudget("-2"))
		XCTAssertNil(ServerCLIValidator.validateThinkingBudget("4K; whoami"))
		XCTAssertNil(ServerCLIValidator.validateThinkingBudget("unlimited"))
	}
}
