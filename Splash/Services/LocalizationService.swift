import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
    
    public var flag: String {
        switch self {
        case .spanish: return "🇩🇴"
        case .english: return "🇬🇧"
        }
    }
}
