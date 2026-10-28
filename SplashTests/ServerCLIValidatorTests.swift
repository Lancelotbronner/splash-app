import Foundation
import Testing
@testable import Splash

@MainActor
@Suite
final class ServerCLIValidatorTests {

	private enum Cases {
		/// Entradas maliciosas que deben rechazar el validador y dejar la lista vacía.
		static let maliciousInputs = [
			"--no-webui ; rm -rf /",
			"--draft $(whoami)",
			"--draft `whoami`",
			"--opt | nc 127.0.0.1 9000",
			"--opt > /tmp/output",
			"--opt \"value\"",
			"--opt \\escape"
		]

		struct ValidationCase: Sendable {
			let input: String
			let expected: String?
		}

		static let idleRelease: [ValidationCase] = [
			.init(input: "off", expected: "off"),
			.init(input: "OFF", expected: "off"),
			.init(input: "30s", expected: "30s"),
			.init(input: "2m", expected: "2m"),
			.init(input: "10M", expected: "10m"),
			.init(input: "1h", expected: "1h"),
			.init(input: "600", expected: "600"),
			// Rechazos
			.init(input: "10m; rm -rf /", expected: nil),
			.init(input: "fast", expected: nil),
			.init(input: "-5m", expected: nil)
		]

		static let maxMemory: [ValidationCase] = [
			.init(input: "auto", expected: "auto"),
			.init(input: "AUTO", expected: "auto"),
			.init(input: "16G", expected: "16G"),
			.init(input: "28g", expected: "28G"),
			.init(input: "512M", expected: "512M"),
			.init(input: "1024", expected: "1024"),
			// Rechazos
			.init(input: "28GB; whoami", expected: nil),
			.init(input: "unlimited", expected: nil),
			.init(input: "-16G", expected: nil)
		]

		static let stateFormat: [ValidationCase] = [
			.init(input: "bf16", expected: "bf16"),
			.init(input: "BF16", expected: "bf16"),
			.init(input: "fp32", expected: "fp32"),
			.init(input: "FP32", expected: "fp32"),
			// Rechazos
			.init(input: "fp16", expected: nil),
			.init(input: "int8", expected: nil),
			.init(input: "bf16; rm -rf /", expected: nil)
		]

		static let thinkingBudget: [ValidationCase] = [
			.init(input: "auto", expected: "auto"),
			.init(input: "-1", expected: "-1"),
			.init(input: "off", expected: "-1"),
			.init(input: "0", expected: "-1"),
			.init(input: "4K", expected: "4000"),
			.init(input: "16k", expected: "16000"),
			.init(input: "8192", expected: "8192"),
			// Rechazos
			.init(input: "-2", expected: nil),
			.init(input: "4K; whoami", expected: nil),
			.init(input: "unlimited", expected: nil)
		]
	}

	@Test func testAcceptsValidFlags() {
		let (tokens, error) = ServerCLIValidator.validateAndTokenize("--no-webui --max-cache-disk 50GB")
		#expect(error == nil)
		#expect(tokens == ["--no-webui", "--max-cache-disk", "50GB"])
	}

	@Test func testAcceptsComplexArguments() {
		let raw = "--draft-model incoai/Qwen3.6-35B-A3B-DFlash2 --revision f12a584 --temp=0.7 --cache-dir /tmp/splash_cache"
		let (tokens, error) = ServerCLIValidator.validateAndTokenize(raw)
		#expect(error == nil)
		#expect(tokens.count == 7)
		#expect(!tokens.contains("--no-webui"))
		#expect(tokens.contains("--temp=0.7"))
		#expect(tokens.contains("/tmp/splash_cache"))
	}

	@Test func testEmptyAndWhitespaceReturnsEmptyListWithoutError() {
		let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("")
		#expect(error1 == nil)
		#expect(tokens1.isEmpty)

		let (tokens2, _) = ServerCLIValidator.validateAndTokenize("   \n\t  ")
		#expect(tokens2.isEmpty)

		let (tokens3, error3) = ServerCLIValidator.validateAndTokenize("    ")
		#expect(error3 == nil)
		#expect(tokens3.isEmpty)
	}

	/// Inyección de shell: punto y coma, sustitución de comandos, tuberías,
	/// redirecciones, comillas y barras invertidas.
	@Test(arguments: Self.Cases.maliciousInputs)
	func testRejectsShellInjection(_ input: String) {
		let (tokens, error) = ServerCLIValidator.validateAndTokenize(input)
		#expect(error != nil, "Debe rechazar: \(input)")
		#expect(tokens.isEmpty, "No debe tokenizar la entrada maliciosa: \(input)")
	}

	@Test func testSanitizedStringHelper() {
		let valid = ServerCLIValidator.sanitizedString("--no-webui --max-cache-disk 50GB")
		#expect(valid == "--no-webui --max-cache-disk 50GB")

		let malicious = ServerCLIValidator.sanitizedString("--no-webui ; evil")
		#expect(malicious == "")
	}

	@Test(arguments: Self.Cases.idleRelease)
	private func testValidateIdleRelease(_ c: Cases.ValidationCase) {
		#expect(ServerCLIValidator.validateIdleRelease(c.input) == c.expected, "validateIdleRelease(\(c.input))")
	}

	@Test(arguments: Self.Cases.maxMemory)
	private func testValidateMaxMemory(_ c: Cases.ValidationCase) {
		#expect(ServerCLIValidator.validateMaxMemory(c.input) == c.expected, "validateMaxMemory(\(c.input))")
	}

	@Test(arguments: Self.Cases.stateFormat)
	private func testValidateStateFormat(_ c: Cases.ValidationCase) {
		#expect(ServerCLIValidator.validateStateFormat(c.input) == c.expected, "validateStateFormat(\(c.input))")
	}

	@Test(arguments: Self.Cases.thinkingBudget)
	private func testValidateThinkingBudget(_ c: Cases.ValidationCase) {
		#expect(ServerCLIValidator.validateThinkingBudget(c.input) == c.expected, "validateThinkingBudget(\(c.input))")
	}
}
