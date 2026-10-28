import Foundation
import Testing
@testable import Splash

// MARK: - P-05 del plan 1.0.1: rutas del motor sin versión fija

@MainActor
@Suite
final class SplashPathsTests {

	@Test func testFirstExistingPicksFirstAvailableCandidate() {
		let candidates = ["/a", "/b", "/c"]
		#expect(SplashPaths.firstExisting(candidates, exists: { $0 == "/b" }) == "/b")
		#expect(SplashPaths.firstExisting(candidates, exists: { $0 == "/c" }) == "/c")
		#expect(SplashPaths.firstExisting(candidates, exists: { _ in false }) == nil)
		#expect(SplashPaths.firstExisting([], exists: { _ in true }) == nil)
	}

	/// Regresión de la clase de errores corregida en 1.0.1: una versión fija en la ruta
	/// rompe la app tras `brew upgrade splash`.
	@Test func testNoCandidatePathPinsAMotorVersion() {
		let all = SplashPaths.brewExecutableCandidates()
		+ SplashPaths.splashExecutableCandidates()
		+ SplashPaths.pythonCandidates()
		+ SplashPaths.modelsScriptCandidates()
		for candidate in all {
			#expect(!candidate.contains("/Cellar/"), "Ruta con versión fija detectada: \(candidate)")
			#expect(candidate.range(of: #"/\d+\.\d+(\.\d+)?"#, options: .regularExpression) == nil,
					"Ruta con número de versión detectada: \(candidate)")
		}
	}

	@Test func testCellarCandidatesTryEveryInstalledVersionInDeterministicOrder() {
		let versions: [String: [String]] = ["/opt/homebrew/Cellar/splash": ["1.0.10", "1.0.2", "1.0.9"]]
		let found = SplashPaths.firstCellarCandidate(
			subpath: "libexec/install/models.py",
			versions: { versions[$0] },
			exists: { $0 == "/opt/homebrew/Cellar/splash/1.0.9/libexec/install/models.py" }
		)
		#expect(found == "/opt/homebrew/Cellar/splash/1.0.9/libexec/install/models.py")
	}

	@Test func testCellarSearchReturnsNilWhenAbsent() {
		#expect(SplashPaths.firstCellarCandidate(subpath: "libexec/python/bin/python3",
												  versions: { _ in nil },
												  exists: { _ in true }) == nil)
		#expect(SplashPaths.firstCellarCandidate(subpath: "libexec/python/bin/python3",
												  versions: { _ in [] },
												  exists: { _ in true }) == nil)
	}

	@Test func testCellarVersionListingIsSorted() {
		#expect(SplashPaths.cellarVersions(in: "/opt/homebrew/Cellar/splash",
											list: { _ in ["1.0.10", "1.0.2"] }) == ["1.0.10", "1.0.2"])
		#expect(SplashPaths.cellarVersions(in: "/x", list: { _ in nil }) == [])
	}
}
