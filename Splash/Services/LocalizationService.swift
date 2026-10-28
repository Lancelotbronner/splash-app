import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
	case spanish = "es"
	case english = "en"

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .spanish: return "Español"
		case .english: return "English"
		}
	}

	var flag: String {
		switch self {
		case .spanish: return "🇩🇴"
		case .english: return "🇬🇧"
		}
	}
}
