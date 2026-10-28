import Foundation
import Testing
@testable import Splash

// MARK: - P-12 / H-13: caché de tamaños de modelo

@MainActor
@Suite
final class ModelSizeCacheTests {

	@Test func testRepeatedLookupsWithSameStampReuseTheCachedValue() {
		var cache = ModelSizeCache()
		var computations = 0
		let stamp = Date(timeIntervalSince1970: 1_700_000_000)

		for _ in 0..<10 {
			let size = cache.size(repoId: "incoai/Qwen3.8-27B-Splash", stamp: stamp) {
				computations += 1
				return 17_400_000_000
			}
			#expect(size == 17_400_000_000)
		}
		#expect(computations == 1, "10 ciclos de sondeo deben costar 1 sola medición (P-12).")
		#expect(cache.count == 1)
	}

	@Test func testStampChangeInvalidatesEntry() {
		var cache = ModelSizeCache()
		var computations = 0
		let first = Date(timeIntervalSince1970: 1_700_000_000)
		let second = first.addingTimeInterval(60)

		_ = cache.size(repoId: "incoai/modelo", stamp: first) { computations += 1; return 10 }
		_ = cache.size(repoId: "incoai/modelo", stamp: second) { computations += 1; return 20 }
		#expect(computations == 2)

		let size = cache.size(repoId: "incoai/modelo", stamp: second) { computations += 1; return 30 }
		#expect(size == 20)
		#expect(computations == 2)
	}

	@Test func testExplicitInvalidationForcesRecompute() {
		var cache = ModelSizeCache()
		var computations = 0
		_ = cache.size(repoId: "incoai/modelo", stamp: nil) { computations += 1; return 1 }
		cache.invalidate(repoId: "incoai/modelo")
		_ = cache.size(repoId: "incoai/modelo", stamp: nil) { computations += 1; return 2 }
		#expect(computations == 2)
		cache.invalidateAll()
		#expect(cache.count == 0)
	}

	@Test func testTTLExpiresEvenWithStableStamp() {
		var cache = ModelSizeCache(ttl: 60)
		var computations = 0
		let t0 = Date(timeIntervalSince1970: 1_700_000_000)
		_ = cache.size(repoId: "m", stamp: nil, now: t0) { computations += 1; return 5 }
		_ = cache.size(repoId: "m", stamp: nil, now: t0.addingTimeInterval(30)) { computations += 1; return 5 }
		#expect(computations == 1)
		_ = cache.size(repoId: "m", stamp: nil, now: t0.addingTimeInterval(61)) { computations += 1; return 5 }
		#expect(computations == 2)
	}

	@Test func testIndependentEntriesPerModel() {
		var cache = ModelSizeCache()
		_ = cache.size(repoId: "a/m1", stamp: nil) { 1 }
		_ = cache.size(repoId: "a/m2", stamp: nil) { 2 }
		#expect(cache.count == 2)
		#expect(cache.size(repoId: "a/m1", stamp: nil) { 99 } == 1)
		#expect(cache.size(repoId: "a/m2", stamp: nil) { 99 } == 2)
	}
}
