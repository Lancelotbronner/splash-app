import Foundation
import Testing
@testable import Splash

// MARK: - P-07 / H-08: comparación semántica de versiones

@MainActor
@Suite
final class VersionTests {

	private enum Cases {
		struct ComparisonCase: Sendable {
			let latest: String
			let current: String
			let expectedNewer: Bool
		}

		static let all: [ComparisonCase] = [
			// Componentes numéricos comparados como números
			.init(latest: "2.0.0", current: "10.0.0", expectedNewer: false),
			.init(latest: "1.2.0", current: "1.10.0", expectedNewer: false),
			.init(latest: "1.10.0", current: "1.2.0", expectedNewer: true),
			.init(latest: "1.0.3", current: "1.0.2", expectedNewer: true),
			.init(latest: "1.0.2", current: "1.0.2", expectedNewer: false),
			// Un release es más nuevo que su propio pre-release
			.init(latest: "1.0.3", current: "1.0.3-beta", expectedNewer: true),
			.init(latest: "1.0.3-beta", current: "1.0.3", expectedNewer: false),
			// Validación del motor incoai/splash (Splash 1.3.1 frente a versiones previas)
			.init(latest: "1.3.1", current: "1.2.1", expectedNewer: true),
			.init(latest: "v1.3.1", current: "1.3.0", expectedNewer: true),
			.init(latest: "1.3.1", current: "1.3.1", expectedNewer: false),
			.init(latest: "1.2.1", current: "1.3.1", expectedNewer: false)
		]
	}

	/// Sonda V-8 de la auditoría, ahora como prueba de regresión.
	/// Con comparación lexicográfica (`String >`) la respuesta era `false`.
	@Test func testPatchTenIsNewerThanPatchTwo() {
		#expect(SemanticVersion.isNewer("1.0.10-beta", than: "1.0.2-beta"))
		#expect(!SemanticVersion.isNewer("1.0.2-beta", than: "1.0.10-beta"))
	}

	/// §10: los identificadores numéricos del sufijo de prepublicación se
	/// comparan como enteros; con orden lexicográfico `-beta.10` precedía
	/// (erróneamente) a `-beta.2`.
	@Test func testPrereleaseIdentifiersCompareNumerically() {
		#expect(SemanticVersion.isNewer("1.0.10-beta.10", than: "1.0.10-beta.2"))
		#expect(!SemanticVersion.isNewer("1.0.10-beta.2", than: "1.0.10-beta.10"))
		#expect(SemanticVersion.isNewer("1.0.10-beta.2", than: "1.0.10-beta"))
		#expect(!SemanticVersion.isNewer("1.0.10-beta", than: "1.0.10-beta.2"))
	}

	@Test(arguments: Self.Cases.all)
	private func testSemanticVersionComparison(_ c: Cases.ComparisonCase) {
		#expect(SemanticVersion.isNewer(c.latest, than: c.current) == c.expectedNewer,
				"isNewer(\(c.latest), than: \(c.current))")
	}

	@Test func testParsingAcceptsPrefixAndPartialVersions() throws {
		#expect(try #require(SemanticVersion("v1.0.2-beta")).description == "1.0.2-beta")
		#expect(try #require(SemanticVersion("1.0")).description == "1.0.0")
		#expect(try #require(SemanticVersion(" 2.1.3 ")).description == "2.1.3")
		#expect(try #require(SemanticVersion("1.0.2+build.9")).major == 1)
	}

	@Test func testUnparseableVersionNeverClaimsAnUpdate() {
		// Ante basura no se inventa una actualización: falso negativo silencioso.
		#expect(!SemanticVersion.isNewer("latest", than: "1.0.2-beta"))
		#expect(!SemanticVersion.isNewer("1.0.10-beta", than: "no-es-version"))
		#expect(!SemanticVersion.isNewer("", than: "1.0.2-beta"))
		#expect(SemanticVersion("1.0.2.3.4") == nil)
		#expect(SemanticVersion("1..2") == nil)
		#expect(SemanticVersion("-1.0.0") == nil)
	}

	/// P-15: la versión vive en un solo sitio y los scripts la extraen de ahí.
	@Test func testVersionExistsOnceAndScriptsAgreeWithIt() throws {
		let root = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent()   // VersionTests.swift
			.deletingLastPathComponent()   // SplashTests → raíz del proyecto
		let version = SplashVersion.current

		let sources = ["Splash/Services/Version.swift"]
		var declarations = 0
		for relative in sources {
			let contents = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
			let occurrences = contents.components(separatedBy: "= \"\(version)\"").count - 1
			declarations += occurrences
		}
		#expect(declarations == 1, "La versión debe declararse una sola vez (P-15).")

		// Ningún otro fichero Swift puede contener un literal de versión del producto.
		let enumerator = FileManager.default.enumerator(at: root.appendingPathComponent("Splash"),
														includingPropertiesForKeys: nil)
		while let file = enumerator?.nextObject() as? URL {
			guard file.pathExtension == "swift", file.lastPathComponent != "Version.swift" else { continue }
			let contents = try String(contentsOf: file, encoding: .utf8)
			#expect(!contents.contains("\"\(version)\""),
					"Versión duplicada en \(file.lastPathComponent); debe venir de SplashVersion.current.")
		}
	}
}
